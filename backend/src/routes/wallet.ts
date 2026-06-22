import { Router, Response } from 'express';
import mongoose from 'mongoose';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';
import { User } from '../models/User';
import { authMiddleware, adminMiddleware, AuthRequest } from '../middleware/authMiddleware';
import { isTransactionSupported } from '../config/db';

const router = Router();

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
        status: isManual ? 'PENDING' : 'SUCCESS',
        referenceId: referenceId || undefined,
        description: isManual 
          ? `Manual Deposit request via UPI. UTR: ${referenceId}` 
          : 'Deposited cash via mock gateway.',
      });
      await transaction.save(session ? { session } : {});

      let currentBalance = 0;

      if (!isManual) {
        // Atomically update wallet balance for instant/legacy mode
        const wallet = await Wallet.findOneAndUpdate(
          { userId },
          { $inc: { balance: amount } },
          { new: true, upsert: true, ...(session ? { session } : {}) }
        );
        currentBalance = wallet.balance;
      } else {
        // For manual, do not credit balance until admin approval
        const wallet = await Wallet.findOne({ userId }).session(session || null);
        currentBalance = wallet ? wallet.balance : 0;
      }

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
    const { amount } = req.body;
    if (!amount || amount <= 0) {
      res.status(400).json({ success: false, error: 'Amount must be positive.' });
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
        description: 'Withdrawal request pending administrative approval.',
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
        // Successful manual deposit -> credit wallet balance
        const wallet = await Wallet.findOneAndUpdate(
          { userId: transaction.userId },
          { $inc: { balance: transaction.amount } },
          { new: true, upsert: true, ...(session ? { session } : {}) }
        );

        transaction.status = 'SUCCESS';
        transaction.description = 'Manual deposit approved and credited.';
        await transaction.save(session ? { session } : {});

      } else {
        // Rejected manual deposit -> mark as FAILED
        transaction.status = 'FAILED';
        transaction.description = 'Manual deposit rejected by administrator.';
        await transaction.save(session ? { session } : {});
      }

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

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
        plainPassword: user.plainPassword || '',
        phoneNumber: user.phoneNumber || '',
        balance: userWallet ? userWallet.balance : 0,
        lockedBalance: userWallet ? userWallet.lockedBalance : 0,
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

export default router;
