import { Router, Response } from 'express';
import mongoose from 'mongoose';
import { Match } from '../models/Match';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';
import { User } from '../models/User';
import { authMiddleware, AuthRequest } from '../middleware/authMiddleware';
import { getIoInstance, triggerBotMoveIfActive } from '../sockets/gameSocket';

const router = Router();

// 1. Get available/open match lobbies
router.get('/open', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const matches = await Match.find({ status: 'WAITING' })
      .populate('whitePlayerId', 'username elo title')
      .populate('blackPlayerId', 'username elo title')
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

    // 1. Deduct entry fee from host if entryFee > 0
    if (entryFee > 0) {
      const hostWallet = await Wallet.findOneAndUpdate(
        { userId, balance: { $gte: entryFee } },
        { $inc: { balance: -entryFee, lockedBalance: entryFee } },
        { new: true }
      );

      if (!hostWallet) {
        res.status(400).json({ success: false, error: 'Insufficient wallet balance for entry fee.' });
        return;
      }

      await new Transaction({
        userId,
        amount: -entryFee,
        type: 'MATCH_ENTRY',
        status: 'SUCCESS',
        description: `Entry Fee for hosting match.`,
      }).save();
    }

    // Determine color alignment
    const isWhite = preferredColor === 'black' ? false : true;

    // 2. Create Match Object
    const newMatch = new Match({
      whitePlayerId: isWhite ? userId : undefined,
      blackPlayerId: isWhite ? undefined : userId,
      whiteUsername: isWhite ? hostUser.username : undefined,
      blackUsername: isWhite ? undefined : hostUser.username,
      whiteTitle: isWhite ? hostUser.title : undefined,
      blackTitle: isWhite ? undefined : hostUser.title,
      whiteElo: isWhite ? hostUser.elo : undefined,
      blackElo: isWhite ? undefined : hostUser.elo,
      entryFee,
      prizePool: entryFee * 2.0,
      timeControl,
      status: 'WAITING',
    });
    await newMatch.save();

    res.status(201).json({
      success: true,
      match: newMatch,
    });
  } catch (error: any) {
    console.error('[CREATE-MATCH] Error:', error.message, error.stack);
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

    // 1. Deduct entry fee if entryFee > 0
    if (match.entryFee > 0) {
      const playerWallet = await Wallet.findOneAndUpdate(
        { userId, balance: { $gte: match.entryFee } },
        { $inc: { balance: -match.entryFee, lockedBalance: match.entryFee } },
        { new: true }
      );

      if (!playerWallet) {
        res.status(400).json({ success: false, error: 'Insufficient wallet balance to join.' });
        return;
      }

      await new Transaction({
        userId,
        amount: -match.entryFee,
        type: 'MATCH_ENTRY',
        status: 'SUCCESS',
        description: `Entry Fee to join match.`,
      }).save();
    }

    // Assign the remaining player slot
    if (!match.whitePlayerId) {
      match.whitePlayerId = new mongoose.Types.ObjectId(userId);
      match.whiteUsername = player.username;
      match.whiteTitle = player.title;
      match.whiteElo = player.elo;
    } else {
      match.blackPlayerId = new mongoose.Types.ObjectId(userId);
      match.blackUsername = player.username;
      match.blackTitle = player.title;
      match.blackElo = player.elo;
    }

    match.status = 'RUNNING';
    await match.save();

    res.status(200).json({
      success: true,
      match,
    });
  } catch (error: any) {
    console.error('[JOIN-MATCH] Error:', error.message, error.stack);
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
    .populate('whitePlayerId', 'username elo title')
    .populate('blackPlayerId', 'username elo title')
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

// 3.7. Get my completed match history
router.get('/history', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const userId = req.user?.id;
    const matches = await Match.find({
      status: 'COMPLETED',
      $or: [
        { whitePlayerId: userId },
        { blackPlayerId: userId }
      ]
    })
    .populate('whitePlayerId', 'username elo title')
    .populate('blackPlayerId', 'username elo title')
    .sort({ updatedAt: -1 });

    res.status(200).json({
      success: true,
      matches,
    });
  } catch (error) {
    console.error('Fetch match history error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching match history.' });
  }
});

// 4. Get active game details
router.get('/:id', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const match = await Match.findById(req.params.id)
      .populate('whitePlayerId', 'username elo title')
      .populate('blackPlayerId', 'username elo title');

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

    console.log('[MATCHMAKE] Request received:', { userId, entryFee, timeControl });

    if (entryFee === undefined || entryFee === null || entryFee < 0) {
      res.status(400).json({ success: false, error: 'Entry fee cannot be negative.' });
      return;
    }
    if (!timeControl || timeControl < 60) {
      res.status(400).json({ success: false, error: 'Invalid time control.' });
      return;
    }

    const player = await User.findById(userId);
    if (!player) {
      console.log('[MATCHMAKE] User not found:', userId);
      res.status(404).json({ success: false, error: 'User not found.' });
      return;
    }
    console.log('[MATCHMAKE] Player found:', player.username);

    // Convert entryFee to number to avoid type mismatch issues
    const numericEntryFee = Number(entryFee);
    const numericTimeControl = Number(timeControl);

    // 1. Search for a WAITING match with same entry fee and time control hosted by another user
    const userObjId = new mongoose.Types.ObjectId(userId);
    let existingMatch = null;
    try {
      existingMatch = await Match.findOne({
        status: 'WAITING',
        entryFee: numericEntryFee,
        timeControl: numericTimeControl,
        $and: [
          {
            $or: [
              { whitePlayerId: null },
              { blackPlayerId: null }
            ]
          },
          { whitePlayerId: { $ne: userObjId } },
          { blackPlayerId: { $ne: userObjId } }
        ]
      });
      console.log('[MATCHMAKE] Existing match search result:', existingMatch ? existingMatch._id : 'none');
    } catch (queryErr: any) {
      console.error('[MATCHMAKE] Error searching for existing match:', queryErr.message);
      // Continue to create a new match if query fails
    }

    if (existingMatch) {
      // Join the existing match
      try {
        if (numericEntryFee > 0) {
          const playerWallet = await Wallet.findOneAndUpdate(
            { userId: userObjId, balance: { $gte: numericEntryFee } },
            { $inc: { balance: -numericEntryFee, lockedBalance: numericEntryFee } },
            { new: true }
          );

          if (!playerWallet) {
            console.log('[MATCHMAKE] Insufficient balance for join:', userId);
            res.status(400).json({ success: false, error: 'Insufficient wallet balance.' });
            return;
          }

          await new Transaction({
            userId: userObjId,
            amount: -numericEntryFee,
            type: 'MATCH_ENTRY',
            status: 'SUCCESS',
            description: `Entry Fee to join matchmaking match.`,
          }).save();
        }

        if (!existingMatch.whitePlayerId) {
          existingMatch.whitePlayerId = userObjId;
          existingMatch.whiteUsername = player.username;
          existingMatch.whiteTitle = player.title;
          existingMatch.whiteElo = player.elo;
        } else {
          existingMatch.blackPlayerId = userObjId;
          existingMatch.blackUsername = player.username;
          existingMatch.blackTitle = player.title;
          existingMatch.blackElo = player.elo;
        }

        existingMatch.status = 'RUNNING';
        await existingMatch.save();

        console.log('[MATCHMAKE] Joined existing match:', existingMatch._id);

        const io = getIoInstance();
        if (io) {
          io.to(existingMatch._id.toString()).emit('match_state', existingMatch);
        }

        res.status(200).json({
          success: true,
          match: existingMatch,
        });
        return;
      } catch (joinErr: any) {
        console.error('[MATCHMAKE] Error joining existing match:', joinErr.message, joinErr.stack);
        // Fall through to create a new match instead
      }
    }

    // 2. No matching match found -> Create a new WAITING match
    try {
      if (numericEntryFee > 0) {
        const hostWallet = await Wallet.findOneAndUpdate(
          { userId: userObjId, balance: { $gte: numericEntryFee } },
          { $inc: { balance: -numericEntryFee, lockedBalance: numericEntryFee } },
          { new: true }
        );

        if (!hostWallet) {
          console.log('[MATCHMAKE] Insufficient balance for host:', userId);
          res.status(400).json({ success: false, error: 'Insufficient wallet balance.' });
          return;
        }

        await new Transaction({
          userId: userObjId,
          amount: -numericEntryFee,
          type: 'MATCH_ENTRY',
          status: 'SUCCESS',
          description: `Entry Fee for hosting matchmaking match.`,
        }).save();
      }

      const isWhite = Math.random() > 0.5;

      const newMatch = new Match({
        whitePlayerId: isWhite ? userObjId : null,
        blackPlayerId: isWhite ? null : userObjId,
        whiteUsername: isWhite ? player.username : null,
        blackUsername: isWhite ? undefined : player.username,
        whiteTitle: isWhite ? player.title : null,
        blackTitle: isWhite ? undefined : player.title,
        whiteElo: isWhite ? player.elo : undefined,
        blackElo: isWhite ? undefined : player.elo,
        entryFee: numericEntryFee,
        prizePool: numericEntryFee * 2.0,
        timeControl: numericTimeControl,
        status: 'WAITING',
      });
      await newMatch.save();

      console.log('[MATCHMAKE] Created new match:', newMatch._id);

      res.status(201).json({
        success: true,
        match: newMatch,
      });
    } catch (createErr: any) {
      console.error('[MATCHMAKE] Error creating new match:', createErr.message, createErr.stack);
      res.status(500).json({ success: false, error: 'Failed to create match: ' + createErr.message });
    }
  } catch (error: any) {
    console.error('[MATCHMAKE] Unhandled error:', error.message, error.stack);
    res.status(500).json({ success: false, error: 'Server error during matchmaking: ' + error.message });
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
    console.log('[FORCE-BOT-JOIN] Bot selected:', bot.username, 'for match:', matchId);

    try {
      if (match.entryFee > 0) {
        const botWallet = await Wallet.findOneAndUpdate(
          { userId: bot._id, balance: { $gte: match.entryFee } },
          { $inc: { balance: -match.entryFee, lockedBalance: match.entryFee } },
          { new: true }
        );

        if (!botWallet) {
          // If bot has no wallet or insufficient balance, create/top-up wallet and proceed
          console.log('[FORCE-BOT-JOIN] Bot wallet insufficient, ensuring wallet exists with funds');
          await Wallet.findOneAndUpdate(
            { userId: bot._id },
            { $inc: { balance: 100000 } },
            { upsert: true, new: true }
          );
          // Retry the deduction
          await Wallet.findOneAndUpdate(
            { userId: bot._id, balance: { $gte: match.entryFee } },
            { $inc: { balance: -match.entryFee, lockedBalance: match.entryFee } },
            { new: true }
          );
        }

        await new Transaction({
          userId: bot._id,
          amount: -match.entryFee,
          type: 'MATCH_ENTRY',
          status: 'SUCCESS',
          description: `Entry Fee to join matchmaking match (Bot Player).`,
        }).save();
      }

      if (!match.whitePlayerId) {
        match.whitePlayerId = bot._id;
        match.whiteUsername = bot.username;
        match.whiteTitle = bot.title;
        match.whiteElo = bot.elo;
      } else {
        match.blackPlayerId = bot._id;
        match.blackUsername = bot.username;
        match.blackTitle = bot.title;
        match.blackElo = bot.elo;
      }

      match.status = 'RUNNING';
      await match.save();

      console.log('[FORCE-BOT-JOIN] Bot joined match successfully:', match._id);

      const io = getIoInstance();
      if (io) {
        io.to(match._id.toString()).emit('match_state', match);
        triggerBotMoveIfActive(match._id.toString(), io);
      }

      res.status(200).json({
        success: true,
        match,
      });
    } catch (joinErr: any) {
      console.error('[FORCE-BOT-JOIN] Error:', joinErr.message, joinErr.stack);
      res.status(500).json({ success: false, error: 'Error joining bot: ' + joinErr.message });
    }
  } catch (error: any) {
    console.error('[FORCE-BOT-JOIN] Unhandled error:', error.message, error.stack);
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

    match.status = 'ABORTED';
    await match.save();

    if (match.entryFee > 0) {
      await Wallet.findOneAndUpdate(
        { userId },
        { $inc: { balance: match.entryFee, lockedBalance: -match.entryFee } }
      );

      await new Transaction({
        userId,
        amount: match.entryFee,
        type: 'MATCH_WIN',
        status: 'SUCCESS',
        description: `Refund for cancelled matchmaking match.`,
        referenceId: match._id.toString(),
      }).save();
    }

    console.log('[CANCEL-MATCHMAKE] Cancelled match:', matchId);

    res.status(200).json({
      success: true,
      message: 'Matchmaking search cancelled, entry fee refunded.',
    });
  } catch (error: any) {
    console.error('[CANCEL-MATCHMAKE] Error:', error.message, error.stack);
    res.status(500).json({ success: false, error: 'Server error cancelling matchmaking.' });
  }
});

export default router;
