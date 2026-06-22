import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess/chess.dart' as ChessDart;
import '../../providers/auth_provider.dart';
import '../../providers/game_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _startLocalClock();
  }

  @override
  void dispose() {
    _localTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
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

    // Initial clock setup from timeControl
    if (_whiteTime == 600 && _blackTime == 600) {
      _whiteTime = match.timeControl;
      _blackTime = match.timeControl;
    }

    final opponentName = isWhitePlayer ? (match.blackUsername ?? 'Waiting...') : (match.whiteUsername ?? 'Waiting...');
    final myName = isWhitePlayer ? (match.whiteUsername ?? 'You') : (match.blackUsername ?? 'You');
    final myColor = isWhitePlayer ? 'White' : 'Black';
    final opponentColor = isWhitePlayer ? 'Black' : 'White';

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
                          opponentName,
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
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
                          '$myName (You)',
                          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
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

          // Game result banner
          if (match.status == 'COMPLETED')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: match.winnerId == authState.user?.id
                  ? const Color(0xFF4ADE80).withOpacity(0.12)
                  : Colors.redAccent.withOpacity(0.12),
              width: double.infinity,
              child: Text(
                match.result == 'DRAW'
                    ? '🤝 Match ended in a Draw. Entry fees refunded.'
                    : match.winnerId == authState.user?.id
                        ? '🏆 Congratulations! You won ₹${match.prizePool.toStringAsFixed(0)}!'
                        : '😞 Game Over. Opponent won.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: match.winnerId == authState.user?.id ? const Color(0xFF4ADE80) : Colors.redAccent[200],
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
