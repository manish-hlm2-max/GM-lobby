import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';
import '../services/auth_service.dart';

class AuthState {
  final UserModel? user;
  final WalletModel? wallet;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.wallet,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    WalletModel? wallet,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      wallet: wallet ?? this.wallet,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();

  AuthNotifier() : super(AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);
    final data = await _authService.getMe();
    if (data != null) {
      state = AuthState(user: data['user'], wallet: data['wallet']);
    } else {
      state = AuthState();
    }
  }

  Future<bool> login(String emailOrUsername, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    final res = await _authService.login(emailOrUsername, password);
    if (res['success'] == true) {
      // Reload profile
      await checkAuth();
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: res['error']);
      return false;
    }
  }

  Future<bool> loginWithGoogle(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    final res = await _authService.loginWithGoogle(email);
    if (res['success'] == true) {
      await checkAuth();
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: res['error']);
      return false;
    }
  }

  Future<bool> register(String email, String username, String password, String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);
    final res = await _authService.register(email, username, password, phoneNumber);
    if (res['success'] == true) {
      await checkAuth();
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: res['error']);
      return false;
    }
  }

  Future<Map<String, dynamic>> checkUsernameAvailability(String username) async {
    return await _authService.checkUsername(username);
  }

  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword, String confirmNewPassword) async {
    return await _authService.changePassword(oldPassword, newPassword, confirmNewPassword);
  }

  Future<void> logout() async {
    await _authService.clearToken();
    state = AuthState();
  }

  // Update local wallet balance manually (e.g. after deposit/withdraw/win)
  void updateWallet(WalletModel wallet) {
    state = state.copyWith(wallet: wallet);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
