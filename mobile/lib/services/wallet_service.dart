import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../config/api_config.dart';
import '../models/transaction_model.dart';

class WalletService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> deposit(double amount, {String? referenceId}) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.deposit),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          if (referenceId != null) 'referenceId': referenceId,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'balance': (data['balance'] as num).toDouble(),
          'status': data['transaction'] != null ? data['transaction']['status'] : 'SUCCESS',
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Deposit failed.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> withdraw({
    required double amount,
    required String bankName,
    required String ifscCode,
    required String accountHolderName,
  }) async {
    try {
      final token = await _authService.getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.withdraw),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'bankName': bankName,
          'ifscCode': ifscCode,
          'accountHolderName': accountHolderName,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'balance': (data['balance'] as num).toDouble(),
          'lockedBalance': (data['lockedBalance'] as num).toDouble(),
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Withdrawal failed.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<TransactionModel>> getHistory() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.transactions),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        final list = data['transactions'] as List;
        return list.map((item) => TransactionModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading transaction history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getDepositSettings() async {
    try {
      final token = await _authService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.depositSettings),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'upiId': data['upiId'],
          'qrCodeUrl': data['qrCodeUrl'],
        };
      }
      return null;
    } catch (e) {
      print('Error loading deposit settings: $e');
      return null;
    }
  }
}
