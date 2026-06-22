class UserModel {
  final String id;
  final String email;
  final String username;
  final int elo;
  final int wins;
  final int losses;
  final int draws;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.elo,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      elo: json['elo'] ?? 1200,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      draws: json['draws'] ?? 0,
      role: json['role'] ?? 'USER',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'elo': elo,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'role': role,
    };
  }
}
