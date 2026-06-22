class TransactionModel {
  final String id;
  final double amount;
  final String type;
  final String status;
  final String description;
  final String? referenceId;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    required this.description,
    this.referenceId,
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
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}
