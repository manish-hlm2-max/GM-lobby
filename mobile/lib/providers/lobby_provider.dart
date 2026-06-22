import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_model.dart';
import '../models/tournament_model.dart';
import '../services/match_service.dart';
import '../services/tournament_service.dart';

class LobbyState {
  final List<MatchModel> openMatches;
  final List<TournamentModel> tournaments;
  final bool isLoading;
  final String? error;

  LobbyState({
    required this.openMatches,
    required this.tournaments,
    this.isLoading = false,
    this.error,
  });

  LobbyState copyWith({
    List<MatchModel>? openMatches,
    List<TournamentModel>? tournaments,
    bool? isLoading,
    String? error,
  }) {
    return LobbyState(
      openMatches: openMatches ?? this.openMatches,
      tournaments: tournaments ?? this.tournaments,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class LobbyNotifier extends StateNotifier<LobbyState> {
  final MatchService _matchService = MatchService();
  final TournamentService _tournamentService = TournamentService();

  LobbyNotifier() : super(LobbyState(openMatches: [], tournaments: []));

  Future<void> refreshLobby() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final matches = await _matchService.getOpenMatches();
      final tournaments = await _tournamentService.getTournaments();
      state = LobbyState(
        openMatches: matches,
        tournaments: tournaments,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<MatchModel?> createMatch(double entryFee, int timeControl, String preferredColor) async {
    final res = await _matchService.createMatch(
      entryFee: entryFee,
      timeControl: timeControl,
      preferredColor: preferredColor,
    );
    if (res['success'] == true) {
      refreshLobby();
      return res['match'];
    }
    return null;
  }

  Future<MatchModel?> joinMatch(String matchId) async {
    final res = await _matchService.joinMatch(matchId);
    if (res['success'] == true) {
      refreshLobby();
      return res['match'];
    }
    return null;
  }

  Future<bool> registerTournament(String tournamentId) async {
    final res = await _tournamentService.registerTournament(tournamentId);
    if (res['success'] == true) {
      refreshLobby();
      return true;
    }
    return false;
  }
}

final lobbyProvider = StateNotifierProvider<LobbyNotifier, LobbyState>((ref) {
  return LobbyNotifier();
});
