import { Router, Response } from 'express';
import mongoose from 'mongoose';
import { Tournament } from '../models/Tournament';
import { Match } from '../models/Match';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';
import { User } from '../models/User';
import { authMiddleware, adminMiddleware, AuthRequest } from '../middleware/authMiddleware';
import { isTransactionSupported } from '../config/db';
import { getIoInstance, triggerBotMoveIfActive } from '../sockets/gameSocket';

const router = Router();

// 1. Get tournaments list
router.get('/', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const tournaments = await Tournament.find({}).sort({ createdAt: -1 });
    res.status(200).json({ success: true, tournaments });
  } catch (error) {
    console.error('Fetch tournaments error:', error);
    res.status(500).json({ success: false, error: 'Server error fetching tournaments.' });
  }
});

// 2. Register for tournament
router.post('/register', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { tournamentId } = req.body;
    const userId = req.user?.id;

    const user = await User.findById(userId);
    if (!user) {
      res.status(404).json({ success: false, error: 'User not found.' });
      return;
    }

    const tournament = await Tournament.findById(tournamentId);
    if (!tournament) {
      res.status(404).json({ success: false, error: 'Tournament not found.' });
      return;
    }

    if (tournament.status !== 'UPCOMING') {
      res.status(400).json({ success: false, error: 'Registration is closed for this tournament.' });
      return;
    }

    // Check if user is already registered
    const isRegistered = tournament.participants.some(p => p.userId.toString() === userId);
    if (isRegistered) {
      res.status(400).json({ success: false, error: 'You are already registered.' });
      return;
    }

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      // Deduct entry fee if any
      if (tournament.entryFee > 0) {
        const wallet = await Wallet.findOneAndUpdate(
          { userId, balance: { $gte: tournament.entryFee } },
          { $inc: { balance: -tournament.entryFee } },
          { new: true, ...(session ? { session } : {}) }
        );

        if (!wallet) {
          res.status(400).json({ success: false, error: 'Insufficient balance to pay entry fee.' });
          if (session) {
            await session.abortTransaction();
            session.endSession();
          }
          return;
        }

        // Create transaction entry
        const transaction = new Transaction({
          userId,
          amount: -tournament.entryFee,
          type: 'TOURNAMENT_ENTRY',
          status: 'SUCCESS',
          description: `Paid entry fee for tournament: ${tournament.name}`,
          referenceId: tournament._id.toString(),
        });
        await transaction.save(session ? { session } : {});
      }

      // Add to participants list
      tournament.participants.push({
        userId: new mongoose.Types.ObjectId(userId),
        username: user.username,
        score: 0,
        status: 'ACTIVE'
      });
      await tournament.save(session ? { session } : {});

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(200).json({ success: true, tournament });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Tournament registration error:', error);
    res.status(500).json({ success: false, error: 'Server error registering for tournament.' });
  }
});

// 3. Admin Create Tournament
router.post('/admin/create', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { name, entryFee, totalPrize, scheduledStartTime, roundCount, type, roundDurationSeconds } = req.body;

    if (!name || !scheduledStartTime) {
      res.status(400).json({ success: false, error: 'Tournament name and start time are required.' });
      return;
    }

    const tournamentType = type || 'STANDARD';
    const finalRoundCount = roundCount || (tournamentType === 'LEAGUE_5_DAY' ? 10 : 3);
    const finalRoundDuration = roundDurationSeconds || 43200; // Default 12 hours for all tournaments

    const newTournament = new Tournament({
      name,
      entryFee: entryFee || 0,
      totalPrize: totalPrize || 0,
      scheduledStartTime: new Date(scheduledStartTime),
      roundCount: finalRoundCount,
      type: tournamentType,
      roundDurationSeconds: finalRoundDuration,
      status: 'UPCOMING',
      participants: [],
      brackets: []
    });

    await newTournament.save();
    res.status(201).json({ success: true, tournament: newTournament });
  } catch (error) {
    console.error('Admin create tournament error:', error);
    res.status(500).json({ success: false, error: 'Server error scheduling tournament.' });
  }
});

// 3.5 Admin Edit Tournament
router.post('/admin/edit', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { tournamentId, name, entryFee, totalPrize, scheduledStartTime, roundCount, roundDurationSeconds } = req.body;

    if (!tournamentId) {
      res.status(400).json({ success: false, error: 'Tournament ID is required.' });
      return;
    }

    const tournament = await Tournament.findById(tournamentId);
    if (!tournament) {
      res.status(404).json({ success: false, error: 'Tournament not found.' });
      return;
    }

    // Allow editing name, prizes for any status; round settings only for UPCOMING/ACTIVE
    if (name !== undefined) tournament.name = name;
    if (entryFee !== undefined && tournament.status === 'UPCOMING') tournament.entryFee = entryFee;
    if (totalPrize !== undefined) tournament.totalPrize = totalPrize;
    if (scheduledStartTime !== undefined && tournament.status === 'UPCOMING') {
      tournament.scheduledStartTime = new Date(scheduledStartTime);
    }
    if (roundCount !== undefined && roundCount > 0) tournament.roundCount = roundCount;
    if (roundDurationSeconds !== undefined && roundDurationSeconds > 0) tournament.roundDurationSeconds = roundDurationSeconds;

    await tournament.save();
    res.status(200).json({ success: true, tournament });
  } catch (error) {
    console.error('Admin edit tournament error:', error);
    res.status(500).json({ success: false, error: 'Server error editing tournament.' });
  }
});

// 4. Admin Start Tournament & Generate Round 1 Matches
router.post('/admin/start', authMiddleware, adminMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { tournamentId } = req.body;
    const tournament = await Tournament.findById(tournamentId);

    if (!tournament) {
      res.status(404).json({ success: false, error: 'Tournament not found.' });
      return;
    }

    if (tournament.status !== 'UPCOMING') {
      res.status(400).json({ success: false, error: 'Tournament has already started or completed.' });
      return;
    }

    let activeParticipants = tournament.participants.filter(p => p.status === 'ACTIVE');

    // If league tournament and odd number of participants, pair the odd player with a bot
    if (tournament.type === 'LEAGUE_5_DAY' && activeParticipants.length % 2 !== 0) {
      const bots = await User.find({ isBot: true });
      if (bots.length > 0) {
        const randomBot = bots[Math.floor(Math.random() * bots.length)];
        const isBotRegistered = tournament.participants.some(p => p.userId.toString() === randomBot._id.toString());
        if (!isBotRegistered) {
          const newParticipant = {
            userId: randomBot._id,
            username: randomBot.username,
            score: 0,
            status: 'ACTIVE' as const
          };
          tournament.participants.push(newParticipant);
          activeParticipants.push(newParticipant);
        } else {
          const pIndex = tournament.participants.findIndex(p => p.userId.toString() === randomBot._id.toString());
          tournament.participants[pIndex].status = 'ACTIVE';
          activeParticipants.push(tournament.participants[pIndex]);
        }
      }
    }

    if (activeParticipants.length < 2) {
      res.status(400).json({ success: false, error: 'Need at least 2 participants to start a tournament.' });
      return;
    }

    const session = isTransactionSupported ? await mongoose.startSession() : null;
    if (session) {
      session.startTransaction();
    }

    try {
      tournament.status = 'ACTIVE';
      tournament.currentRound = 1;
      tournament.roundStartTime = new Date();

      await tournament.save(session ? { session } : {});

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(200).json({ success: true, tournament, matchesCreatedCount: 0 });
    } catch (txError) {
      if (session) {
        await session.abortTransaction();
        session.endSession();
      }
      throw txError;
    }
  } catch (error) {
    console.error('Admin start tournament error:', error);
    res.status(500).json({ success: false, error: 'Server error starting tournament.' });
  }
});

// 5. Matchmaking for active tournament round
router.post('/matchmake', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const { tournamentId } = req.body;
    const userId = req.user?.id;

    const user = await User.findById(userId);
    if (!user) {
      res.status(404).json({ success: false, error: 'User not found.' });
      return;
    }

    const tournament = await Tournament.findById(tournamentId);
    if (!tournament) {
      res.status(404).json({ success: false, error: 'Tournament not found.' });
      return;
    }

    if (tournament.status !== 'ACTIVE') {
      res.status(400).json({ success: false, error: 'Tournament is not active.' });
      return;
    }

    // Check if user is registered participant
    const isParticipant = tournament.participants.some(p => p.userId.toString() === userId && p.status === 'ACTIVE');
    if (!isParticipant) {
      res.status(400).json({ success: false, error: 'You are not a participant in this tournament.' });
      return;
    }

    // Check if user already played in the current round
    const hasPlayed = tournament.brackets.some(
      b => b.round === tournament.currentRound && 
      (b.playerA.toString() === userId || b.playerB.toString() === userId)
    );
    if (hasPlayed) {
      res.status(400).json({ success: false, error: 'You have already played your match for this round.' });
      return;
    }

    // Exclusive Bot Matchmaking for Tournaments
    const bots = await User.find({ isBot: true }).sort({ elo: -1 }).limit(5);
    if (bots.length === 0) {
      res.status(500).json({ success: false, error: 'No high-level bots available for tournament.' });
      return;
    }
    const bot = bots[Math.floor(Math.random() * bots.length)];

    const isWhite = Math.random() > 0.5;
    const newMatch = new Match({
      whitePlayerId: isWhite ? new mongoose.Types.ObjectId(userId) : bot._id,
      blackPlayerId: isWhite ? bot._id : new mongoose.Types.ObjectId(userId),
      whiteUsername: isWhite ? user.username : bot.username,
      blackUsername: isWhite ? bot.username : user.username,
      whiteTitle: isWhite ? user.title : bot.title,
      blackTitle: isWhite ? bot.title : user.title,
      whiteElo: isWhite ? user.elo : bot.elo,
      blackElo: isWhite ? bot.elo : user.elo,
      entryFee: 0,
      prizePool: 0,
      timeControl: 600, // 10 minutes
      status: 'RUNNING',
      startedAt: new Date(),
      tournamentId: tournament._id,
      round: tournament.currentRound
    });

    await newMatch.save();

    // Record in brackets
    tournament.brackets.push({
      round: tournament.currentRound,
      matchId: newMatch._id as mongoose.Types.ObjectId,
      playerA: newMatch.whitePlayerId!,
      playerB: newMatch.blackPlayerId!,
    });
    await tournament.save();

    res.status(200).json({
      success: true,
      match: newMatch
    });

    // Trigger bot move if it plays as white
    triggerBotMoveIfActive(newMatch._id.toString(), getIoInstance());
  } catch (error) {
    console.error('Tournament matchmaking error:', error);
    res.status(500).json({ success: false, error: 'Server error during tournament matchmaking.' });
  }
});

export default router;
