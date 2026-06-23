class MatchModel {
  final String id;
  final String? whitePlayerId;
  final String? blackPlayerId;
  final String? whiteUsername;
  final String? blackUsername;
  final String? whiteTitle;
  final String? blackTitle;
  final int? whiteEloChange;
  final int? blackEloChange;
  final int? whiteElo;
  final int? blackElo;
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
    this.whiteEloChange,
    this.blackEloChange,
    this.whiteElo,
    this.blackElo,
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
      whiteTitle: json['whiteTitle'] != null && json['whiteTitle'].toString().isNotEmpty
          ? json['whiteTitle'].toString()
          : (json['whitePlayerId'] is Map
              ? (json['whitePlayerId']['title'] != null && json['whitePlayerId']['title'].toString().isNotEmpty ? json['whitePlayerId']['title'].toString() : null)
              : null),
      blackTitle: json['blackTitle'] != null && json['blackTitle'].toString().isNotEmpty
          ? json['blackTitle'].toString()
          : (json['blackPlayerId'] is Map
              ? (json['blackPlayerId']['title'] != null && json['blackPlayerId']['title'].toString().isNotEmpty ? json['blackPlayerId']['title'].toString() : null)
              : null),
      whiteEloChange: json['whiteEloChange'] != null ? (json['whiteEloChange'] as num).toInt() : null,
      blackEloChange: json['blackEloChange'] != null ? (json['blackEloChange'] as num).toInt() : null,
      whiteElo: json['whiteElo'] != null
          ? (json['whiteElo'] as num).toInt()
          : (json['whitePlayerId'] is Map && json['whitePlayerId']['elo'] != null
              ? (json['whitePlayerId']['elo'] as num).toInt()
              : null),
      blackElo: json['blackElo'] != null
          ? (json['blackElo'] as num).toInt()
          : (json['blackPlayerId'] is Map && json['blackPlayerId']['elo'] != null
              ? (json['blackPlayerId']['elo'] as num).toInt()
              : null),
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
    int? whiteEloChange,
    int? blackEloChange,
    int? whiteElo,
    int? blackElo,
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
      whiteEloChange: whiteEloChange ?? this.whiteEloChange,
      blackEloChange: blackEloChange ?? this.blackEloChange,
      whiteElo: whiteElo ?? this.whiteElo,
      blackElo: blackElo ?? this.blackElo,
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
