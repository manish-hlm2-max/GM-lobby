class UserModel {
  final String id;
  final String email;
  final String username;
  final String phoneNumber;
  final int elo;
  final int wins;
  final int losses;
  final int draws;
  final String role;
  final String? title;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.phoneNumber,
    required this.elo,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.role,
    this.title,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['_id'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      elo: json['elo'] ?? 1200,
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      draws: json['draws'] ?? 0,
      role: json['role'] ?? 'USER',
      title: json['title'] != null && json['title'].toString().isNotEmpty
          ? json['title'].toString()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'phoneNumber': phoneNumber,
      'elo': elo,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'role': role,
      'title': title,
    };
  }
}
