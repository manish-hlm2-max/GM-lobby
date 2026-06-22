import { Server, Socket } from 'socket.io';
import { Chess } from 'chess.js';
import mongoose from 'mongoose';
import axios from 'axios';
import { Match, IMatch } from '../models/Match';
import { Tournament } from '../models/Tournament';
import { User } from '../models/User';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';
import { seedBots } from '../config/botSeeder';
import { isTransactionSupported } from '../config/db';

// Map of active timers for running games
const gameTimers: { [matchId: string]: NodeJS.Timeout } = {};
const forfeitTimers: { [matchId_userId: string]: NodeJS.Timeout } = {};

const triggerForfeitTimeout = async (userId: string, io: Server) => {
  try {
    const activeMatches = await Match.find({
      status: 'RUNNING',
      $or: [
        { whitePlayerId: new mongoose.Types.ObjectId(userId) },
        { blackPlayerId: new mongoose.Types.ObjectId(userId) }
      ]
    });

    for (const match of activeMatches) {
      const matchId = match._id.toString();
      const key = `${matchId}_${userId}`;
      if (forfeitTimers[key]) clearTimeout(forfeitTimers[key]);

      console.log(`User ${userId} disconnected. Starting 30s forfeit timer for match ${matchId}`);
      forfeitTimers[key] = setTimeout(async () => {
        try {
          const freshMatch = await Match.findById(matchId);
          if (!freshMatch || freshMatch.status !== 'RUNNING') return;

          // Double check connection
          const isUserConnected = activeConnections[userId] && activeConnections[userId].length > 0;
          if (isUserConnected) {
            console.log(`Forfeit aborted for match ${matchId}: user ${userId} reconnected to socket.`);
            return;
          }

          console.log(`Match ${matchId} forfeit: user ${userId} did not reconnect within 30s.`);
          const isWhite = freshMatch.whitePlayerId?.toString() === userId;
          const winnerId = isWhite ? freshMatch.blackPlayerId?.toString() : freshMatch.whitePlayerId?.toString();
          const result = isWhite ? 'BLACK_WIN' : 'WHITE_WIN';

          if (gameTimers[matchId]) {
            clearTimeout(gameTimers[matchId]);
            delete gameTimers[matchId];
          }

          await concludeMatch(freshMatch, result, winnerId, io);
        } catch (err) {
          console.error('Error executing forfeit timeout:', err);
        } finally {
          delete forfeitTimers[key];
        }
      }, 30000);
    }
  } catch (error) {
    console.error('Error in triggerForfeitTimeout:', error);
  }
};

// Map to track connected users: userId -> Socket IDs
const activeConnections: { [userId: string]: string[] } = {};

let ioInstance: Server | null = null;

export const getIoInstance = (): Server | null => {
  return ioInstance;
};

export const setupGameSocket = (io: Server) => {
  ioInstance = io;
  // Seed bots and start scheduler
  seedBots().then(() => {
    startBotScheduler(io);
  }).catch(err => {
    console.error('Failed to seed bots or start bot scheduler:', err);
  });

  io.on('connection', (socket: Socket) => {
    const userId = socket.handshake.query.userId as string;
    if (!userId) {
      socket.disconnect();
      return;
    }

    // Register active user connection
    if (!activeConnections[userId]) {
      activeConnections[userId] = [];
    }
    activeConnections[userId].push(socket.id);
    console.log(`User connected: ${userId} (Socket: ${socket.id}). Active users: ${Object.keys(activeConnections).length}`);

    // Join Match Room
    socket.on('join_match', async ({ matchId }) => {
      socket.join(matchId);
      console.log(`Socket ${socket.id} joined match room ${matchId}`);
      
      // Clear any active forfeit timer for this user in this match
      const key = `${matchId}_${userId}`;
      if (forfeitTimers[key]) {
        console.log(`User ${userId} rejoined match room ${matchId}. Clearing forfeit timer.`);
        clearTimeout(forfeitTimers[key]);
        delete forfeitTimers[key];
      }
      
      // Send current state
      try {
        const match = await Match.findById(matchId);
        if (match) {
          socket.emit('match_state', match);
          // Set up the clock timeout if the match is running and no timer is running
          if (match.status === 'RUNNING' && !gameTimers[matchId]) {
            console.log(`Clock timeout was not running for match ${matchId}. Initializing now.`);
            setupClockTimeout(matchId, match, io);
          }
          triggerBotMoveIfActive(matchId, io);
        }
      } catch (err) {
        console.error(err);
      }
    });

    // Handle Client Move
    socket.on('make_move', async ({ matchId, from, to, promotion }) => {
      try {
        const match = await Match.findById(matchId);
        if (!match || match.status !== 'RUNNING') {
          socket.emit('move_error', { error: 'Match is not active.' });
          return;
        }

        // Verify it is this player's turn and they are in the match
        const isWhiteTurn = new Chess(match.boardFen).turn() === 'w';
        const activePlayerId = isWhiteTurn ? match.whitePlayerId : match.blackPlayerId;

        if (activePlayerId?.toString() !== userId) {
          socket.emit('move_error', { error: "It's not your turn." });
          return;
        }

        // Execute Move in Chess.js
        const chess = new Chess(match.boardFen);
        let moveResult;
        try {
          moveResult = chess.move({ from, to, promotion });
        } catch (e) {
          socket.emit('move_error', { error: 'Illegal move.' });
          return;
        }

        // Move is legal! Cancel active timeout timer for this match
        if (gameTimers[matchId]) {
          clearTimeout(gameTimers[matchId]);
          delete gameTimers[matchId];
        }

        // Append move to history
        match.moveHistory.push({
          from,
          to,
          promotion,
          san: moveResult.san,
          createdAt: new Date(),
        });
        match.boardFen = chess.fen();

        // Check for Game Ends
        if (chess.isGameOver()) {
          let winnerId: string | undefined = undefined;
          let result: 'WHITE_WIN' | 'BLACK_WIN' | 'DRAW' | undefined = undefined;

          if (chess.isCheckmate()) {
            winnerId = chess.turn() === 'w' ? match.blackPlayerId?.toString() : match.whitePlayerId?.toString();
            result = chess.turn() === 'w' ? 'BLACK_WIN' : 'WHITE_WIN';
          } else {
            result = 'DRAW'; // Stalemate, repetition, draw agreement, etc.
          }

          await concludeMatch(match, result, winnerId, io);
        } else {
          // Game goes on -> Save and broadcast state
          await match.save();
          io.to(matchId).emit('match_state', match);

          // Setup timeout trigger for next player
          setupClockTimeout(matchId, match, io);

          // Trigger bot move if next player is a bot
          triggerBotMoveIfActive(matchId, io);
        }
      } catch (error) {
        console.error('Error handling move:', error);
        socket.emit('move_error', { error: 'Failed to process move on server.' });
      }
    });

    // Handle resignation
    socket.on('resign', async ({ matchId }) => {
      try {
        const match = await Match.findById(matchId);
        if (!match || match.status !== 'RUNNING') {
          return;
        }

        const isWhite = match.whitePlayerId?.toString() === userId;
        const winnerId = isWhite ? match.blackPlayerId?.toString() : match.whitePlayerId?.toString();
        const result = isWhite ? 'BLACK_WIN' : 'WHITE_WIN';

        if (gameTimers[matchId]) {
          clearTimeout(gameTimers[matchId]);
          delete gameTimers[matchId];
        }

        await concludeMatch(match, result, winnerId, io);
      } catch (err) {
        console.error('Resignation error:', err);
      }
    });

    // Chat Message
    socket.on('send_message', ({ matchId, sender, text }) => {
      io.to(matchId).emit('new_message', { sender, text, createdAt: new Date() });
    });

    socket.on('disconnect', () => {
      console.log(`Socket disconnected: ${socket.id}`);
      if (activeConnections[userId]) {
        activeConnections[userId] = activeConnections[userId].filter((id) => id !== socket.id);
        if (activeConnections[userId].length === 0) {
          delete activeConnections[userId];
          // Start forfeit timer!
          triggerForfeitTimeout(userId, io);
        }
      }
    });
  });
};

// Helper to compute remaining seconds for each player based on move history timestamps
const calculateRemainingTimes = (match: IMatch) => {
  const matchStart = new Date(match.createdAt).getTime();
  let whiteElapsed = 0;
  let blackElapsed = 0;

  const history = match.moveHistory;
  for (let i = 0; i < history.length; i++) {
    const moveTime = new Date(history[i].createdAt).getTime();
    const startTime = i === 0 ? matchStart : new Date(history[i - 1].createdAt).getTime();
    const diffMs = moveTime - startTime;

    if (i % 2 === 0) {
      whiteElapsed += diffMs;
    } else {
      blackElapsed += diffMs;
    }
  }

  // Current turn elapsed time (if running)
  if (match.status === 'RUNNING') {
    const now = Date.now();
    const lastMoveTime = history.length > 0 ? new Date(history[history.length - 1].createdAt).getTime() : matchStart;
    const currentDiffMs = now - lastMoveTime;

    if (history.length % 2 === 0) {
      whiteElapsed += currentDiffMs;
    } else {
      blackElapsed += currentDiffMs;
    }
  }

  const whiteRemainingSec = Math.max(0, match.timeControl - Math.floor(whiteElapsed / 1000));
  const blackRemainingSec = Math.max(0, match.timeControl - Math.floor(blackElapsed / 1000));

  return { whiteRemainingSec, blackRemainingSec };
};

// Start timeout timer for active player (authoritative server clock flag fall)
const setupClockTimeout = (matchId: string, match: IMatch, io: Server) => {
  // Get remaining times for both players
  const { whiteRemainingSec, blackRemainingSec } = calculateRemainingTimes(match);

  const chess = new Chess(match.boardFen);
  const isWhiteTurn = chess.turn() === 'w';
  const remainingSec = isWhiteTurn ? whiteRemainingSec : blackRemainingSec;
  const timeoutMs = remainingSec * 1000;

  console.log(`Setting clock timeout for match ${matchId}: ${isWhiteTurn ? 'White' : 'Black'} has ${remainingSec} seconds left.`);

  // Cancel any existing timer for safety
  if (gameTimers[matchId]) {
    clearTimeout(gameTimers[matchId]);
  }

  gameTimers[matchId] = setTimeout(async () => {
    try {
      const activeMatch = await Match.findById(matchId);
      if (!activeMatch || activeMatch.status !== 'RUNNING') return;

      const currentChess = new Chess(activeMatch.boardFen);
      const currentIsWhiteTurn = currentChess.turn() === 'w';
      const winnerId = currentIsWhiteTurn ? activeMatch.blackPlayerId?.toString() : activeMatch.whitePlayerId?.toString();
      const result = currentIsWhiteTurn ? 'BLACK_WIN' : 'WHITE_WIN';

      console.log(`Match ${matchId} timed out. Winner: ${winnerId}`);
      await concludeMatch(activeMatch, result, winnerId, io);
    } catch (err) {
      console.error('Clock timeout execution error:', err);
    }
  }, timeoutMs);
};

// End Match: calculate Elo, handle payment logic, save DB records, broadcast update
const concludeMatch = async (
  match: IMatch,
  result: 'WHITE_WIN' | 'BLACK_WIN' | 'DRAW',
  winnerId: string | undefined,
  io: Server
) => {
  const session = isTransactionSupported ? await mongoose.startSession() : null;
  if (session) {
    session.startTransaction();
  }

  try {
    match.status = 'COMPLETED';
    match.result = result;
    match.winnerId = winnerId ? new mongoose.Types.ObjectId(winnerId) : undefined;
    await match.save({ session: session || undefined });

    const whiteId = match.whitePlayerId!.toString();
    const blackId = match.blackPlayerId!.toString();

    // 1. Process payouts
    if (match.entryFee > 0) {
      if (result === 'DRAW') {
        // Draw -> Refund entry fee to available balance
        await Wallet.findOneAndUpdate(
          { userId: whiteId },
          { $inc: { balance: match.entryFee, lockedBalance: -match.entryFee } },
          { session: session || undefined }
        );
        await Wallet.findOneAndUpdate(
          { userId: blackId },
          { $inc: { balance: match.entryFee, lockedBalance: -match.entryFee } },
          { session: session || undefined }
        );

        // Save transaction refund logs
        await new Transaction({
          userId: whiteId,
          amount: match.entryFee,
          type: 'MATCH_WIN',
          status: 'SUCCESS',
          description: `Entry Fee refunded due to Draw.`,
          referenceId: match._id.toString(),
        }).save({ session: session || undefined });

        await new Transaction({
          userId: blackId,
          amount: match.entryFee,
          type: 'MATCH_WIN',
          status: 'SUCCESS',
          description: `Entry Fee refunded due to Draw.`,
          referenceId: match._id.toString(),
        }).save({ session: session || undefined });

      } else {
        // Winner gets the prize pool, loser loses their locked fee
        const winner = winnerId!;
        const loser = winner === whiteId ? blackId : whiteId;

        // Deduct entry fee from loser's locked balance
        await Wallet.findOneAndUpdate(
          { userId: loser },
          { $inc: { lockedBalance: -match.entryFee } },
          { session: session || undefined }
        );

        // Credit winner: remove entry fee lock, add prize pool
        await Wallet.findOneAndUpdate(
          { userId: winner },
          { $inc: { balance: match.prizePool, lockedBalance: -match.entryFee } },
          { session: session || undefined }
        );

        // Log transaction logs
        await new Transaction({
          userId: winner,
          amount: match.prizePool,
          type: 'MATCH_WIN',
          status: 'SUCCESS',
          description: `Payout for winning match ${match._id}.`,
          referenceId: match._id.toString(),
        }).save({ session: session || undefined });
      }
    }

    // 2. Adjust Elo Ratings
    const whiteUser = await User.findById(whiteId).session(session);
    const blackUser = await User.findById(blackId).session(session);

    if (whiteUser && blackUser) {
      const eloW = whiteUser.elo;
      const eloB = blackUser.elo;

      let scoreW = 0.5;
      if (result === 'WHITE_WIN') scoreW = 1;
      if (result === 'BLACK_WIN') scoreW = 0;

      const expectedW = 1 / (1 + Math.pow(10, (eloB - eloW) / 400));
      const expectedB = 1 - expectedW;

      const scoreB = 1 - scoreW;

      const K = 32;
      const newEloW = Math.round(eloW + K * (scoreW - expectedW));
      const newEloB = Math.round(eloB + K * (scoreB - expectedB));

      whiteUser.elo = newEloW;
      blackUser.elo = newEloB;

      if (result === 'WHITE_WIN') {
        whiteUser.wins += 1;
        blackUser.losses += 1;
      } else if (result === 'BLACK_WIN') {
        whiteUser.losses += 1;
        blackUser.wins += 1;
      } else {
        whiteUser.draws += 1;
        blackUser.draws += 1;
      }

      await whiteUser.save({ session: session || undefined });
      await blackUser.save({ session: session || undefined });
    }

    // 3. Tournament updates & progression
    const tournament = await Tournament.findOne({
      status: 'ACTIVE',
      'brackets.matchId': match._id
    }).session(session);

    if (tournament) {
      console.log(`concludeMatch: Found active tournament ${tournament._id} for match ${match._id}`);

      // 3.1. Record the winner in the brackets
      const bracket = tournament.brackets.find(b => b.matchId.toString() === match._id.toString());
      if (bracket) {
        bracket.winner = winnerId ? new mongoose.Types.ObjectId(winnerId) : undefined;
      }

      // 3.2. Update scores on participants list
      if (result === 'DRAW') {
        const pW = tournament.participants.find(p => p.userId.toString() === whiteId);
        if (pW) pW.score += 0.5;
        const pB = tournament.participants.find(p => p.userId.toString() === blackId);
        if (pB) pB.score += 0.5;
      } else if (winnerId) {
        const pWinner = tournament.participants.find(p => p.userId.toString() === winnerId);
        if (pWinner) pWinner.score += 1;
      }

      // 3.3. Check if all matches in the current round are completed
      const currentRoundBrackets = tournament.brackets.filter(b => b.round === tournament.currentRound);
      const currentRoundMatchIds = currentRoundBrackets.map(b => b.matchId);

      // Fetch all these matches inside session
      const currentRoundMatches = await Match.find({
        _id: { $in: currentRoundMatchIds }
      }).session(session);

      const allCompleted = currentRoundMatches.every(m => {
        if (m._id.toString() === match._id.toString()) {
          return true; // this match is current, so it's completed
        }
        return m.status === 'COMPLETED' || m.status === 'ABORTED';
      });

      if (allCompleted) {
        console.log(`concludeMatch: All matches of Round ${tournament.currentRound} in tournament ${tournament._id} are completed.`);

        if (tournament.currentRound >= tournament.roundCount) {
          // Conclude the tournament!
          tournament.status = 'COMPLETED';
          
          let maxScore = -1;
          tournament.participants.forEach(p => {
            if (p.score > maxScore) maxScore = p.score;
          });

          const winners = tournament.participants.filter(p => p.score === maxScore && p.status === 'ACTIVE');
          if (winners.length > 0 && tournament.totalPrize > 0) {
            const payoutPerWinner = tournament.totalPrize / winners.length;
            for (const winner of winners) {
              await Wallet.findOneAndUpdate(
                { userId: winner.userId },
                { $inc: { balance: payoutPerWinner } },
                { session: session || undefined }
              );

              // Log transaction
              await new Transaction({
                userId: winner.userId,
                amount: payoutPerWinner,
                type: 'TOURNAMENT_PRIZE',
                status: 'SUCCESS',
                description: `Prize payout for winning tournament: ${tournament.name}`,
                referenceId: tournament._id.toString()
              }).save({ session: session || undefined });
            }
          }
          console.log(`concludeMatch: Concluded tournament ${tournament._id}. Winners count: ${winners.length}`);
        } else {
          // Generate next round
          tournament.currentRound += 1;
          const activeParticipants = tournament.participants.filter(p => p.status === 'ACTIVE');
          // Sort Swiss-style (by score desc)
          activeParticipants.sort((a, b) => b.score - a.score);

          const matchesToCreate = [];
          for (let i = 0; i < activeParticipants.length; i += 2) {
            if (i + 1 < activeParticipants.length) {
              const playerA = activeParticipants[i];
              const playerB = activeParticipants[i + 1];

              const newMatch = new Match({
                whitePlayerId: playerA.userId,
                blackPlayerId: playerB.userId,
                whiteUsername: playerA.username,
                blackUsername: playerB.username,
                entryFee: 0,
                prizePool: 0,
                timeControl: 600, // standard 10 mins
                status: 'RUNNING'
              });
              matchesToCreate.push(newMatch);
            } else {
              // Odd player gets a bye: they get 1 point and advance
              const oddPlayer = activeParticipants[i];
              oddPlayer.score += 1;
            }
          }

          if (matchesToCreate.length > 0) {
            const savedMatches = await Match.insertMany(matchesToCreate, session ? { session } : {});
            savedMatches.forEach(m => {
              tournament.brackets.push({
                round: tournament.currentRound,
                matchId: m._id as mongoose.Types.ObjectId,
                playerA: m.whitePlayerId!,
                playerB: m.blackPlayerId!,
              });
            });
          }
          console.log(`concludeMatch: Scheduled Round ${tournament.currentRound} for tournament ${tournament._id} with ${matchesToCreate.length} matches.`);
        }
      }

      await tournament.save({ session: session || undefined });
    }

    if (session) {
      await session.commitTransaction();
      session.endSession();
    }

    // Broadcast update
    io.to(match._id.toString()).emit('match_state', match);
    io.to(match._id.toString()).emit('game_ended', { result, winnerId });

  } catch (err) {
    if (session) {
      await session.abortTransaction();
      session.endSession();
    }
    console.error('concludeMatch Transaction Aborted:', err);
  }
};

export const triggerBotMoveIfActive = async (matchId: string, io: Server) => {
  try {
    const match = await Match.findById(matchId);
    if (!match || match.status !== 'RUNNING') return;

    const chess = new Chess(match.boardFen);
    const isWhiteTurn = chess.turn() === 'w';
    const activePlayerId = isWhiteTurn ? match.whitePlayerId : match.blackPlayerId;

    if (!activePlayerId) return;

    const activeUser = await User.findById(activePlayerId);
    if (!activeUser || !activeUser.isBot) return;

    console.log(`Bot ${activeUser.username} is thinking... Match ${match._id}`);

    // Realistic delay: 1.5 to 3.5 seconds
    const delay = 1500 + Math.random() * 2000;

    setTimeout(async () => {
      try {
        // Re-fetch match to ensure state hasn't changed (resignation, timeout, etc.)
        const currentMatch = await Match.findById(matchId);
        if (!currentMatch || currentMatch.status !== 'RUNNING') return;

        const currentChess = new Chess(currentMatch.boardFen);
        const currentIsWhiteTurn = currentChess.turn() === 'w';
        const currentActivePlayerId = currentIsWhiteTurn ? currentMatch.whitePlayerId : currentMatch.blackPlayerId;

        if (currentActivePlayerId?.toString() !== activePlayerId.toString()) return;

        let from = '';
        let to = '';
        let promotion: string | undefined = undefined;

        try {
          const fen = currentMatch.boardFen;
          // Stockfish API Depth 10
          const response = await axios.get(`https://stockfish.online/api/s/v2.php?fen=${encodeURIComponent(fen)}&depth=10`, { timeout: 4000 });
          const bestmove = response.data?.bestmove || '';
          
          if (bestmove.startsWith('bestmove')) {
            const uci = bestmove.split(' ')[1];
            if (uci && uci.length >= 4) {
              from = uci.substring(0, 2);
              to = uci.substring(2, 4);
              if (uci.length > 4) {
                promotion = uci.substring(4, 5);
              }
            }
          }
        } catch (apiError: any) {
          console.warn('Stockfish API failed, falling back to random move:', apiError.message);
        }

        // Fallback to random move if API move failed or was illegal
        let moveResult;
        const legalMoves = currentChess.moves({ verbose: true });
        if (legalMoves.length === 0) return; // Game is already over or stuck

        if (from && to) {
          try {
            moveResult = currentChess.move({ from, to, promotion });
          } catch (moveErr) {
            console.warn('Bot tried illegal API move, falling back to random move');
          }
        }

        if (!moveResult) {
          // Pick a random legal move
          const randomMove = legalMoves[Math.floor(Math.random() * legalMoves.length)];
          from = randomMove.from;
          to = randomMove.to;
          promotion = randomMove.promotion;
          moveResult = currentChess.move({ from, to, promotion });
        }

        // Update match document
        currentMatch.moveHistory.push({
          from,
          to,
          promotion,
          san: moveResult.san,
          createdAt: new Date(),
        });
        currentMatch.boardFen = currentChess.fen();

        // Check if game is over
        if (currentChess.isGameOver()) {
          let winnerId: string | undefined = undefined;
          let result: 'WHITE_WIN' | 'BLACK_WIN' | 'DRAW' | undefined = undefined;

          if (currentChess.isCheckmate()) {
            winnerId = currentChess.turn() === 'w' ? currentMatch.blackPlayerId?.toString() : currentMatch.whitePlayerId?.toString();
            result = currentChess.turn() === 'w' ? 'BLACK_WIN' : 'WHITE_WIN';
          } else {
            result = 'DRAW';
          }

          await concludeMatch(currentMatch, result, winnerId, io);
        } else {
          await currentMatch.save();
          io.to(matchId).emit('match_state', currentMatch);

          // Reset timer clocks
          if (gameTimers[matchId]) {
            clearTimeout(gameTimers[matchId]);
            delete gameTimers[matchId];
          }
          setupClockTimeout(matchId, currentMatch, io);

          // In case the next player is also a bot (highly unlikely, but safe), trigger again
          triggerBotMoveIfActive(matchId, io);
        }
      } catch (innerError) {
        console.error('Error during Bot move execution timeout:', innerError);
      }
    }, delay);
  } catch (error) {
    console.error('Error in triggerBotMoveIfActive:', error);
  }
};

export const startBotScheduler = (io: Server) => {
  console.log('Starting Grandmaster bots match-maker scheduler...');
  setInterval(async () => {
    try {
      // Find open matches created by humans
      const waitingMatches = await Match.find({ status: 'WAITING' });
      if (waitingMatches.length === 0) return;

      for (const match of waitingMatches) {
        // Concurrency check: make sure another bot didn't join in this tick
        const freshMatch = await Match.findById(match._id);
        if (!freshMatch || freshMatch.status !== 'WAITING') continue;

        // ONLY auto-join if the match was created at least 30 seconds ago
        const elapsedMs = Date.now() - new Date(freshMatch.createdAt).getTime();
        if (elapsedMs < 30000) {
          continue;
        }

        const hostId = freshMatch.whitePlayerId || freshMatch.blackPlayerId;
        if (!hostId) continue;

        const hostUser = await User.findById(hostId);
        if (!hostUser || hostUser.isBot) continue; // Skip if host is a bot or not found

        // Find a bot to join
        const bots = await User.find({ isBot: true });
        if (bots.length === 0) continue;

        const randomBot = bots[Math.floor(Math.random() * bots.length)];

        // Make the bot join the match!
        const session = isTransactionSupported ? await mongoose.startSession() : null;
        if (session) {
          session.startTransaction();
        }

        try {
          // If entryFee > 0, deduct from bot wallet
          if (freshMatch.entryFee > 0) {
            const botWallet = await Wallet.findOneAndUpdate(
              { userId: randomBot._id, balance: { $gte: freshMatch.entryFee } },
              { $inc: { balance: -freshMatch.entryFee, lockedBalance: freshMatch.entryFee } },
              { new: true, ...(session ? { session } : {}) }
            );

            if (!botWallet) {
              if (session) {
                await session.abortTransaction();
                session.endSession();
              }
              continue;
            }

            // Create transaction log for bot
            const transaction = new Transaction({
              userId: randomBot._id,
              amount: -freshMatch.entryFee,
              type: 'MATCH_ENTRY',
              status: 'SUCCESS',
              description: `Entry Fee to join match (Bot Player).`,
            });
            await transaction.save(session ? { session } : {});
          }

          // Assign bot to empty slot
          if (!freshMatch.whitePlayerId) {
            freshMatch.whitePlayerId = randomBot._id;
            freshMatch.whiteUsername = randomBot.username;
          } else {
            freshMatch.blackPlayerId = randomBot._id;
            freshMatch.blackUsername = randomBot.username;
          }

          freshMatch.status = 'RUNNING';
          await freshMatch.save(session ? { session } : {});

          if (session) {
            await session.commitTransaction();
            session.endSession();
          }

          console.log(`Bot ${randomBot.username} joined match ${freshMatch._id}`);

          // Broadcast match state update
          io.to(freshMatch._id.toString()).emit('match_state', freshMatch);

          // Setup timeout trigger for the first move
          setupClockTimeout(freshMatch._id.toString(), freshMatch, io);

          // Trigger first move if it is the bot's turn!
          triggerBotMoveIfActive(freshMatch._id.toString(), io);

        } catch (txError) {
          if (session) {
            await session.abortTransaction();
            session.endSession();
          }
          console.error(`Error in bot auto-join transaction for match ${freshMatch._id}:`, txError);
        }
      }
    } catch (err) {
      console.error('Error in bot scheduler loop:', err);
    }
  }, 15000); // Check every 15 seconds
};
