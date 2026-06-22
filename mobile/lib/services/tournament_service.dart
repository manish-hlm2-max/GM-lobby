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
}
