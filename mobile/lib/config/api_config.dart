class ApiConfig {
  static const String host = '10.0.2.2:3000'; // Target local server from Android emulator
  static const String baseUrl = 'http://$host';
  static const String wsUrl = 'ws://$host';

  // Auth endpoints
  static const String register = '$baseUrl/api/auth/register';
  static const String login = '$baseUrl/api/auth/login';
  static const String me = '$baseUrl/api/auth/me';

  // Wallet endpoints
  static const String deposit = '$baseUrl/api/wallet/deposit';
  static const String withdraw = '$baseUrl/api/wallet/withdraw';
  static const String transactions = '$baseUrl/api/wallet/history';

  // Match endpoints
  static const String openMatches = '$baseUrl/api/match/open';
  static const String createMatch = '$baseUrl/api/match/create';
  static const String joinMatch = '$baseUrl/api/match/join';
  static String matchDetails(String id) => '$baseUrl/api/match/$id';

  // Tournament endpoints
  static const String tournamentsList = '$baseUrl/api/tournament';
  static const String registerTournament = '$baseUrl/api/tournament/register';
}
