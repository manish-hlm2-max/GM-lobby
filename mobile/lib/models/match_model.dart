class MatchModel {
  final String id;
  final String? whitePlayerId;
  final String? blackPlayerId;
  final String? whiteUsername;
  final String? blackUsername;
  final double entryFee;
  final double prizePool;
  final int timeControl;
  final String status;
  final String boardFen;
  final List<dynamic> moveHistory;
  final String? result;
  final String? winnerId;
  final String? createdAt;

  MatchModel({
    required this.id,
    this.whitePlayerId,
    this.blackPlayerId,
    this.whiteUsername,
    this.blackUsername,
    required this.entryFee,
    required this.prizePool,
    required this.timeControl,
    required this.status,
    required this.boardFen,
    required this.moveHistory,
    this.result,
    this.winnerId,
    this.createdAt,
  });

  factory MatchModel.fromJson(Map<String, dynamic> json) {
    return MatchModel(
      id: json['id'] ?? json['_id'] ?? '',
      whitePlayerId: json['whitePlayerId'] is Map
          ? json['whitePlayerId']['_id'] ?? json['whitePlayerId']['id']
          : json['whitePlayerId'],
      blackPlayerId: json['blackPlayerId'] is Map
          ? json['blackPlayerId']['_id'] ?? json['blackPlayerId']['id']
          : json['blackPlayerId'],
      whiteUsername: json['whitePlayerId'] is Map
          ? json['whitePlayerId']['username'] ?? json['whiteUsername']
          : json['whiteUsername'],
      blackUsername: json['blackPlayerId'] is Map
          ? json['blackPlayerId']['username'] ?? json['blackUsername']
          : json['blackUsername'],
      entryFee: (json['entryFee'] as num?)?.toDouble() ?? 0.0,
      prizePool: (json['prizePool'] as num?)?.toDouble() ?? 0.0,
      timeControl: json['timeControl'] ?? 600,
      status: json['status'] ?? 'WAITING',
      boardFen: json['boardFen'] ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moveHistory: json['moveHistory'] ?? [],
      result: json['result'],
      winnerId: json['winnerId'],
      createdAt: json['createdAt']?.toString(),
    );
  }
}
