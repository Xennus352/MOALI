import 'dart:async';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';

/// Reason a Google sign-in attempt could not complete. The message is a short
/// machine token the UI maps to a localized, human sentence.
class GoogleSignInError implements Exception {
  GoogleSignInError(this.code);

  /// One of: `not_configured`, `launch_failed`, `timeout`, `cancelled`.
  final String code;

  @override
  String toString() => 'GoogleSignInError($code)';
}

/// Completes the browser-based Google OAuth flow on a native device.
///
/// The flow (matching the backend in `../server`):
///  1. open the system browser at `/api/v1/auth/google?redirect_uri=moali://auth`;
///  2. the user signs in with Google and the backend callback redirects to the
///     custom scheme `moali://auth?token=<handoff>`;
///  3. the host platform delivers that URL through the `moali/auth` method
///     channel (see `MainActivity.kt` / `SceneDelegate.swift`);
///  4. we exchange the short-lived handoff token for a real session token.
///
/// No token is ever read from a URL the app did not initiate, and the handoff
/// token is single-purpose and expires in two minutes.
class GoogleSignIn {
  GoogleSignIn({
    ApiClient? client,
    MethodChannel? channel,
    Future<bool> Function(Uri)? launcher,
  })  : _api = client ?? api,
        _channel = channel ?? const MethodChannel(channelName),
        _launch = launcher ?? _defaultLaunch;

  static const String channelName = 'moali/auth';

  final ApiClient _api;
  final MethodChannel _channel;
  final Future<bool> Function(Uri) _launch;

  Completer<String>? _pending;
  bool _listening = false;

  static Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  /// Register the channel handler once and pick up any cold-start deep link.
  Future<void> _ensureListening() async {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'deepLink' && call.arguments is String) {
        _deliver(call.arguments as String);
      }
      return null;
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      if (initial != null) _deliver(initial);
    } catch (_) {
      // No host implementation (e.g. unit tests) — the button still fails
      // softly rather than crashing.
    }
  }

  void _deliver(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.scheme != 'moali' || uri.host != 'auth') return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    final completer = _pending;
    if (completer != null && !completer.isCompleted) completer.complete(token);
  }

  /// Run the full flow and return the signed-in user, or throw
  /// [GoogleSignInError].
  Future<SessionUser> signIn({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    await _ensureListening();

    if (!await _api.googleAuthConfigured()) {
      throw GoogleSignInError('not_configured');
    }

    final completer = Completer<String>();
    _pending = completer;

    final launched = await _launch(Uri.parse(_api.googleAuthUrl()));
    if (!launched) {
      _pending = null;
      throw GoogleSignInError('launch_failed');
    }

    final String token;
    try {
      token = await completer.future.timeout(timeout);
    } on TimeoutException {
      throw GoogleSignInError('timeout');
    } finally {
      if (identical(_pending, completer)) _pending = null;
    }

    return _api.exchangeHandoffToken(token);
  }
}
