import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> login(String emailOrUsername, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'emailOrUsername': emailOrUsername,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final token = data['token'];
        await saveToken(token);
        return {
          'success': true,
          'user': UserModel.fromJson(data['user']),
          'token': token,
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Login failed.',
      };
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('TimeoutException')) {
        errMsg = 'Connection timed out. The server is not responding.';
      } else if (errMsg.contains('SocketException') || errMsg.contains('HandshakeException')) {
        errMsg = 'Cannot reach server. Please check your internet connection.';
      }
      return {
        'success': false,
        'error': errMsg,
      };
    }
  }

  Future<Map<String, dynamic>> register(String email, String username, String password, String phoneNumber) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
          'phoneNumber': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        final token = data['token'];
        await saveToken(token);
        return {
          'success': true,
          'user': UserModel.fromJson(data['user']),
          'token': token,
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Registration failed.',
      };
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('TimeoutException')) {
        errMsg = 'Connection timed out. The server is not responding.';
      } else if (errMsg.contains('SocketException') || errMsg.contains('HandshakeException')) {
        errMsg = 'Cannot reach server. Please check your internet connection.';
      }
      return {
        'success': false,
        'error': errMsg,
      };
    }
  }

  Future<Map<String, dynamic>> checkUsername(String username) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.checkUsername(username)),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'available': data['available'] ?? false,
          'message': data['message'] ?? '',
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to check username.',
      };
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('TimeoutException')) {
        errMsg = 'Connection timed out. The server is not responding.';
      } else if (errMsg.contains('SocketException') || errMsg.contains('HandshakeException')) {
        errMsg = 'Cannot reach server. Please check your internet connection.';
      }
      return {
        'success': false,
        'error': errMsg,
      };
    }
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse(ApiConfig.me),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'user': UserModel.fromJson(data['user']),
          'wallet': WalletModel.fromJson(data['wallet']),
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword, String confirmNewPassword) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'error': 'Authentication required. Log in again.'};
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'oldPassword': oldPassword,
          'newPassword': newPassword,
          'confirmNewPassword': confirmNewPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password updated successfully.',
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Password update failed.',
      };
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('TimeoutException')) {
        errMsg = 'Connection timed out. The server is not responding.';
      } else if (errMsg.contains('SocketException') || errMsg.contains('HandshakeException')) {
        errMsg = 'Cannot reach server. Please check your internet connection.';
      }
      return {
        'success': false,
        'error': errMsg,
      };
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.searchUsers(query)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['users'] as List;
        return list.map((item) => UserModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addFriend(String friendId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.addFriend),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'friendId': friendId}),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Friend added.',
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to add friend.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<UserModel>> getFriends() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.getFriends),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['friends'] as List;
        return list.map((item) => UserModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting friends: $e');
      return [];
    }
  }
}
