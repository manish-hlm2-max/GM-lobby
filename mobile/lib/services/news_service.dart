import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';
import '../models/news_model.dart';

class NewsService {
  final AuthService _authService = AuthService();

  Future<List<NewsModel>> getNews() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.news),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['news'] != null) {
          final List list = data['news'];
          return list.map((item) => NewsModel.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('Fetch news error: $e');
      return [];
    }
  }
}
