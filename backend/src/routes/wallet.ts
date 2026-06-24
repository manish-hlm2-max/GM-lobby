import { Router, Response } from 'express';
import mongoose from 'mongoose';
import fs from 'fs';
import path from 'path';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';
import { User } from '../models/User';
import { Settings } from '../models/Settings';
import { authMiddleware, adminMiddleware, AuthRequest } from '../middleware/authMiddleware';
import { isTransactionSupported } from '../config/db';
import { getIoInstance } from '../sockets/gameSocket';

const router = Router();

// Helper: emit wallet update to a specific user via their personal socket room
const emitWalletUpdate = async (userId: string) => {
  const io = getIoInstance();
  if (!io) return;
  try {
    const wallet = await Wallet.findOne({ userId });
    io.to(`user:${userId}`).emit('wallet_updated', {
      balance: wallet ? wallet.balance : 0,
      lockedBalance: wallet ? wallet.lockedBalance : 0,
    });
  } catch (err) {
    console.error('Error emitting wallet update:', err);
  }
};

// 1. Simulate Deposit / Request Manual Deposit
router.post('/deposit', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { amount, referenceId } = req.body;
    if (!amount || amount <= 0) {
      res.status(400).json({ success: false, error: 'Amount must be positive.' });
      return;
    }

    const userId = req.user?.id;

    // Start database transaction session
    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      const isManual = !!referenceId;

      // Create transaction log
      const transaction = new Transaction({
        userId,
        amount,
        type: 'DEPOSIT',
        status: 'PENDING',
        referenceId: referenceId || undefined,
        description: isManual 
          ? `Manual Deposit request via UPI. UTR: ${referenceId}` 
          : 'Deposited cash via mock gateway (Pending Admin Approval).',
      });
      await transaction.save(session ? { session } : {});

      // For all deposits, do not credit balance until admin approval
      const wallet = await Wallet.findOne({ userId }).session(session || null);
      const currentBalance = wallet ? wallet.balance : 0;

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(200).json({
        success: true,
        balance: currentBalance,
        transaction,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Deposit error:', error);
    res.status(500).json({ success: false, error: 'Server error processing deposit.' });
  }
});

// 2. Request Withdrawal
router.post('/withdraw', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { amount, bankName, ifscCode, accountHolderName } = req.body;
    if (!amount || amount <= 0) {
      res.status(400).json({ success: false, error: 'Amount must be positive.' });
      return;
    }

    if (!bankName || !ifscCode || !accountHolderName) {
      res.status(400).json({ success: false, error: 'Bank name, IFSC code, and account holder name are required.' });
      return;
    }

    const userId = req.user?.id;

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      // Find wallet & check available balance atomically
      // By using findOneAndUpdate with conditional query, we block double spending
      const wallet = await Wallet.findOneAndUpdate(
        { userId, balance: { $gte: amount } },
        { $inc: { balance: -amount, lockedBalance: amount } },
        { new: true, ...(session ? { session } : {}) }
      );

      if (!wallet) {
        res.status(400).json({ success: false, error: 'Insufficient funds.' });
        if (session) {
          await session.abortTransaction();
          session.endSession();
        }
        return;
      }

      // Create transaction log
      const transaction = new Transaction({
        userId,
        amount: -amount,
        type: 'WITHDRAWAL',
        status: 'PENDING',
        description: `Withdrawal request to ${bankName} (${accountHolderName})`,
        bankName,
        ifscCode,
        accountHolderName,
      });
      await transaction.save(session ? { session } : {});

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(200).json({
        success: true,
        balance: wallet.balance,
        lockedBalance: wallet.lockedBalance,
        transaction,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Withdrawal error:', error);
    res.status(500).json({ success: false, error: 'Server error processing withdrawal.' });
  }
});

// 3. Get Transaction History
router.get('/history', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const transactions = await Transaction.find({ userId }).sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      transactions,
    });
  } catch (error) {
    console.error('Wallet history error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching wallet history.' });
  }
});

// 4. Admin Administers Withdrawal (Approve / Reject)
router.post('/admin/withdrawal/:action', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { action } = req.params;
    const { transactionId } = req.body;

    if (action !== 'approve' && action !== 'reject') {
      res.status(400).json({ success: false, error: 'Invalid action. Must be approve or reject.' });
      return;
    }

    const transaction = await Transaction.findById(transactionId);
    if (!transaction || transaction.type !== 'WITHDRAWAL' || transaction.status !== 'PENDING') {
      res.status(400).json({ success: false, error: 'Invalid or non-pending withdrawal transaction.' });
      return;
    }

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      const withdrawalAmount = Math.abs(transaction.amount); // negative number stored in amount

      if (action === 'approve') {
        // Successful withdrawal -> deduct from lockedBalance
        const wallet = await Wallet.findOneAndUpdate(
          { userId: transaction.userId, lockedBalance: { $gte: withdrawalAmount } },
          { $inc: { lockedBalance: -withdrawalAmount } },
          { new: true, ...(session ? { session } : {}) }
        );

        if (!wallet) {
          res.status(400).json({ success: false, error: 'Locked balance inconsistency.' });
          if (session) {
            await session.abortTransaction();
            session.endSession();
          }
          return;
        }

        transaction.status = 'SUCCESS';
        transaction.description = 'Withdrawal processed and approved.';
        await transaction.save(session ? { session } : {});

      } else {
        // Rejected withdrawal -> transfer lockedBalance back to available balance
        const wallet = await Wallet.findOneAndUpdate(
          { userId: transaction.userId, lockedBalance: { $gte: withdrawalAmount } },
          { $inc: { balance: withdrawalAmount, lockedBalance: -withdrawalAmount } },
          { new: true, ...(session ? { session } : {}) }
        );

        if (!wallet) {
          res.status(400).json({ success: false, error: 'Locked balance inconsistency.' });
          if (session) {
            await session.abortTransaction();
            session.endSession();
          }
          return;
        }

        transaction.status = 'FAILED';
        transaction.description = 'Withdrawal request rejected by administrator.';
        await transaction.save(session ? { session } : {});
      }

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      // Emit real-time wallet update to the affected user
      emitWalletUpdate(transaction.userId.toString());

      res.status(200).json({
        success: true,
        transaction,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Admin withdrawal error:', error);
    res.status(500).json({ success: false, error: 'Server error processing admin action.' });
  }
});

// 4.5. Admin Administers Deposit (Approve / Reject)
router.post('/admin/deposit/:action', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { action } = req.params;
    const { transactionId } = req.body;

    if (action !== 'approve' && action !== 'reject') {
      res.status(400).json({ success: false, error: 'Invalid action. Must be approve or reject.' });
      return;
    }

    const transaction = await Transaction.findById(transactionId);
    if (!transaction || transaction.type !== 'DEPOSIT' || transaction.status !== 'PENDING') {
      res.status(400).json({ success: false, error: 'Invalid or non-pending deposit transaction.' });
      return;
    }

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      if (action === 'approve') {
        // Successful deposit -> credit wallet balance
        const wallet = await Wallet.findOneAndUpdate(
          { userId: transaction.userId },
          { $inc: { balance: transaction.amount } },
          { new: true, upsert: true, ...(session ? { session } : {}) }
        );

        transaction.status = 'SUCCESS';
        transaction.description = `${transaction.description} - Approved and credited by admin`;
        await transaction.save(session ? { session } : {});

      } else {
        // Rejected deposit -> mark as FAILED
        transaction.status = 'FAILED';
        transaction.description = `${transaction.description} - Rejected by admin`;
        await transaction.save(session ? { session } : {});
      }

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      // Emit real-time wallet update to the affected user
      emitWalletUpdate(transaction.userId.toString());

      res.status(200).json({
        success: true,
        transaction,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Admin deposit verification error:', error);
    res.status(500).json({ success: false, error: 'Server error processing admin action.' });
  }
});

// 5. Admin Balance Override (Audit-Logged)
router.post('/admin/override', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { targetUserId, amount, reason } = req.body;

    if (!targetUserId || amount === undefined || amount === 0 || !reason) {
      res.status(400).json({ success: false, error: 'Target User ID, non-zero amount, and a reason are required.' });
      return;
    }

    const targetUser = await User.findById(targetUserId);
    if (!targetUser) {
      res.status(404).json({ success: false, error: 'Target user not found.' });
      return;
    }

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      // Log audit transaction
      const transaction = new Transaction({
        userId: targetUserId,
        amount,
        type: 'ADMIN_OVERRIDE',
        status: 'SUCCESS',
        description: `Admin Override by ${req.user?.email}. Reason: ${reason}`,
      });
      await transaction.save(session ? { session } : {});

      // Perform update
      // Handled carefully to prevent negative balances
      const updateQuery = amount > 0 
        ? { $inc: { balance: amount } }
        : { $inc: { balance: amount }, balance: { $gte: Math.abs(amount) } };

      const wallet = await Wallet.findOneAndUpdate(
        { userId: targetUserId, ...(amount < 0 ? { balance: { $gte: Math.abs(amount) } } : {}) },
        { $inc: { balance: amount } },
        { new: true, upsert: amount > 0, ...(session ? { session } : {}) }
      );

      if (!wallet) {
        res.status(400).json({ success: false, error: 'Failed to adjust balance. Would cause negative funds.' });
        if (session) {
          await session.abortTransaction();
          session.endSession();
        }
        return;
      }

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      // Emit real-time wallet update to the affected user
      emitWalletUpdate(targetUserId);

      res.status(200).json({
        success: true,
        balance: wallet.balance,
        transaction,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Admin override error:', error);
    res.status(500).json({ success: false, error: 'Server error processing override.' });
  }
});

// Admin fetches all users and transaction history (for admin tab views)
router.get('/admin/users', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const users = await User.find({}).select('-passwordHash');
    
    // Fetch wallet balances alongside
    const wallets = await Wallet.find({});
    
    const usersWithWallets = users.map(user => {
      const userWallet = wallets.find(w => w.userId.toString() === user._id.toString());
      return {
        id: user._id,
        email: user.email,
        username: user.username,
        role: user.role,
        elo: user.elo,
        isBlocked: user.isBlocked || false,
        isBot: user.isBot || false,
        plainPassword: user.plainPassword || '',
        phoneNumber: user.phoneNumber || '',
        fullName: user.fullName || '',
        balance: userWallet ? userWallet.balance : 0,
        lockedBalance: userWallet ? userWallet.lockedBalance : 0,
        title: user.title || '',
      };
    });

    res.status(200).json({
      success: true,
      users: usersWithWallets,
    });
  } catch (error) {
    console.error('Admin users fetch error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching users list.' });
  }
});

// Admin blocks or unblocks a user
router.post('/admin/user/block', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { targetUserId, block } = req.body;

    if (!targetUserId) {
      res.status(400).json({ success: false, error: 'Target user ID is required.' });
      return;
    }

    const targetUser = await User.findById(targetUserId);
    if (!targetUser) {
      res.status(404).json({ success: false, error: 'Target user not found.' });
      return;
    }

    if (targetUser.role === 'SUPER_ADMIN' || targetUser.role === 'MODERATOR') {
      res.status(400).json({ success: false, error: 'Cannot block administrative accounts.' });
      return;
    }

    targetUser.isBlocked = block;
    await targetUser.save();

    res.status(200).json({
      success: true,
      message: `User successfully ${block ? 'blocked' : 'unblocked'}.`,
      isBlocked: targetUser.isBlocked,
    });
  } catch (error) {
    console.error('Admin block user error:', error);
    res.status(500).json({ success: false, error: 'Server error processing block user.' });
  }
});

// Admin sets or clears a user's chess title
router.post('/admin/user/title', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { targetUserId, title } = req.body;

    if (!targetUserId) {
      res.status(400).json({ success: false, error: 'Target user ID is required.' });
      return;
    }

    // Validate title value
    const normalizedTitle = title ? title.trim().toUpperCase() : '';
    const validTitles = ['GM', 'IM', 'FM', 'CM', 'WGM', 'WIM', 'WFM', 'WCM', ''];
    if (!validTitles.includes(normalizedTitle)) {
      res.status(400).json({ success: false, error: `Invalid title. Must be one of: ${validTitles.filter(Boolean).join(', ')} or empty.` });
      return;
    }

    const targetUser = await User.findById(targetUserId);
    if (!targetUser) {
      res.status(404).json({ success: false, error: 'Target user not found.' });
      return;
    }

    targetUser.title = normalizedTitle || '';
    await targetUser.save();

    res.status(200).json({
      success: true,
      message: `User title updated to ${normalizedTitle || 'none'}.`,
      title: targetUser.title || '',
    });
  } catch (error) {
    console.error('Admin set user title error:', error);
    res.status(500).json({ success: false, error: 'Server error updating user title.' });
  }
});

// Admin fetches all transactions in the system
router.get('/admin/transactions', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const transactions = await Transaction.find({}).populate('userId', 'username email').sort({ createdAt: -1 });
    res.status(200).json({
      success: true,
      transactions,
    });
  } catch (error) {
    console.error('Admin transactions fetch error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching all system transactions.' });
  }
});

// 15. Get current UPI ID and QR code URL for deposits
router.get('/deposit-settings', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const upiSetting = await Settings.findOne({ key: 'deposit_upi_id' });
    const qrSetting = await Settings.findOne({ key: 'deposit_qr_code_url' });

    res.status(200).json({
      success: true,
      upiId: upiSetting ? upiSetting.value : 'fojimeena125-3@oksbi',
      qrCodeUrl: qrSetting ? qrSetting.value : null
    });
  } catch (error) {
    console.error('Fetch deposit settings error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching deposit settings.' });
  }
});

// 16. Admin updates UPI ID and QR code image for deposits
router.post('/admin/deposit-settings', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { upiId, qrCodeBase64 } = req.body;

    let qrCodeUrl = null;

    if (upiId) {
      await Settings.findOneAndUpdate(
        { key: 'deposit_upi_id' },
        { value: upiId },
        { upsert: true, new: true }
      );
    }

    if (qrCodeBase64) {
      // Decode base64 and save as file
      const matches = qrCodeBase64.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
      let buffer: Buffer;

      if (matches && matches.length === 3) {
        buffer = Buffer.from(matches[2], 'base64');
      } else {
        buffer = Buffer.from(qrCodeBase64, 'base64');
      }

      // Create uploads directory if it doesn't exist
      const uploadsDir = path.join(__dirname, '../../public/uploads');
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }

      // Write QR image
      const filename = `qrcode_${Date.now()}.png`;
      const filePath = path.join(uploadsDir, filename);
      fs.writeFileSync(filePath, buffer);

      // Delete old file if exists
      const oldQrSetting = await Settings.findOne({ key: 'deposit_qr_code_url' });
      if (oldQrSetting && typeof oldQrSetting.value === 'string') {
        const oldFilename = oldQrSetting.value.split('?')[0].split('/').pop();
        if (oldFilename) {
          const oldFilePath = path.join(uploadsDir, oldFilename);
          if (fs.existsSync(oldFilePath)) {
            try {
              fs.unlinkSync(oldFilePath);
            } catch (err) {
              console.error('Failed to delete old QR image:', err);
            }
          }
        }
      }

      qrCodeUrl = `/public/uploads/${filename}`;
      await Settings.findOneAndUpdate(
        { key: 'deposit_qr_code_url' },
        { value: qrCodeUrl },
        { upsert: true, new: true }
      );
    } else {
      const qrSetting = await Settings.findOne({ key: 'deposit_qr_code_url' });
      qrCodeUrl = qrSetting ? qrSetting.value : null;
    }

    res.status(200).json({
      success: true,
      message: 'Deposit settings updated successfully.',
      upiId: upiId || 'fojimeena125-3@oksbi',
      qrCodeUrl
    });
  } catch (error) {
    console.error('Admin update deposit settings error:', error);
    res.status(500).json({ success: false, error: 'Server error updating deposit settings.' });
  }
});

export default router;
