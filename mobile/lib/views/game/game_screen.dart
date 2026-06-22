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
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
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
    _messageController.dispose();
    _scrollController.dispose();
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

  // Convert time in seconds to mm:ss format
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
      // Select piece
      if (piece != null) {
        // verify piece matches user's color
        final isPieceWhite = piece.color == ChessDart.Color.WHITE;
        if (isPieceWhite == isWhitePlayer) {
          setState(() {
            _selectedSquare = square;
            // Get legal destination squares for the selected piece
            final moves = chess.generate_moves(options: {'square': square});
            _legalMoves = moves.map((m) => m.toAlgebraic()).toList();
          });
        }
      }
    } else {
      // Execute Move or Re-select
      if (_legalMoves.contains(square)) {
        // Check for promotion (default to queen for simplicity)
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
        // Re-select if tapped on own piece again
        if (piece != null) {
          final isPieceWhite = piece.color == ChessDart.Color.WHITE;
          if (isPieceWhite == isWhitePlayer) {
            setState(() {
              _selectedSquare = square;
              final moves = chess.generate_moves(options: {'square': square});
              _legalMoves = moves.map((m) => m.toAlgebraic()).toList();
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

  String _getPieceUnicode(ChessDart.Piece? piece) {
    if (piece == null) return '';
    switch (piece.type) {
      case ChessDart.PieceType.PAWN:
        return '♟';
      case ChessDart.PieceType.KNIGHT:
        return '♞';
      case ChessDart.PieceType.BISHOP:
        return '♝';
      case ChessDart.PieceType.ROOK:
        return '♜';
      case ChessDart.PieceType.QUEEN:
        return '♛';
      case ChessDart.PieceType.KING:
        return '♚';
      default:
        return '';
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final username = ref.read(authProvider).user?.username ?? 'Guest';
    ref.read(gameProvider.notifier).sendMessage(username, text);
    _messageController.clear();
    // Scroll chat to bottom
    Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
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

    // Determine opponent name and rating
    final opponentName = isWhitePlayer ? (match.blackUsername ?? 'Waiting...') : (match.whiteUsername ?? 'Waiting...');
    final myName = isWhitePlayer ? (match.whiteUsername ?? 'You') : (match.blackUsername ?? 'You');

    return Scaffold(
      backgroundColor: const Color(0xFF030712),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text('Wager Match: \$${match.entryFee.toStringAsFixed(2)}'),
        actions: [
          if (match.status == 'RUNNING')
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF0F172A),
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
          // Opponent details & Timer bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: Colors.white12, child: Text(opponentName.substring(0, 1).toUpperCase())),
                    const SizedBox(width: 8),
                    Text(opponentName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _activeTurn == (isWhitePlayer ? 'b' : 'w') ? Colors.amber.withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _activeTurn == (isWhitePlayer ? 'b' : 'w') ? Colors.amber : Colors.transparent),
                  ),
                  child: Text(
                    _formatTime(isWhitePlayer ? _blackTime : _whiteTime),
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // Chess Board Grid
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white10, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 64,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemBuilder: (context, index) {
                  // If black player, reverse index to flip board
                  final displayIndex = isWhitePlayer ? index : 63 - index;
                  final fileIndex = displayIndex % 8;
                  final rankIndex = 8 - (displayIndex ~/ 8);
                  
                  final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
                  final square = '$file$rankIndex';

                  final isLightSquare = (fileIndex + (displayIndex ~/ 8)) % 2 == 0;
                  final squareColor = isLightSquare ? const Color(0xFFF1F5F9) : const Color(0xFF334155);

                  final piece = chess.get(square);
                  final isSelected = _selectedSquare == square;
                  final isLegalDest = _legalMoves.contains(square);

                  return GestureDetector(
                    onTap: () => _onSquareTap(square, chess, isWhitePlayer),
                    child: Container(
                      color: isSelected 
                          ? Colors.teal.withOpacity(0.6) 
                          : isLegalDest 
                              ? Colors.teal.withOpacity(0.3) 
                              : squareColor,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Piece Vector Drawing
                          if (piece != null)
                            Text(
                              _getPieceUnicode(piece),
                              style: TextStyle(
                                fontSize: 32,
                                color: piece.color == ChessDart.Color.WHITE ? Colors.white : Colors.black,
                                shadows: const [
                                  Shadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 1)),
                                ],
                              ),
                            ),
                          // Highlight dots for legal moves
                          if (isLegalDest && piece == null)
                            Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Player details & Timer bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: Colors.teal[400], child: Text(myName.substring(0, 1).toUpperCase())),
                    const SizedBox(width: 8),
                    Text('$myName (You)', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _activeTurn == (isWhitePlayer ? 'w' : 'b') ? Colors.amber.withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _activeTurn == (isWhitePlayer ? 'w' : 'b') ? Colors.amber : Colors.transparent),
                  ),
                  child: Text(
                    _formatTime(isWhitePlayer ? _whiteTime : _blackTime),
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          // Game status notifications or outcomes
          if (match.status == 'COMPLETED')
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.teal.withOpacity(0.15),
              width: double.infinity,
              child: Text(
                match.result == 'DRAW' 
                    ? 'Match ended in a Draw. Entry fees refunded.' 
                    : match.winnerId == authState.user?.id 
                        ? 'Congratulations! You won the prize pool!' 
                        : 'Game Over. Opponent won.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.teal[300], fontWeight: FontWeight.bold),
              ),
            ),

          // Live Chat Log
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: gameState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = gameState.messages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${msg['sender']}: ',
                                  style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: '${msg['text']}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Send message...',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.04),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.teal),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
