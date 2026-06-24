import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

class SocketService {
  IO.Socket? _socket;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String userId, {Function? onConnect, Function? onDisconnect}) {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      ApiConfig.wsUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'userId': userId})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      print('Socket connected successfully');
      if (onConnect != null) onConnect();
    });

    _socket!.onDisconnect((_) {
      print('Socket disconnected');
      if (onDisconnect != null) onDisconnect();
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void joinMatch(String matchId) {
    _socket?.emit('join_match', {'matchId': matchId});
  }

  void makeMove(String matchId, String from, String to, {String? promotion}) {
    _socket?.emit('make_move', {
      'matchId': matchId,
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });
  }

  void resign(String matchId) {
    _socket?.emit('resign', {'matchId': matchId});
  }

  void sendMessage(String matchId, String sender, String text) {
    _socket?.emit('send_message', {
      'matchId': matchId,
      'sender': sender,
      'text': text,
    });
  }

  void onMatchState(Function(Map<String, dynamic>) callback) {
    _socket?.on('match_state', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onGameEnded(Function(Map<String, dynamic>) callback) {
    _socket?.on('game_ended', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onNewMessage(Function(Map<String, dynamic>) callback) {
    _socket?.on('new_message', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onMoveError(Function(Map<String, dynamic>) callback) {
    _socket?.on('move_error', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void onWalletUpdated(Function(Map<String, dynamic>) callback) {
    _socket?.on('wallet_updated', (data) {
      callback(Map<String, dynamic>.from(data));
    });
  }

  void off(String event) {
    _socket?.off(event);
  }
}
