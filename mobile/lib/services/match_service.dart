import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';
import '../models/match_model.dart';

class MatchService {
  final AuthService _authService = AuthService();

  Future<List<MatchModel>> getOpenMatches() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.openMatches),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['matches'] as List;
        return list.map((item) => MatchModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching open matches: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createMatch({
    required double entryFee,
    required int timeControl,
    required String preferredColor,
  }) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.createMatch),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'entryFee': entryFee,
          'timeControl': timeControl,
          'preferredColor': preferredColor,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'match': MatchModel.fromJson(data['match']),
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Create match failed.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> joinMatch(String matchId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.joinMatch),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'matchId': matchId}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'match': MatchModel.fromJson(data['match']),
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Join match failed.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<MatchModel?> getMatchDetails(String matchId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.matchDetails(matchId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return MatchModel.fromJson(data['match']);
      }
      return null;
    } catch (e) {
      print('Error fetching match details: $e');
      return null;
    }
  }

  Future<List<MatchModel>> getMyActiveMatches() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.myActiveMatches),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['matches'] as List;
        return list.map((item) => MatchModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching my active matches: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> matchmake({
    required double entryFee,
    required int timeControl,
  }) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/match/matchmake'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'entryFee': entryFee,
          'timeControl': timeControl,
        }),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {
          'success': true,
          'match': MatchModel.fromJson(data['match']),
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

  Future<Map<String, dynamic>> forceBotJoin(String matchId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/match/force-bot-join'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'matchId': matchId}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {
          'success': true,
          'match': MatchModel.fromJson(data['match']),
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Force bot join failed.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> cancelMatchmake(String matchId) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/match/cancel-matchmake'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'matchId': matchId}),
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return {
          'success': true,
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Cancellation failed.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
