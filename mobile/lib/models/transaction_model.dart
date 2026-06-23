class TransactionModel {
  final String id;
  final double amount;
  final String type;
  final String status;
  final String description;
  final String? referenceId;
  final String? bankName;
  final String? ifscCode;
  final String? accountHolderName;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
    this.referenceId,
    this.bankName,
    this.ifscCode,
    this.accountHolderName,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? json['_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] ?? '',
      status: json['status'] ?? 'PENDING',
      description: json['description'] ?? '',
      referenceId: json['referenceId'],
      bankName: json['bankName'],
      ifscCode: json['ifscCode'],
      accountHolderName: json['accountHolderName'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
