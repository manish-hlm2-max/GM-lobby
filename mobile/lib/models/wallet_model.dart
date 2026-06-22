class WalletModel {
  final double balance;
  final double lockedBalance;

  WalletModel({
    required this.balance,
    required this.lockedBalance,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      lockedBalance: (json['lockedBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
