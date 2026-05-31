import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/constants.dart';

/// WebSocket servisi — web frontend useWebSocket hook ile aynı işlev
class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  final dynamic areaId;
  final void Function(Map<String, dynamic>)? onMessage;
  final void Function(bool)? onConnectionChange;

  WebSocketService({this.areaId, this.onMessage, this.onConnectionChange});

  bool get isConnected => _isConnected;

  void connect() {
    if (_channel != null) return;

    try {
      final url = ApiConfig.wsOccupancy(areaId: areaId);
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
          // Auto-reconnect after 3 seconds (same as web frontend)
          _reconnectTimer = Timer(const Duration(seconds: 3), connect);
        },
        onError: (error) {
          _isConnected = false;
          onConnectionChange?.call(false);
          _channel?.sink.close();
          _channel = null;
          _reconnectTimer = Timer(const Duration(seconds: 3), connect);
        },
      );
    } catch (e) {
      _isConnected = false;
      onConnectionChange?.call(false);
      _reconnectTimer = Timer(const Duration(seconds: 3), connect);
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    onConnectionChange?.call(false);
  }
}
