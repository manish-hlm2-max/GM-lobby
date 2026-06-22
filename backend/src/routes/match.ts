import { Router, Response } from 'express';
import mongoose from 'mongoose';
import { Match } from '../models/Match';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';
import { User } from '../models/User';
import { authMiddleware, AuthRequest } from '../middleware/authMiddleware';

const router = Router();

// 1. Get available/open match lobbies
router.get('/open', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const matches = await Match.find({ status: 'WAITING' })
      .populate('whitePlayerId', 'username elo')
      .populate('blackPlayerId', 'username elo')
      .sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      matches,
    });
  } catch (error) {
    console.error('Fetch open matches error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching open lobbies.' });
  }
});

// 2. Create Match Lobby
router.post('/create', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { entryFee, timeControl, preferredColor } = req.body;
    const userId = req.user?.id;

    if (entryFee < 0) {
      res.status(400).json({ success: false, error: 'Entry fee cannot be negative.' });
      return;
    }
    if (!timeControl || timeControl < 60) {
      res.status(400).json({ success: false, error: 'Invalid time control. Minimum 60 seconds.' });
      return;
    }

    const hostUser = await User.findById(userId);
    if (!hostUser) {
      res.status(404).json({ success: false, error: 'Host user not found.' });
      return;
    }

    const session = await mongoose.startSession();
    session.startTransaction();

    try {
      // 1. Deduct entry fee from host if entryFee > 0
      if (entryFee > 0) {
        const hostWallet = await Wallet.findOneAndUpdate(
          { userId, balance: { $gte: entryFee } },
          { $inc: { balance: -entryFee, lockedBalance: entryFee } },
          { new: true, session }
        );

        if (!hostWallet) {
          res.status(400).json({ success: false, error: 'Insufficient wallet balance for entry fee.' });
          await session.abortTransaction();
          session.endSession();
          return;
        }

        // Create transaction log
        const transaction = new Transaction({
          userId,
          amount: -entryFee,
          type: 'MATCH_ENTRY',
          status: 'SUCCESS',
          description: `Entry Fee for hosting match.`,
        });
        await transaction.save({ session });
      }

      // Determine color alignment
      const isWhite = preferredColor === 'black' ? false : true;

      // 2. Create Match Object
      const newMatch = new Match({
        whitePlayerId: isWhite ? userId : undefined,
        blackPlayerId: isWhite ? undefined : userId,
        whiteUsername: isWhite ? hostUser.username : undefined,
        blackUsername: isWhite ? undefined : hostUser.username,
        entryFee,
        prizePool: entryFee * 1.8, // 10% platform fee, 90% payout per player (so host fee + joiner fee = 2x, winning is 1.8x)
        timeControl,
        status: 'WAITING',
      });
      await newMatch.save({ session });

      await session.commitTransaction();
      session.endSession();

      res.status(201).json({
        success: true,
        match: newMatch,
      });
    } catch (txError) {
      await session.abortTransaction();
      session.endSession();
      throw txError;
    }
  } catch (error) {
    console.error('Create match error:', error);
    res.status(500).json({ success: false, error: 'Server error creating match lobby.' });
  }
});

// 3. Join Match Lobby
router.post('/join', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { matchId } = req.body;
    const userId = req.user?.id;

    const player = await User.findById(userId);
    if (!player) {
      res.status(404).json({ success: false, error: 'User not found.' });
      return;
    }

    const match = await Match.findById(matchId);
    if (!match) {
      res.status(404).json({ success: false, error: 'Match lobby not found.' });
      return;
    }

    if (match.status !== 'WAITING') {
      res.status(400).json({ success: false, error: 'Lobby is no longer open.' });
      return;
    }

    // Verify joining player is not already in the game
    if (match.whitePlayerId?.toString() === userId || match.blackPlayerId?.toString() === userId) {
      res.status(400).json({ success: false, error: 'You are already host of this match.' });
      return;
    }

    const session = await mongoose.startSession();
    session.startTransaction();

    try {
      // 1. Deduct entry fee if entryFee > 0
      if (match.entryFee > 0) {
        const playerWallet = await Wallet.findOneAndUpdate(
          { userId, balance: { $gte: match.entryFee } },
          { $inc: { balance: -match.entryFee, lockedBalance: match.entryFee } },
          { new: true, session }
        );

        if (!playerWallet) {
          res.status(400).json({ success: false, error: 'Insufficient wallet balance to join.' });
          await session.abortTransaction();
          session.endSession();
          return;
        }

        // Create transaction log
        const transaction = new Transaction({
          userId,
          amount: -match.entryFee,
          type: 'MATCH_ENTRY',
          status: 'SUCCESS',
          description: `Entry Fee to join match.`,
        });
        await transaction.save({ session });
      }

      // Assign the remaining player slot
      if (!match.whitePlayerId) {
        match.whitePlayerId = new mongoose.Types.ObjectId(userId);
        match.whiteUsername = player.username;
      } else {
        match.blackPlayerId = new mongoose.Types.ObjectId(userId);
        match.blackUsername = player.username;
      }

      match.status = 'RUNNING';
      await match.save({ session });

      await session.commitTransaction();
      session.endSession();

      res.status(200).json({
        success: true,
        match,
      });
    } catch (txError) {
      await session.abortTransaction();
      session.endSession();
      throw txError;
    }
  } catch (error) {
    console.error('Join match error:', error);
    res.status(500).json({ success: false, error: 'Server error joining match lobby.' });
  }
});

// 4. Get active game details
router.get('/:id', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const match = await Match.findById(req.params.id)
      .populate('whitePlayerId', 'username elo')
      .populate('blackPlayerId', 'username elo');

    if (!match) {
      res.status(404).json({ success: false, error: 'Match not found.' });
      return;
    }

    res.status(200).json({
      success: true,
      match,
    });
  } catch (error) {
    console.error('Get match details error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching match details.' });
  }
});

export default router;
