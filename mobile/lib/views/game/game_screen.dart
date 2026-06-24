import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess/chess.dart' as ChessDart;
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';
import '../../widgets/title_badge.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  String? _selectedSquare;
  List<String> _legalMoves = [];
  Timer? _localTimer;
  int _whiteTime = 600;
  int _blackTime = 600;
  String _activeTurn = 'w';
  
  final ScrollController _opponentScrollController = ScrollController();
  final ScrollController _playerScrollController = ScrollController();
  int _lastMoveCount = -1;

  // Guards for result dialog
  bool _isResultDialogShowing = false;
  String? _currentMatchId;

  @override
  void initState() {
    super.initState();
    // Capture the match ID we were initialized with
    final match = ref.read(gameProvider).currentMatch;
    _currentMatchId = match?.id;
    _startLocalClock();
  }

  @override
  void dispose() {
    _localTimer?.cancel();
    _opponentScrollController.dispose();
    _playerScrollController.dispose();
    // Disconnect socket and clean up state when leaving screen
    ref.read(gameProvider.notifier).leaveGame();
    super.dispose();
  }

  void _startLocalClock() {
    _localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final match = ref.read(gameProvider).currentMatch;
      if (match != null && match.status == 'RUNNING') {
        final chess = ChessDart.Chess.fromFEN(match.boardFen);
        setState(() {
          _activeTurn = chess.turn == ChessDart.Color.WHITE ? 'w' : 'b';
          if (_activeTurn == 'w') {
            if (_whiteTime > 0) _whiteTime--;
          } else {
            if (_blackTime > 0) _blackTime--;
          }
        });
      }
    });
  }

  void _calculateRemainingTimes(MatchModel match) {
    if (match.createdAt == null) return;

    final matchStart = DateTime.parse(match.createdAt!).toUtc();
    int whiteElapsedSeconds = 0;
    int blackElapsedSeconds = 0;

    final history = match.moveHistory;
    final totalMoves = history.length;

    for (int i = 0; i < totalMoves; i++) {
      final move = history[i];
      if (move is Map) {
        final moveTimeStr = move['createdAt'];
        if (moveTimeStr == null) continue;
        final moveTime = DateTime.parse(moveTimeStr).toUtc();

        DateTime startTime;
        if (i == 0) {
          startTime = matchStart;
        } else {
          final prevMove = history[i - 1];
          final prevTimeStr = (prevMove is Map) ? prevMove['createdAt'] : null;
          startTime = prevTimeStr != null
              ? DateTime.parse(prevTimeStr).toUtc()
              : matchStart;
        }

        final diff = moveTime.difference(startTime).inSeconds;
        if (i % 2 == 0) {
          // White move
          whiteElapsedSeconds += diff;
        } else {
          // Black move
          blackElapsedSeconds += diff;
        }
      }
    }

    // Now add elapsed time for the current ongoing turn
    if (match.status == 'RUNNING') {
      final now = DateTime.now().toUtc();
      DateTime lastMoveTime = matchStart;
      if (totalMoves > 0) {
        final lastMove = history[totalMoves - 1];
        final lastTimeStr = (lastMove is Map) ? lastMove['createdAt'] : null;
        if (lastTimeStr != null) {
          lastMoveTime = DateTime.parse(lastTimeStr).toUtc();
        }
      }

      final currentElapsed = now.difference(lastMoveTime).inSeconds;
      if (totalMoves % 2 == 0) {
        // It's White's turn
        whiteElapsedSeconds += currentElapsed;
      } else {
        // It's Black's turn
        blackElapsedSeconds += currentElapsed;
      }
    }

    setState(() {
      _whiteTime = (match.timeControl - whiteElapsedSeconds).clamp(0, match.timeControl);
      _blackTime = (match.timeControl - blackElapsedSeconds).clamp(0, match.timeControl);
      _lastMoveCount = totalMoves;
    });
  }

  Widget _buildMovesRow(List<String> moves, {required bool isPlayer}) {
    if (moves.isEmpty) {
      return Container(
        height: 36,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'No moves played yet',
          style: GoogleFonts.inter(color: Colors.white30, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Container(
      height: 36,
      color: const Color(0xFF16213E).withOpacity(0.3),
      child: ListView.builder(
        controller: isPlayer ? _playerScrollController : _opponentScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        itemCount: moves.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: isPlayer ? Colors.teal.withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPlayer ? Colors.teal.withOpacity(0.4) : Colors.white12,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              moves[index],
              style: GoogleFonts.inter(
                color: isPlayer ? const Color(0xFF4ADE80) : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onSquareTap(String square, ChessDart.Chess chess, bool isWhitePlayer) {
    final state = ref.read(gameProvider);
    if (state.currentMatch == null || state.currentMatch!.status != 'RUNNING') return;
    if (!state.isMyTurn) return;

    final piece = chess.get(square);

    if (_selectedSquare == null) {
      if (piece != null) {
        final isPieceWhite = piece.color == ChessDart.Color.WHITE;
        if (isPieceWhite == isWhitePlayer) {
          setState(() {
            _selectedSquare = square;
            final moves = chess.generate_moves({'square': square});
            _legalMoves = moves.map<String>((m) => m.toAlgebraic).toList();
          });
        }
      }
    } else {
      if (_legalMoves.contains(square)) {
        String? promotion;
        if (piece?.type == ChessDart.PieceType.PAWN && 
            (square.endsWith('8') || square.endsWith('1'))) {
          promotion = 'q';
        }

        ref.read(gameProvider.notifier).makeMove(
          _selectedSquare!,
          square,
          promotion: promotion,
        );

        HapticFeedback.lightImpact();

        setState(() {
          _selectedSquare = null;
          _legalMoves = [];
        });
      } else {
        if (piece != null) {
          final isPieceWhite = piece.color == ChessDart.Color.WHITE;
          if (isPieceWhite == isWhitePlayer) {
            setState(() {
              _selectedSquare = square;
              final moves = chess.generate_moves({'square': square});
              _legalMoves = moves.map<String>((m) => m.toAlgebraic).toList();
            });
            return;
          }
        }
        setState(() {
          _selectedSquare = null;
          _legalMoves = [];
        });
      }
    }
  }

  // White pieces use outlined unicode (♙♘♗♖♕♔), black pieces use filled unicode (♟♞♝♜♛♚)
  String _getPieceUnicode(ChessDart.Piece? piece) {
    if (piece == null) return '';
    final isWhite = piece.color == ChessDart.Color.WHITE;
    switch (piece.type) {
      case ChessDart.PieceType.PAWN:
        return isWhite ? '♙' : '♟';
      case ChessDart.PieceType.KNIGHT:
        return isWhite ? '♘' : '♞';
      case ChessDart.PieceType.BISHOP:
        return isWhite ? '♗' : '♝';
      case ChessDart.PieceType.ROOK:
        return isWhite ? '♖' : '♜';
      case ChessDart.PieceType.QUEEN:
        return isWhite ? '♕' : '♛';
      case ChessDart.PieceType.KING:
        return isWhite ? '♔' : '♚';
      default:
        return '';
    }
  }

  void _showResultDialog(BuildContext context, MatchModel match, String? currentUserId) {
    final isDraw = match.result == 'DRAW';
    final isWinner = match.winnerId == currentUserId;
    
    String titleText;
    String statusText;
    Color statusColor;
    String description;
    IconData statusIcon;
    List<Color> gradientColors;
    
    if (isDraw) {
      titleText = 'DRAW';
      statusText = 'Draw Match';
      statusColor = Colors.orangeAccent;
      description = 'Match ended in a draw. Both players fought well!';
      statusIcon = Icons.handshake_rounded;
      gradientColors = [const Color(0xFF2C3E50), const Color(0xFF3498DB)];
    } else if (isWinner) {
      titleText = 'VICTORY';
      statusText = 'You Won!';
      statusColor = const Color(0xFF4ADE80);
      description = 'Congratulations on your spectacular win!';
      statusIcon = Icons.emoji_events_rounded;
      gradientColors = [const Color(0xFF134E5E), const Color(0xFF71B280)];
    } else {
      titleText = 'DEFEAT';
      statusText = 'You Lost';
      statusColor = Colors.redAccent;
      description = 'Better luck next time! Keep practicing.';
      statusIcon = Icons.trending_down_rounded;
      gradientColors = [const Color(0xFF430000), const Color(0xFF9E1010)];
    }

    final winnerName = match.winnerId == match.whitePlayerId
        ? (match.whiteUsername ?? 'White Player')
        : (match.blackUsername ?? 'Black Player');

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Result Dialog',
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeInOutBack.transform(anim1.value),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              content: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1F2937),
                      Color(0xFF111827),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.15),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glowing Icon Container
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          statusIcon,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Result title
                    Text(
                      titleText,
                      style: GoogleFonts.outfit(
                        color: statusColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Elo change badge
                    () {
                      final isWhite = match.whitePlayerId == currentUserId;
                      final eloChange = isWhite ? match.whiteEloChange : match.blackEloChange;
                      if (eloChange == null) return const SizedBox.shrink();

                      final isPositive = eloChange > 0;
                      final isNegative = eloChange < 0;
                      final color = isPositive
                          ? const Color(0xFF4ADE80)
                          : (isNegative ? Colors.redAccent : Colors.white60);
                      final sign = isPositive ? '+' : '';

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withOpacity(0.15), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPositive
                                    ? Icons.trending_up_rounded
                                    : (isNegative ? Icons.trending_down_rounded : Icons.trending_flat_rounded),
                                color: color,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Rating: $sign$eloChange',
                                style: GoogleFonts.inter(
                                  color: color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }(),
                    const SizedBox(height: 16),
                    // Player details card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'White Player',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      buildTitleBadge(match.whiteTitle, fontSize: 9, rightMargin: 4),
                                      TextSpan(
                                        text: match.whiteUsername ?? 'White',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (match.whiteEloChange != null)
                                        TextSpan(
                                          text: ' (${match.whiteEloChange! > 0 ? '+' : ''}${match.whiteEloChange})',
                                          style: GoogleFonts.inter(
                                            color: match.whiteEloChange! > 0
                                                ? const Color(0xFF4ADE80)
                                                : (match.whiteEloChange! < 0 ? Colors.redAccent : Colors.white60),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                    ],
                                  ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white10, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Black Player',
                                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      buildTitleBadge(match.blackTitle, fontSize: 9, rightMargin: 4),
                                      TextSpan(
                                        text: match.blackUsername ?? 'Black',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (match.blackEloChange != null)
                                        TextSpan(
                                          text: ' (${match.blackEloChange! > 0 ? '+' : ''}${match.blackEloChange})',
                                          style: GoogleFonts.inter(
                                            color: match.blackEloChange! > 0
                                                ? const Color(0xFF4ADE80)
                                                : (match.blackEloChange! < 0 ? Colors.redAccent : Colors.white60),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                    ],
                                  ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (!isDraw) ...[
                            const Divider(color: Colors.white10, height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Winner',
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    winnerName,
                                    textAlign: TextAlign.end,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF4ADE80),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (match.prizePool > 0) ...[
                            const Divider(color: Colors.white10, height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Prize Pool',
                                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                                ),
                                Text(
                                  '₹${match.prizePool.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(
                                    color: const Color(0xFFFFD700),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Action button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: statusColor,
                        foregroundColor: Colors.white,
                        shadowColor: statusColor.withOpacity(0.5),
                        elevation: 8,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context); // Pop result dialog
                        Navigator.pop(context); // Pop GameScreen
                      },
                      child: Text(
                        'Close',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for turn transitions to trigger haptics and game over dialog
    ref.listen<GameState>(gameProvider, (previous, next) {
      if (next.currentMatch != null) {
        // Only react to events for the match this screen was initialized with
        if (_currentMatchId != null && next.currentMatch!.id != _currentMatchId) {
          return;
        }

        if (previous != null) {
          final wasMyTurn = previous.isMyTurn;
          final isMyTurnNow = next.isMyTurn;
          if (!wasMyTurn && isMyTurnNow && next.currentMatch!.status == 'RUNNING') {
            HapticFeedback.vibrate();
          }
        }
        if (next.currentMatch!.status == 'COMPLETED' && !_isResultDialogShowing) {
          final prevStatus = previous?.currentMatch?.status;
          if (prevStatus != 'COMPLETED') {
            _isResultDialogShowing = true;
            ref.read(gameProvider.notifier).markResultShown();
            _showResultDialog(context, next.currentMatch!, authState.user?.id);
          }
        }
      }
    });

    final gameState = ref.watch(gameProvider);
    final match = gameState.currentMatch;

    if (match == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF030712),
        body: Center(child: CircularProgressIndicator(color: Colors.teal)),
      );
    }

    final isWhitePlayer = match.whitePlayerId == authState.user?.id;
    final chess = ChessDart.Chess.fromFEN(match.boardFen);

    String? lastMoveFrom;
    String? lastMoveTo;
    if (match.moveHistory.isNotEmpty) {
      final lastMove = match.moveHistory.last;
      if (lastMove is Map) {
        lastMoveFrom = lastMove['from']?.toString();
        lastMoveTo = lastMove['to']?.toString();
      }
    }

    if (_lastMoveCount != match.moveHistory.length) {
      _lastMoveCount = match.moveHistory.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateRemainingTimes(match);
        if (_opponentScrollController.hasClients) {
          _opponentScrollController.jumpTo(_opponentScrollController.position.maxScrollExtent);
        }
        if (_playerScrollController.hasClients) {
          _playerScrollController.jumpTo(_playerScrollController.position.maxScrollExtent);
        }
      });
    }

    final history = match.moveHistory;
    final List<String> opponentMoves = [];
    final List<String> playerMoves = [];

    for (int i = 0; i < history.length; i++) {
      final move = history[i];
      if (move is Map) {
        final san = move['san'] as String? ?? '';
        final moveNum = (i ~/ 2) + 1;
        final isWhiteMove = i % 2 == 0;
        
        if (isWhitePlayer) {
          if (isWhiteMove) {
            playerMoves.add('$moveNum. $san');
          } else {
            opponentMoves.add('$moveNum... $san');
          }
        } else {
          if (isWhiteMove) {
            opponentMoves.add('$moveNum. $san');
          } else {
            playerMoves.add('$moveNum... $san');
          }
        }
      }
    }

    final opponentName = isWhitePlayer ? (match.blackUsername ?? 'Waiting...') : (match.whiteUsername ?? 'Waiting...');
    final myName = isWhitePlayer ? (match.whiteUsername ?? 'You') : (match.blackUsername ?? 'You');
    final opponentTitle = isWhitePlayer ? match.blackTitle : match.whiteTitle;
    final myTitle = isWhitePlayer ? match.whiteTitle : match.blackTitle;
    final myColor = isWhitePlayer ? 'White' : 'Black';
    final opponentColor = isWhitePlayer ? 'Black' : 'White';
    final opponentElo = isWhitePlayer ? match.blackElo : match.whiteElo;
    final myElo = isWhitePlayer ? match.whiteElo : match.blackElo;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          match.entryFee > 0 ? '₹${match.entryFee.toStringAsFixed(0)} Match' : 'Free Match',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (match.status == 'RUNNING')
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF16213E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Resign?', style: TextStyle(color: Colors.white)),
                    content: const Text('Are you sure you want to resign the match?', style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ref.read(gameProvider.notifier).resign();
                        },
                        child: const Text('Resign', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Resign', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Opponent info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF16213E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isWhitePlayer ? Colors.black87 : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          opponentName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: isWhitePlayer ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$opponentName  (${opponentElo ?? 1200})',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        buildFullTitleBadge(opponentTitle),
                        Text(
                          opponentColor,
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _activeTurn == (isWhitePlayer ? 'b' : 'w')
                        ? const Color(0xFF4ADE80).withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _activeTurn == (isWhitePlayer ? 'b' : 'w')
                          ? const Color(0xFF4ADE80)
                          : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _formatTime(isWhitePlayer ? _blackTime : _whiteTime),
                    style: GoogleFonts.outfit(
                      color: _activeTurn == (isWhitePlayer ? 'b' : 'w') ? const Color(0xFF4ADE80) : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Opponent moves row
          _buildMovesRow(opponentMoves, isPlayer: false),

          // Chess Board - expanded to fill available space
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF3D2B1F), width: 4),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 64,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                    itemBuilder: (context, index) {
                      final displayIndex = isWhitePlayer ? index : 63 - index;
                      final fileIndex = displayIndex % 8;
                      final rankIndex = 8 - (displayIndex ~/ 8);
                      
                      final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
                      final square = '$file$rankIndex';

                      // Chess.com board colors
                      final isLightSquare = (fileIndex + (displayIndex ~/ 8)) % 2 == 0;
                      final squareColor = isLightSquare ? const Color(0xFFEEEED2) : const Color(0xFF769656);

                      final piece = chess.get(square);
                      final isSelected = _selectedSquare == square;
                      final isLegalDest = _legalMoves.contains(square);

                      Color tileColor = squareColor;
                      if (square == lastMoveFrom || square == lastMoveTo) {
                        tileColor = isLightSquare
                            ? const Color(0xFFF7F785) // Chess.com style light yellow
                            : const Color(0xFFBACA44); // Chess.com style dark yellow
                      }

                      if (isSelected) {
                        tileColor = const Color(0xFFF7F769);
                      } else if (isLegalDest && piece != null) {
                        // Capture highlight - reddish tint
                        tileColor = isLightSquare
                            ? const Color(0xFFE8C36A)
                            : const Color(0xFFBAAA33);
                      }

                      return GestureDetector(
                        onTap: () => _onSquareTap(square, chess, isWhitePlayer),
                        child: Container(
                          color: tileColor,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Rank and File labels
                              if (fileIndex == 0)
                                Positioned(
                                  top: 2,
                                  left: 2,
                                  child: Text(
                                    '$rankIndex',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isLightSquare ? const Color(0xFF769656) : const Color(0xFFEEEED2),
                                    ),
                                  ),
                                ),
                              if (rankIndex == (isWhitePlayer ? 1 : 8))
                                Positioned(
                                  bottom: 1,
                                  right: 2,
                                  child: Text(
                                    file,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: isLightSquare ? const Color(0xFF769656) : const Color(0xFFEEEED2),
                                    ),
                                  ),
                                ),

                              // Chess piece
                              if (piece != null)
                                Text(
                                  _getPieceUnicode(piece),
                                  style: TextStyle(
                                    fontSize: 34,
                                    color: piece.color == ChessDart.Color.WHITE
                                        ? Colors.white
                                        : Colors.black87,
                                    height: 1.0,
                                    shadows: [
                                      Shadow(
                                        color: piece.color == ChessDart.Color.WHITE
                                            ? Colors.black54
                                            : Colors.black26,
                                        blurRadius: 3,
                                        offset: const Offset(1, 1),
                                      ),
                                    ],
                                  ),
                                ),

                              // Legal move dot
                              if (isLegalDest && piece == null)
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                ),

                              // Capture ring indicator
                              if (isLegalDest && piece != null)
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.18),
                                      width: 4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Player moves row
          _buildMovesRow(playerMoves, isPlayer: true),

          // Player info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF16213E),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isWhitePlayer ? Colors.white : Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          myName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: isWhitePlayer ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$myName (You)  (${myElo ?? 1200})',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        buildFullTitleBadge(myTitle),
                        Text(
                          myColor,
                          style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _activeTurn == (isWhitePlayer ? 'w' : 'b')
                        ? const Color(0xFF4ADE80).withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _activeTurn == (isWhitePlayer ? 'w' : 'b')
                          ? const Color(0xFF4ADE80)
                          : Colors.white12,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _formatTime(isWhitePlayer ? _whiteTime : _blackTime),
                    style: GoogleFonts.outfit(
                      color: _activeTurn == (isWhitePlayer ? 'w' : 'b') ? const Color(0xFF4ADE80) : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }
}
