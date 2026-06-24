import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';
import '../models/announcement_model.dart';

class AnnouncementService {
  final AuthService _authService = AuthService();

  Future<List<AnnouncementModel>> getAnnouncements() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.announcements),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['announcements'] != null) {
          final List list = data['announcements'];
          return list.map((item) => AnnouncementModel.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Fetch announcements error: $e');
      return [];
    }
  }
}
