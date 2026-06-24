class ApiConfig {
  static const String host = 'chess-betting-backend.onrender.com'; // Target live Render server
  static const String baseUrl = 'https://$host';
  static const String wsUrl = 'wss://$host';

  // Auth endpoints
  static const String register = '$baseUrl/api/auth/register';
  static const String login = '$baseUrl/api/auth/login';
  static const String googleLogin = '$baseUrl/api/auth/google';
  static const String me = '$baseUrl/api/auth/me';
  static const String appVersion = '$baseUrl/api/app-version';
  static String checkUsername(String username) => '$baseUrl/api/auth/check-username?username=${Uri.encodeComponent(username)}';

  // Wallet endpoints
  static const String deposit = '$baseUrl/api/wallet/deposit';
  static const String withdraw = '$baseUrl/api/wallet/withdraw';
  static const String transactions = '$baseUrl/api/wallet/history';
  static const String depositSettings = '$baseUrl/api/wallet/deposit-settings';

  // Match endpoints
  static const String openMatches = '$baseUrl/api/match/open';
  static const String createMatch = '$baseUrl/api/match/create';
  static const String joinMatch = '$baseUrl/api/match/join';
  static const String myActiveMatches = '$baseUrl/api/match/my-active';
  static const String matchHistory = '$baseUrl/api/match/history';
  static String matchDetails(String id) => '$baseUrl/api/match/$id';

  // Tournament endpoints
  static const String tournamentsList = '$baseUrl/api/tournament';
  static const String registerTournament = '$baseUrl/api/tournament/register';

  // Announcement endpoints
  static const String announcements = '$baseUrl/api/announcement';

  // News endpoints
  static const String news = '$baseUrl/api/news';

  // Friends endpoints
  static String searchUsers(String query) => '$baseUrl/api/auth/users/search?username=${Uri.encodeComponent(query)}';
  static const String addFriend = '$baseUrl/api/auth/friends/add';
  static const String getFriends = '$baseUrl/api/auth/friends';
}
