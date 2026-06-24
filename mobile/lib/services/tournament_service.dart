import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';
import '../models/tournament_model.dart';

class TournamentService {
  final AuthService _authService = AuthService();

  Future<List<TournamentModel>> getTournaments() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.tournamentsList),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['tournaments'] as List;
        return list.map((item) => TournamentModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching tournaments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> registerTournament(String tournamentId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.registerTournament),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'tournamentId': tournamentId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'tournament': TournamentModel.fromJson(data['tournament']),
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Registration failed.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> matchmakeTournament(String tournamentId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tournament/matchmake'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'tournamentId': tournamentId}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {
          'success': true,
          'match': data['match'],
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Matchmaking failed.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ── Admin Methods ──

  Future<Map<String, dynamic>> adminCreateTournament({
    required String name,
    required double entryFee,
    required double totalPrize,
    required String scheduledStartTime,
    required int roundCount,
    required int roundDurationSeconds,
    String type = 'LEAGUE_5_DAY',
  }) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tournament/admin/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'entryFee': entryFee,
          'totalPrize': totalPrize,
          'scheduledStartTime': scheduledStartTime,
          'roundCount': roundCount,
          'roundDurationSeconds': roundDurationSeconds,
          'type': type,
        }),
      );

      final data = jsonDecode(response.body);
      return {'success': data['success'] == true, 'error': data['error']};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> adminEditTournament({
    required String tournamentId,
    String? name,
    double? totalPrize,
    int? roundCount,
    int? roundDurationSeconds,
  }) async {
    try {
      final token = await _authService.getToken();
      final body = <String, dynamic>{'tournamentId': tournamentId};
      if (name != null) body['name'] = name;
      if (totalPrize != null) body['totalPrize'] = totalPrize;
      if (roundCount != null) body['roundCount'] = roundCount;
      if (roundDurationSeconds != null) body['roundDurationSeconds'] = roundDurationSeconds;

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tournament/admin/edit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);
      return {'success': data['success'] == true, 'error': data['error']};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> adminStartTournament(String tournamentId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tournament/admin/start'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'tournamentId': tournamentId}),
      );

      final data = jsonDecode(response.body);
      return {'success': data['success'] == true, 'error': data['error']};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> adminDeleteTournament(String tournamentId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/tournament/admin/delete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'tournamentId': tournamentId,
        }),
      );

      final data = jsonDecode(response.body);
      return {'success': data['success'] == true, 'error': data['error']};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
