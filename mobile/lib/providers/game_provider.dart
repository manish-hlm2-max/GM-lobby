import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess/chess.dart' as ChessDart;
import '../models/match_model.dart';
import '../services/socket_service.dart';
import 'auth_provider.dart';

class GameState {
  final MatchModel? currentMatch;
  final List<Map<String, dynamic>> messages;
  final String? error;
  final bool isMyTurn;

  GameState({
    this.currentMatch,
    this.messages = const [],
    this.error,
    this.isMyTurn = false,
  });

  GameState copyWith({
    MatchModel? currentMatch,
    List<Map<String, dynamic>>? messages,
    String? error,
    bool? isMyTurn,
  }) {
    return GameState(
      currentMatch: currentMatch ?? this.currentMatch,
      messages: messages ?? this.messages,
      error: error ?? this.error,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }
}

class GameNotifier extends StateNotifier<GameState> {
  final SocketService _socketService = SocketService();
  final Ref ref;

  GameNotifier(this.ref) : super(GameState());

  void initMatch(MatchModel match) {
    state = GameState(currentMatch: match, messages: []);
    final userId = ref.read(authProvider).user?.id ?? '';
    
    // Connect socket and listen
    _socketService.connect(userId, onConnect: () {
      _socketService.joinMatch(match.id);
    });

    _socketService.onMatchState((data) {
      final updatedMatch = MatchModel.fromJson(data);
      final isWhite = updatedMatch.whitePlayerId == userId;
      
      // Determine turn details
      final chess = ChessDart.Chess.fromFEN(updatedMatch.boardFen);
      final isWhiteTurn = chess.turn == ChessDart.Color.WHITE;
      final isMyTurn = (isWhite && isWhiteTurn) || (!isWhite && !isWhiteTurn);

      state = state.copyWith(
        currentMatch: updatedMatch,
        isMyTurn: isMyTurn,
        error: null,
      );
    });

    _socketService.onNewMessage((data) {
      state = state.copyWith(
        messages: [...state.messages, data],
      );
    });

    _socketService.onGameEnded((data) {
      // Reload profile to reflect balance updates
      ref.read(authProvider.notifier).checkAuth();
    });

    _socketService.onMoveError((data) {
      state = state.copyWith(error: data['error']);
    });
  }

  void makeMove(String from, String to, {String? promotion}) {
    if (state.currentMatch == null) return;
    final match = state.currentMatch!;
    
    // 1. Local Optimistic Update
    try {
      final chess = ChessDart.Chess.fromFEN(match.boardFen);
      
      final success = chess.move({
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
      });
      
      if (success) {
        final lastMoveSan = chess.getHistory().last;
        
        final newHistoryItem = {
          'from': from,
          'to': to,
          'san': lastMoveSan,
          if (promotion != null) 'promotion': promotion,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        };
        
        final updatedMatch = match.copyWith(
          boardFen: chess.fen,
          moveHistory: [...match.moveHistory, newHistoryItem],
        );
        
        state = state.copyWith(
          currentMatch: updatedMatch,
          isMyTurn: false, // Optimistically hand turn over
          error: null,
        );
      }
    } catch (e) {
      // Fallback/log local prediction error silently and let the socket resolve it
      print("Optimistic update error: $e");
    }

    // 2. Server Sync
    _socketService.makeMove(match.id, from, to, promotion: promotion);
  }

  void resign() {
    if (state.currentMatch == null) return;
    _socketService.resign(state.currentMatch!.id);
  }

  void sendMessage(String sender, String text) {
    if (state.currentMatch == null) return;
    _socketService.sendMessage(state.currentMatch!.id, sender, text);
  }

  void leaveGame() {
    _socketService.disconnect();
    state = GameState();
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}

final gameProvider = StateNotifierProvider<GameNotifier, GameState>((ref) {
  return GameNotifier(ref);
});
