class TournamentModel {
  final String id;
  final String name;
  final double entryFee;
  final double totalPrize;
  final String status;
  final String type;
  final DateTime scheduledStartTime;
  final DateTime? roundStartTime;
  final int roundDurationSeconds;
  final int roundCount;
  final int currentRound;
  final List<dynamic> participants;
  final List<dynamic> brackets;

  TournamentModel({
    required this.id,
    required this.name,
    required this.entryFee,
    required this.totalPrize,
    required this.status,
    required this.type,
    required this.scheduledStartTime,
    this.roundStartTime,
    required this.roundDurationSeconds,
    required this.roundCount,
    required this.currentRound,
    required this.participants,
    required this.brackets,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      entryFee: (json['entryFee'] as num?)?.toDouble() ?? 0.0,
      totalPrize: (json['totalPrize'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'UPCOMING',
      type: json['type'] ?? 'STANDARD',
      scheduledStartTime: json['scheduledStartTime'] != null
          ? DateTime.parse(json['scheduledStartTime'])
          : DateTime.now(),
      roundStartTime: json['roundStartTime'] != null
          ? DateTime.parse(json['roundStartTime'])
          : null,
      roundDurationSeconds: json['roundDurationSeconds'] ?? 43200,
      roundCount: json['roundCount'] ?? 3,
      currentRound: json['currentRound'] ?? 0,
      participants: json['participants'] ?? [],
      brackets: json['brackets'] ?? [],
    );
  }
}
