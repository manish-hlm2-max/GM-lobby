import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess/chess.dart' as ChessDart;
import '../../models/match_model.dart';
import '../../providers/auth_provider.dart';

class MatchReplayScreen extends ConsumerStatefulWidget {
  final MatchModel match;
  const MatchReplayScreen({super.key, required this.match});

  @override
  ConsumerState<MatchReplayScreen> createState() => _MatchReplayScreenState();
}

class _MatchReplayScreenState extends ConsumerState<MatchReplayScreen> {
  int _currentMoveIndex = 0;
  String _currentFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  bool _isPlaying = false;
  Timer? _autoPlayTimer;
// ... (rest of imports and declarations match)

  @override
  void initState() {
    super.initState();
    // Start at the end of the match
    _currentMoveIndex = widget.match.moveHistory.length;
    _updateBoardFen();
  }

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  void _updateBoardFen() {
    final chess = ChessDart.Chess();
    for (int i = 0; i < _currentMoveIndex; i++) {
      final move = widget.match.moveHistory[i] as Map<String, dynamic>;
      final from = move['from'] as String;
      final to = move['to'] as String;
      final promotion = move['promotion'] as String?;
      
      chess.move({
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
      });
    }
    setState(() {
      _currentFen = chess.fen;
    });
  }

  void _stepFirst() {
    _stopPlayback();
    setState(() {
      _currentMoveIndex = 0;
      _updateBoardFen();
    });
  }

  void _stepPrevious() {
    _stopPlayback();
    if (_currentMoveIndex > 0) {
      setState(() {
        _currentMoveIndex--;
        _updateBoardFen();
      });
    }
  }

  void _stepNext() {
    _stopPlayback();
    if (_currentMoveIndex < widget.match.moveHistory.length) {
      setState(() {
        _currentMoveIndex++;
        _updateBoardFen();
      });
    }
  }

  void _stepLast() {
    _stopPlayback();
    setState(() {
      _currentMoveIndex = widget.match.moveHistory.length;
      _updateBoardFen();
    });
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    if (_currentMoveIndex >= widget.match.moveHistory.length) {
      setState(() {
        _currentMoveIndex = 0;
        _updateBoardFen();
      });
    }
    setState(() {
      _isPlaying = true;
    });
    // Set a timer to step forward every 1.5 seconds
    _autoPlayTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) {
      if (_currentMoveIndex < widget.match.moveHistory.length) {
        setState(() {
          _currentMoveIndex++;
          _updateBoardFen();
        });
      } else {
        _stopPlayback();
      }
    });
  }

  void _stopPlayback() {
    if (_isPlaying) {
      _autoPlayTimer?.cancel();
      setState(() {
        _isPlaying = false;
      });
    }
  }

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
    final currentUserId = ref.watch(authProvider).user?.id;
    final isWhitePlayer = widget.match.whitePlayerId == currentUserId;
    
    final opponentName = isWhitePlayer ? (widget.match.blackUsername ?? 'Opponent') : (widget.match.whiteUsername ?? 'Opponent');
    final myName = isWhitePlayer ? (widget.match.whiteUsername ?? 'You') : (widget.match.blackUsername ?? 'You');
    
    final chess = ChessDart.Chess.fromFEN(_currentFen);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Match Review',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Opponent info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isWhitePlayer ? Colors.black87 : Colors.white,
                  child: Text(
                    opponentName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: isWhitePlayer ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  opponentName,
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  isWhitePlayer ? 'Black' : 'White',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          // Chess Board
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF3D2B1F), width: 4),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 64,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemBuilder: (context, index) {
                  // White player sees white at the bottom; black player sees black at bottom
                  final displayIndex = isWhitePlayer ? index : 63 - index;
                  final fileIndex = displayIndex % 8;
                  final rankIndex = 8 - (displayIndex ~/ 8);
                  
                  final file = String.fromCharCode('a'.codeUnitAt(0) + fileIndex);
                  final square = '$file$rankIndex';

                  final isLightSquare = (fileIndex + (displayIndex ~/ 8)) % 2 == 0;
                  final squareColor = isLightSquare ? const Color(0xFFEEEED2) : const Color(0xFF769656);

                  final piece = chess.get(square);

                  // Highlight move squares if applicable
                  bool isLastMoveSquare = false;
                  if (_currentMoveIndex > 0) {
                    final prevMove = widget.match.moveHistory[_currentMoveIndex - 1] as Map<String, dynamic>;
                    if (prevMove['from'] == square || prevMove['to'] == square) {
                      isLastMoveSquare = true;
                    }
                  }

                  Color tileColor = squareColor;
                  if (isLastMoveSquare) {
                    tileColor = const Color(0xFFF7F769).withOpacity(0.6);
                  }

                  return Container(
                    color: tileColor,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // File and rank labels
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

                        // Piece
                        if (piece != null)
                          Text(
                            _getPieceUnicode(piece),
                            style: TextStyle(
                              fontSize: 34,
                              color: piece.color == ChessDart.Color.WHITE
                                  ? Colors.white
                                  : Colors.black87,
                              height: 1.0,
                              shadows: const [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 2,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Player info bar (Self)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF16213E),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isWhitePlayer ? Colors.white : Colors.black87,
                  child: Text(
                    myName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: isWhitePlayer ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$myName (You)',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                Text(
                  isWhitePlayer ? 'White' : 'Black',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),

          // Playback Controls
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: const Color(0xFF0F172A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page_rounded, color: Colors.tealAccent, size: 28),
                  onPressed: _stepFirst,
                  tooltip: 'First Move',
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_before_rounded, color: Colors.tealAccent, size: 28),
                  onPressed: _stepPrevious,
                  tooltip: 'Previous Move',
                ),
                IconButton(
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: Colors.tealAccent,
                    size: 40,
                  ),
                  onPressed: _togglePlayback,
                  tooltip: _isPlaying ? 'Pause' : 'Autoplay',
                ),
                IconButton(
                  icon: const Icon(Icons.navigate_next_rounded, color: Colors.tealAccent, size: 28),
                  onPressed: _stepNext,
                  tooltip: 'Next Move',
                ),
                IconButton(
                  icon: const Icon(Icons.last_page_rounded, color: Colors.tealAccent, size: 28),
                  onPressed: _stepLast,
                  tooltip: 'Final Board State',
                ),
              ],
            ),
          ),

          // Moves List
          Expanded(
            child: Container(
              color: const Color(0xFF030712),
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Moves History (${_currentMoveIndex} / ${widget.match.moveHistory.length})',
                    style: GoogleFonts.outfit(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(widget.match.moveHistory.length, (idx) {
                          final move = widget.match.moveHistory[idx] as Map<String, dynamic>;
                          final san = move['san'] as String;
                          final isSelected = _currentMoveIndex == idx + 1;
                          final isWhiteMove = idx % 2 == 0;
                          final moveNum = (idx ~/ 2) + 1;
                          
                          String label = '';
                          if (isWhiteMove) {
                            label = '$moveNum. $san';
                          } else {
                            label = san;
                          }

                          return GestureDetector(
                            onTap: () {
                              _stopPlayback();
                              setState(() {
                                _currentMoveIndex = idx + 1;
                                _updateBoardFen();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.tealAccent.withOpacity(0.15) : Colors.white.withOpacity(0.02),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Colors.tealAccent : Colors.white.withOpacity(0.05),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.inter(
                                  color: isSelected ? Colors.tealAccent : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
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


