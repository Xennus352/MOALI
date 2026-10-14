/// Real-time event subscription for the Flutter app.
///
/// The backend exposes an authenticated WebSocket at ``/api/v1/ws``. The mobile
/// client cannot attach a Cookie header during the handshake, so it passes the
/// HMAC session token as a ``token`` query parameter (the same token stored in
/// the browser cookie on web clients).
///
/// Events are scoped server-side by role AND explicit recipient, so an
/// enumerator only hears about their own submissions plus general admin /
/// reviewer broadcasts when their account has those roles. Every event is
/// forwarded to the [events] broadcast stream for the UI to react to.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/api_client.dart';

enum RealtimeStatus { disconnected, connecting, connected }

class RealTimeService {
  RealTimeService({required this.api});

  final ApiClient api;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final ValueNotifier<RealtimeStatus> _status =
      ValueNotifier(RealtimeStatus.disconnected);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  int _attempt = 0;
  int _connectionGeneration = 0;
  bool _closed = true;

  /// Broadcast of server events (``{type, data, …}``).
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Connection lifecycle, for a badge in the app bar.
  ValueNotifier<RealtimeStatus> get status => _status;

  /// Begin connecting (authenticated by the stored session token).
  void start() {
    if (api.sessionToken == null || !_closed) return;
    _closed = false;
    _attempt = 0;
    _connect();
  }

  /// Tear everything down (on logout or screen disposal).
  void stop() {
    _closed = true;
    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _releaseConnection();
    _status.value = RealtimeStatus.disconnected;
  }

  /// Dispose of the service: close the WebSocket channel, cancel timers,
  /// and clear subscriptions so no callbacks fire after the widget is gone.
  void dispose() {
    stop();
    _status.dispose();
    _events.close();
    // Ensure no lingering subscription reference.
    _sub = null;
  }

  Uri _webSocketUri(String token) {
    final base = Uri.parse(api.baseUrl);
    final scheme = switch (base.scheme) {
      'http' => 'ws',
      'https' => 'wss',
      'ws' || 'wss' => base.scheme,
      _ => throw FormatException('Unsupported WebSocket URL scheme: ${base.scheme}'),
    };
    final basePath = base.path.replaceFirst(RegExp(r'/+$'), '');
    // The stored token format is "moali_session=<jwt>", but the WebSocket
    /// expects only the JWT value as the token query parameter.
    final cleanToken = token.startsWith('moali_session=')
        ? token.substring('moali_session='.length)
        : token;
    // Ensure the token is properly URL-encoded since it contains
    /// session identifiers that may include special characters.
    final encodedToken = Uri.encodeComponent(cleanToken);
    return base.replace(
      scheme: scheme,
      path: '$basePath/api/v1/ws',
      queryParameters: {...base.queryParameters, 'token': encodedToken},
      fragment: null,
    );
  }

  void _releaseConnection() {
    final subscription = _sub;
    _sub = null;
    if (subscription != null) {
      unawaited(subscription.cancel().catchError((Object _) {}));
    }

    final channel = _channel;
    _channel = null;
    if (channel != null) {
      unawaited(channel.sink.close().catchError((Object _) {}));
    }
  }

  void _connect() {
    final token = api.sessionToken;
    if (token == null || _closed) return;
    _reconnectTimer = null;
    final generation = ++_connectionGeneration;
    _status.value = RealtimeStatus.connecting;
    try {
      final uri = _webSocketUri(token);
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (message) {
          if (_closed || generation != _connectionGeneration) return;
          _attempt = 0;
          _status.value = RealtimeStatus.connected;
          try {
            final decoded = jsonDecode(message as String);
            if (decoded is Map<String, dynamic>) {
              _events.add(decoded);
            }
          } catch (_) {
            // Non-JSON keepalive or malformed frame — ignore.
          }
        },
        onDone: () {
          if (generation == _connectionGeneration) _scheduleReconnect();
        },
        onError: (_) {
          if (generation == _connectionGeneration) _scheduleReconnect();
        },
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_closed || (_reconnectTimer?.isActive ?? false)) return;
    _connectionGeneration++;
    _releaseConnection();
    _status.value = RealtimeStatus.disconnected;
    final backoff = 1 << _attempt.clamp(0, 5).toInt();
    _attempt += 1;
    _reconnectTimer = Timer(Duration(seconds: backoff), () {
      _reconnectTimer = null;
      _connect();
    });
  }
}
