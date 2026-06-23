class MatchModel {
  final String id;
  final String? whitePlayerId;
  final String? blackPlayerId;
  final String? whiteUsername;
  final String? blackUsername;
  final String? whiteTitle;
  final String? blackTitle;
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
    this.whiteTitle,
    this.blackTitle,
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
      whiteTitle: json['whitePlayerId'] is Map
          ? (json['whitePlayerId']['title'] != null && json['whitePlayerId']['title'].toString().isNotEmpty ? json['whitePlayerId']['title'].toString() : null)
          : null,
      blackTitle: json['blackPlayerId'] is Map
          ? (json['blackPlayerId']['title'] != null && json['blackPlayerId']['title'].toString().isNotEmpty ? json['blackPlayerId']['title'].toString() : null)
          : null,
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

  MatchModel copyWith({
    String? id,
    String? whitePlayerId,
    String? blackPlayerId,
    String? whiteUsername,
    String? blackUsername,
    String? whiteTitle,
    String? blackTitle,
    double? entryFee,
    double? prizePool,
    int? timeControl,
    String? status,
    String? boardFen,
    List<dynamic>? moveHistory,
    String? result,
    String? winnerId,
    String? createdAt,
  }) {
    return MatchModel(
      id: id ?? this.id,
      whitePlayerId: whitePlayerId ?? this.whitePlayerId,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      whiteUsername: whiteUsername ?? this.whiteUsername,
      blackUsername: blackUsername ?? this.blackUsername,
      whiteTitle: whiteTitle ?? this.whiteTitle,
      blackTitle: blackTitle ?? this.blackTitle,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      timeControl: timeControl ?? this.timeControl,
      status: status ?? this.status,
      boardFen: boardFen ?? this.boardFen,
      moveHistory: moveHistory ?? this.moveHistory,
      result: result ?? this.result,
      winnerId: winnerId ?? this.winnerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
