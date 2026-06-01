import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/api_config.dart';
import '../core/constants.dart';

/// Live occupancy WebSocket — same lifecycle and reconnect cadence as the
/// web frontend's `useWebSocket` hook.
class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _stopped = false;
  final ApiConfig _config;
  final int? areaId;
  final void Function(Map<String, dynamic>)? onMessage;
  final void Function(bool)? onConnectionChange;

  WebSocketService({
    required ApiConfig config,
    this.areaId,
    this.onMessage,
    this.onConnectionChange,
  }) : _config = config;

  bool get isConnected => _isConnected;

  void connect() {
    if (_channel != null || _stopped) return;

    try {
      final url = '${_config.wsBaseUrl}${ApiPaths.wsOccupancy(areaId: areaId)}';
      _channel = WebSocketChannel.connect(Uri.parse(url));

      _isConnected = true;
      onConnectionChange?.call(true);

      _channel!.stream.listen(
        (data) {
          try {
            final parsed = jsonDecode(data as String) as Map<String, dynamic>;
            onMessage?.call(parsed);
          } catch (_) {
            // Ignore non-JSON frames
          }
        },
        onDone: () {
          _isConnected = false;
          onConnectionChange?.call(false);
          _channel = null;
          if (!_stopped) {
            _reconnectTimer = Timer(const Duration(seconds: 3), connect);
          }
        },
        onError: (error) {
          _isConnected = false;
          onConnectionChange?.call(false);
          _channel?.sink.close();
          _channel = null;
          if (!_stopped) {
            _reconnectTimer = Timer(const Duration(seconds: 3), connect);
          }
        },
      );
    } catch (e) {
      _isConnected = false;
      onConnectionChange?.call(false);
      if (!_stopped) {
        _reconnectTimer = Timer(const Duration(seconds: 3), connect);
      }
    }
  }

  void disconnect() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    onConnectionChange?.call(false);
  }
}
