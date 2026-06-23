import { Router, Response } from 'express';
import mongoose from 'mongoose';
import { Tournament } from '../models/Tournament';
import { Match } from '../models/Match';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';
import { User } from '../models/User';
import { authMiddleware, adminMiddleware, AuthRequest } from '../middleware/authMiddleware';
import { isTransactionSupported } from '../config/db';

const router = Router();

// 1. Get tournaments list
router.get('/', authMiddleware, async (req: AuthRequest, res: Response): Promise<void> => {
  try {
    const tournaments = await Tournament.find({}).sort({ scheduledStartTime: 1 });
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
    const { name, entryFee, totalPrize, scheduledStartTime, roundCount } = req.body;

    if (!name || !scheduledStartTime) {
      res.status(400).json({ success: false, error: 'Tournament name and start time are required.' });
      return;
    }

    const newTournament = new Tournament({
      name,
      entryFee: entryFee || 0,
      totalPrize: totalPrize || 0,
      scheduledStartTime: new Date(scheduledStartTime),
      roundCount: roundCount || 3,
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

    const activeParticipants = tournament.participants.filter(p => p.status === 'ACTIVE');
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

      // Simple matchmaking: pair players sequentially
      // For Swiss/Arena, we shuffle or sort by score. For Round 1, pair sequentially.
      const activeUserIds = activeParticipants.map(p => p.userId);
      const activeUsers = await User.find({ _id: { $in: activeUserIds } }).select('_id title');
      const titleMap = new Map<string, string>();
      activeUsers.forEach(u => {
        if (u.title) {
          titleMap.set(u._id.toString(), u.title);
        }
      });

      const matchesToCreate = [];
      for (let i = 0; i < activeParticipants.length; i += 2) {
        if (i + 1 < activeParticipants.length) {
          const playerA = activeParticipants[i];
          const playerB = activeParticipants[i + 1];

          // Create a Match document for the tournament pairing
          const tournamentMatch = new Match({
            whitePlayerId: playerA.userId,
            blackPlayerId: playerB.userId,
            whiteUsername: playerA.username,
            blackUsername: playerB.username,
            whiteTitle: titleMap.get(playerA.userId.toString()),
            blackTitle: titleMap.get(playerB.userId.toString()),
            entryFee: 0, // already paid at tournament signup
            prizePool: 0, // paid at tournament end
            timeControl: 600, // 10 minutes default
            status: 'RUNNING'
          });

          matchesToCreate.push(tournamentMatch);
        } else {
          // Odd player gets a bye: they advance automatically
          const oddPlayer = activeParticipants[i];
          const index = tournament.participants.findIndex(p => p.userId.toString() === oddPlayer.userId.toString());
          if (index !== -1) {
            tournament.participants[index].score += 1; // 1 point for the bye
          }
        }
      }

      // Save matches inside transaction
      const savedMatches = await Match.insertMany(matchesToCreate, session ? { session } : {});

      // Add pairings to tournament brackets
      savedMatches.forEach((savedMatch, idx) => {
        tournament.brackets.push({
          round: 1,
          matchId: savedMatch._id as mongoose.Types.ObjectId,
          playerA: savedMatch.whitePlayerId!,
          playerB: savedMatch.blackPlayerId!,
        });
      });

      await tournament.save(session ? { session } : {});

      if (session) {
        await session.commitTransaction();
        session.endSession();
      }

      res.status(200).json({ success: true, tournament, matchesCreatedCount: savedMatches.length });
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

export default router;
