import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/wallet_service.dart';
import 'auth_provider.dart';

class WalletState {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? error;

  WalletState({
    required this.transactions,
    this.isLoading = false,
    this.error,
  });

  WalletState copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? error,
  }) {
    return WalletState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletService _walletService = WalletService();
  final Ref ref;

  WalletNotifier(this.ref) : super(WalletState(transactions: []));

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);
    final history = await _walletService.getHistory();
    state = WalletState(transactions: history, isLoading: false);
  }

  Future<bool> deposit(double amount, {String? referenceId}) async {
    state = state.copyWith(isLoading: true, error: null);
    final res = await _walletService.deposit(amount, referenceId: referenceId);
    if (res['success'] == true) {
      // Update balance in AuthProvider only if credited successfully (not PENDING verification)
      if (res['status'] != 'PENDING') {
        final currentLocked = ref.read(authProvider).wallet?.lockedBalance ?? 0.0;
        ref.read(authProvider.notifier).updateWallet(
          WalletModel(balance: res['balance'], lockedBalance: currentLocked),
        );
      }
      await loadHistory();
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: res['error']);
      return false;
    }
  }

  Future<bool> withdraw({
    required double amount,
    required String bankName,
    required String ifscCode,
    required String accountHolderName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final res = await _walletService.withdraw(
      amount: amount,
      bankName: bankName,
      ifscCode: ifscCode,
      accountHolderName: accountHolderName,
    );
    if (res['success'] == true) {
      ref.read(authProvider.notifier).updateWallet(
        WalletModel(balance: res['balance'], lockedBalance: res['lockedBalance']),
      );
      await loadHistory();
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: res['error']);
      return false;
    }
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref);
});
