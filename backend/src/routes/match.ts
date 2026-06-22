import { Router, Response } from 'express';
import mongoose from 'mongoose';
import { Match } from '../models/Match';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';
import { User } from '../models/User';
import { authMiddleware, AuthRequest } from '../middleware/authMiddleware';
import { getIoInstance, triggerBotMoveIfActive } from '../sockets/gameSocket';
import { isTransactionSupported } from '../config/db';

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

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      // 1. Deduct entry fee from host if entryFee > 0
      if (entryFee > 0) {
        const hostWallet = await Wallet.findOneAndUpdate(
          { userId, balance: { $gte: entryFee } },
          { $inc: { balance: -entryFee, lockedBalance: entryFee } },
          { new: true, ...(session ? { session } : {}) }
        );

        if (!hostWallet) {
          res.status(400).json({ success: false, error: 'Insufficient wallet balance for entry fee.' });
          if (session) {
            await session.abortTransaction();
            session.endSession();
          }
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
        await transaction.save(session ? { session } : {});
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
        prizePool: entryFee * 2.0, // winner gets double the entry fee
        timeControl,
        status: 'WAITING',
      });
      await newMatch.save(session ? { session } : {});

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(201).json({
        success: true,
        match: newMatch,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
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

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      // 1. Deduct entry fee if entryFee > 0
      if (match.entryFee > 0) {
        const playerWallet = await Wallet.findOneAndUpdate(
          { userId, balance: { $gte: match.entryFee } },
          { $inc: { balance: -match.entryFee, lockedBalance: match.entryFee } },
          { new: true, ...(session ? { session } : {}) }
        );

        if (!playerWallet) {
          res.status(400).json({ success: false, error: 'Insufficient wallet balance to join.' });
          if (session) {
            await session.abortTransaction();
            session.endSession();
          }
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
        await transaction.save(session ? { session } : {});
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
      await match.save(session ? { session } : {});

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(200).json({
        success: true,
        match,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Join match error:', error);
    res.status(500).json({ success: false, error: 'Server error joining match lobby.' });
  }
});

// 3.5. Get my active/running matches
router.get('/my-active', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const matches = await Match.find({
      status: 'RUNNING',
      $or: [
        { whitePlayerId: userId },
        { blackPlayerId: userId }
      ]
    })
    .populate('whitePlayerId', 'username elo')
    .populate('blackPlayerId', 'username elo')
    .sort({ updatedAt: -1 });

    res.status(200).json({
      success: true,
      matches,
    });
  } catch (error) {
    console.error('Fetch active matches error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching active matches.' });
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

// Matchmaking
router.post('/matchmake', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { entryFee, timeControl } = req.body;
    const userId = req.user?.id;

    if (entryFee < 0) {
      res.status(400).json({ success: false, error: 'Entry fee cannot be negative.' });
      return;
    }
    if (!timeControl || timeControl < 60) {
      res.status(400).json({ success: false, error: 'Invalid time control.' });
      return;
    }

    const player = await User.findById(userId);
    if (!player) {
      res.status(404).json({ success: false, error: 'User not found.' });
      return;
    }

    // 1. Search for a WAITING match with same entry fee and time control hosted by another user
    const existingMatch = await Match.findOne({
      status: 'WAITING',
      entryFee,
      timeControl,
      $or: [
        { whitePlayerId: { $exists: false } },
        { blackPlayerId: { $exists: false } },
        { whitePlayerId: null },
        { blackPlayerId: null }
      ],
      whitePlayerId: { $ne: new mongoose.Types.ObjectId(userId) },
      blackPlayerId: { $ne: new mongoose.Types.ObjectId(userId) }
    });

    if (existingMatch) {
      const session = isTransactionSupported ? await mongoose.startSession() : null;
      if (session) {
        session.startTransaction();
      }

      try {
        if (entryFee > 0) {
          const playerWallet = await Wallet.findOneAndUpdate(
            { userId, balance: { $gte: entryFee } },
            { $inc: { balance: -entryFee, lockedBalance: entryFee } },
            { new: true, ...(session ? { session } : {}) }
          );

          if (!playerWallet) {
            res.status(400).json({ success: false, error: 'Insufficient wallet balance.' });
            if (session) {
              await session.abortTransaction();
              session.endSession();
            }
            return;
          }

          await new Transaction({
            userId,
            amount: -entryFee,
            type: 'MATCH_ENTRY',
            status: 'SUCCESS',
            description: `Entry Fee to join matchmaking match.`,
          }).save(session ? { session } : {});
        }

        if (!existingMatch.whitePlayerId) {
          existingMatch.whitePlayerId = new mongoose.Types.ObjectId(userId);
          existingMatch.whiteUsername = player.username;
        } else {
          existingMatch.blackPlayerId = new mongoose.Types.ObjectId(userId);
          existingMatch.blackUsername = player.username;
        }

        existingMatch.status = 'RUNNING';
        await existingMatch.save(session ? { session } : {});

        if (session) {
          await session.commitTransaction();
          session.endSession();
        }

        const io = getIoInstance();
        if (io) {
          io.to(existingMatch._id.toString()).emit('match_state', existingMatch);
        }

        res.status(200).json({
          success: true,
          match: existingMatch,
        });
        return;
      } catch (txError) {
        if (session) {
          await session.abortTransaction();
          session.endSession();
        }
        throw txError;
      }
    }

    // 2. No matching match found -> Create a new WAITING match
    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      if (entryFee > 0) {
        const hostWallet = await Wallet.findOneAndUpdate(
          { userId, balance: { $gte: entryFee } },
          { $inc: { balance: -entryFee, lockedBalance: entryFee } },
          { new: true, ...(session ? { session } : {}) }
        );

        if (!hostWallet) {
          res.status(400).json({ success: false, error: 'Insufficient wallet balance.' });
          if (session) {
            await session.abortTransaction();
            session.endSession();
          }
          return;
        }

        await new Transaction({
          userId,
          amount: -entryFee,
          type: 'MATCH_ENTRY',
          status: 'SUCCESS',
          description: `Entry Fee for hosting matchmaking match.`,
        }).save(session ? { session } : {});
      }

      const isWhite = Math.random() > 0.5;

      const newMatch = new Match({
        whitePlayerId: isWhite ? userId : undefined,
        blackPlayerId: isWhite ? undefined : userId,
        whiteUsername: isWhite ? player.username : undefined,
        blackUsername: isWhite ? undefined : player.username,
        entryFee,
        prizePool: entryFee * 2.0, // winner gets double
        timeControl,
        status: 'WAITING',
      });
      await newMatch.save(session ? { session } : {});

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(201).json({
        success: true,
        match: newMatch,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Matchmaking error:', error);
    res.status(500).json({ success: false, error: 'Server error during matchmaking.' });
  }
});

router.post('/force-bot-join', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { matchId } = req.body;
    const match = await Match.findById(matchId);

    if (!match) {
      res.status(404).json({ success: false, error: 'Match not found.' });
      return;
    }

    if (match.status !== 'WAITING') {
      res.status(200).json({ success: true, match, message: 'Match is already active.' });
      return;
    }

    // Find a random bot
    const bots = await User.find({ isBot: true });
    if (bots.length === 0) {
      res.status(500).json({ success: false, error: 'No bots available.' });
      return;
    }

    const bot = bots[Math.floor(Math.random() * bots.length)];

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      if (match.entryFee > 0) {
        const botWallet = await Wallet.findOneAndUpdate(
          { userId: bot._id, balance: { $gte: match.entryFee } },
          { $inc: { balance: -match.entryFee, lockedBalance: match.entryFee } },
          { new: true, ...(session ? { session } : {}) }
        );

        if (!botWallet) {
          res.status(400).json({ success: false, error: 'Bot wallet balance insufficient.' });
          if (session) {
            await session.abortTransaction();
            session.endSession();
          }
          return;
        }

        await new Transaction({
          userId: bot._id,
          amount: -match.entryFee,
          type: 'MATCH_ENTRY',
          status: 'SUCCESS',
          description: `Entry Fee to join matchmaking match (Bot Player).`,
        }).save(session ? { session } : {});
      }

      if (!match.whitePlayerId) {
        match.whitePlayerId = bot._id;
        match.whiteUsername = bot.username;
      } else {
        match.blackPlayerId = bot._id;
        match.blackUsername = bot.username;
      }

      match.status = 'RUNNING';
      await match.save(session ? { session } : {});

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      const io = getIoInstance();
      if (io) {
        io.to(match._id.toString()).emit('match_state', match);
        triggerBotMoveIfActive(match._id.toString(), io);
      }

      res.status(200).json({
        success: true,
        match,
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Force bot join error:', error);
    res.status(500).json({ success: false, error: 'Server error forcing bot join.' });
  }
});

router.post('/cancel-matchmake', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { matchId } = req.body;
    const userId = req.user?.id;

    const match = await Match.findById(matchId);
    if (!match) {
      res.status(404).json({ success: false, error: 'Match not found.' });
      return;
    }

    if (match.status !== 'WAITING') {
      res.status(400).json({ success: false, error: 'Match is already active or completed.' });
      return;
    }

    const isHost = match.whitePlayerId?.toString() === userId || match.blackPlayerId?.toString() === userId;
    if (!isHost) {
      res.status(403).json({ success: false, error: 'Only the match host can cancel.' });
      return;
    }

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      match.status = 'ABORTED';
      await match.save(session ? { session } : {});

      if (match.entryFee > 0) {
        await Wallet.findOneAndUpdate(
          { userId },
          { $inc: { balance: match.entryFee, lockedBalance: -match.entryFee } },
          session ? { session } : {}
        );

        await new Transaction({
          userId,
          amount: match.entryFee,
          type: 'MATCH_WIN',
          status: 'SUCCESS',
          description: `Refund for cancelled matchmaking match.`,
          referenceId: match._id.toString(),
        }).save(session ? { session } : {});
      }

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(200).json({
        success: true,
        message: 'Matchmaking search cancelled, entry fee refunded.',
      });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Cancel matchmaking error:', error);
    res.status(500).json({ success: false, error: 'Server error cancelling matchmaking.' });
  }
});

export default router;
