import { Server, Socket } from 'socket.io';
import { Chess } from 'chess.js';
import mongoose from 'mongoose';
import { Match, IMatch } from '../models/Match';
import { User } from '../models/User';
import { Wallet } from '../models/Wallet';
import { Transaction } from '../models/Transaction';

// Map of active timers for running games
const gameTimers: { [matchId: string]: NodeJS.Timeout } = {};

// Map to track connected users: userId -> Socket IDs
const activeConnections: { [userId: string]: string[] } = {};

export const setupGameSocket = (io: Server) => {
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
      
      // Send current state
      try {
        const match = await Match.findById(matchId);
        if (match) {
          socket.emit('match_state', match);
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
        }
      }
    });
  });
};

// Start timeout timer for active player (authoritative server clock flag fall)
const setupClockTimeout = (matchId: string, match: IMatch, io: Server) => {
  // Simple check: we just trigger flag fall after timeControl / sides
  // For standard 10m chess without increments, we can set timeout for the remaining player time.
  // In a production app, we would subtract elapsed time.
  // We'll set a simple fallback: if no moves made in timeControl (e.g. 10 mins), opponent wins.
  const timeoutMs = match.timeControl * 1000;
  
  gameTimers[matchId] = setTimeout(async () => {
    try {
      const activeMatch = await Match.findById(matchId);
      if (!activeMatch || activeMatch.status !== 'RUNNING') return;

      const chess = new Chess(activeMatch.boardFen);
      const isWhiteTurn = chess.turn() === 'w';
      const winnerId = isWhiteTurn ? activeMatch.blackPlayerId?.toString() : activeMatch.whitePlayerId?.toString();
      const result = isWhiteTurn ? 'BLACK_WIN' : 'WHITE_WIN';

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
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    match.status = 'COMPLETED';
    match.result = result;
    match.winnerId = winnerId ? new mongoose.Types.ObjectId(winnerId) : undefined;
    await match.save({ session });

    const whiteId = match.whitePlayerId!.toString();
    const blackId = match.blackPlayerId!.toString();

    // 1. Process payouts
    if (match.entryFee > 0) {
      if (result === 'DRAW') {
        // Draw -> Refund entry fee to available balance
        await Wallet.findOneAndUpdate(
          { userId: whiteId },
          { $inc: { balance: match.entryFee, lockedBalance: -match.entryFee } },
          { session }
        );
        await Wallet.findOneAndUpdate(
          { userId: blackId },
          { $inc: { balance: match.entryFee, lockedBalance: -match.entryFee } },
          { session }
        );

        // Save transaction refund logs
        await new Transaction({
          userId: whiteId,
          amount: match.entryFee,
          type: 'MATCH_WIN',
          status: 'SUCCESS',
          description: `Entry Fee refunded due to Draw.`,
          referenceId: match._id.toString(),
        }).save({ session });

        await new Transaction({
          userId: blackId,
          amount: match.entryFee,
          type: 'MATCH_WIN',
          status: 'SUCCESS',
          description: `Entry Fee refunded due to Draw.`,
          referenceId: match._id.toString(),
        }).save({ session });

      } else {
        // Winner gets the prize pool, loser loses their locked fee
        const winner = winnerId!;
        const loser = winner === whiteId ? blackId : whiteId;

        // Deduct entry fee from loser's locked balance
        await Wallet.findOneAndUpdate(
          { userId: loser },
          { $inc: { lockedBalance: -match.entryFee } },
          { session }
        );

        // Credit winner: remove entry fee lock, add prize pool
        await Wallet.findOneAndUpdate(
          { userId: winner },
          { $inc: { balance: match.prizePool, lockedBalance: -match.entryFee } },
          { session }
        );

        // Log transaction logs
        await new Transaction({
          userId: winner,
          amount: match.prizePool,
          type: 'MATCH_WIN',
          status: 'SUCCESS',
          description: `Payout for winning match ${match._id}.`,
          referenceId: match._id.toString(),
        }).save({ session });
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

      await whiteUser.save({ session });
      await blackUser.save({ session });
    }

    await session.commitTransaction();
    session.endSession();

    // Broadcast update
    io.to(match._id.toString()).emit('match_state', match);
    io.to(match._id.toString()).emit('game_ended', { result, winnerId });

  } catch (err) {
    await session.abortTransaction();
    session.endSession();
    console.error('concludeMatch Transaction Aborted:', err);
  }
};
