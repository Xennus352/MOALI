// HTTP client for the MOALI FastAPI backend (../server).
//
// The backend authenticates with a signed, httpOnly session cookie
// (`moali_session`) rather than a bearer token. The `package:http` client does
// not manage cookies for us, so this class captures the `Set-Cookie` header on
// login and replays it as a `Cookie` header on every subsequent request.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/storage/local_store.dart';

/// Any non-2xx response, or a transport failure (when [statusCode] is 0).
class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.field});

  final int statusCode;
  final String message;

  /// The offending field for 422 validation errors, when the server sends one.
  final String? field;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// The authenticated session user returned by `/auth/login` and `/auth/me`.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.isSuperuser = false,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final bool isSuperuser;

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: '${json['id'] ?? ''}',
        name: (json['name'] as String?)?.trim().isNotEmpty == true
            ? json['name'] as String
            : '${json['email'] ?? ''}'.split('@').first,
        email: (json['email'] as String?) ?? '',
        role: (json['role'] as String?) ?? 'user',
        isSuperuser: json['is_superuser'] == true,
      );
}

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  /// Override at build/run time with:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
  final String baseUrl;

  final http.Client _client = http.Client();
  String? _sessionCookie;

  static const String sessionCookieName = 'moali_session';

  /// Durable-storage key for the mobile session token (see [restoreSession]).
  static const String _tokenStorageKey = 'moali_session_token_v1';

  /// Sensible per-platform default. The Android emulator reaches the host
  /// machine through 10.0.2.2, everything else can use loopback directly.
  static String get defaultBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  bool get hasSession => _sessionCookie != null;

  /// Raw session token (``name=value`` pair) for the WebSocket handshake,
  /// which cannot attach a Cookie header on Android.
  String? get sessionToken => _sessionCookie;

  /// Install a bare session token (as returned by the native Google OAuth
  /// handoff exchange) as the cookie replayed on every request.
  void setSessionToken(String? token) {
    _sessionCookie =
        (token == null || token.isEmpty) ? null : '$sessionCookieName=$token';
    _persistSession();
  }

  /// Restore a previously saved session so the user stays signed in across
  /// restarts. Safe to call once, early in startup; it is a no-op when a
  /// session is already held.
  Future<void> restoreSession() async {
    if (_sessionCookie != null) return;
    final raw = await LocalStore.instance.readString(_tokenStorageKey);
    if (raw != null && raw.isNotEmpty) _sessionCookie = raw;
  }

  /// Mirror the in-memory cookie to durable storage (or clear it).
  void _persistSession() {
    final cookie = _sessionCookie;
    if (cookie == null || cookie.isEmpty) {
      LocalStore.instance.remove(_tokenStorageKey);
    } else {
      LocalStore.instance.writeString(_tokenStorageKey, cookie);
    }
  }

  // ------------------------------------------------------------------
  // plumbing
  // ------------------------------------------------------------------
  Map<String, String> _headers({bool withBody = false}) => {
        'Accept': 'application/json',
        if (withBody) 'Content-Type': 'application/json',
        'Cookie': ?_sessionCookie,
      };

  void _captureCookie(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    final pair = raw.split(';').first.trim();
    if (pair.startsWith('$sessionCookieName=')) {
      _sessionCookie = pair;
      _persistSession();
    }
  }

  /// Decode a UTF-8 JSON body (using [http.Response.bodyBytes] so Burmese text
  /// survives even when the server omits a charset).
  Map<String, dynamic> _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return const {};
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = 'Request failed (${response.statusCode})';
    String? field;
    try {
      final body = _decode(response);
      if (body['detail'] is String) message = body['detail'] as String;
      if (body['field'] is String) field = body['field'] as String;
    } catch (_) {
      // Non-JSON error body; keep the generic message.
    }
    throw ApiException(response.statusCode, message, field: field);
  }

  /// Run a request, converting transport errors into a friendly [ApiException].
  Future<http.Response> _send(Future<http.Response> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw ApiException(
        0,
        'Cannot reach the server at $baseUrl. Is the backend running?',
      );
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  // ------------------------------------------------------------------
  // auth
  // ------------------------------------------------------------------
  Future<SessionUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _send(() => _client.post(
          _uri('/api/v1/auth/login'),
          headers: _headers(withBody: true),
          body: jsonEncode({'email': email, 'password': password}),
        ));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _captureCookie(response);
    }
    _ensureOk(response);
    final body = _decode(response);
    final user = body['user'];
    if (user is! Map) {
      throw ApiException(response.statusCode, 'Malformed login response');
    }
    return SessionUser.fromJson(Map<String, dynamic>.from(user));
  }

  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await _send(() => _client.post(
          _uri('/api/v1/auth/register'),
          headers: _headers(withBody: true),
          body: jsonEncode({
            'email': email,
            'password': password,
            if (name != null && name.isNotEmpty) 'name': name,
          }),
        ));
    _ensureOk(response);
  }

  /// Returns the current user, or `null` when there is no valid session.
  Future<SessionUser?> me() async {
    if (_sessionCookie == null) return null;
    final response = await _send(
      () => _client.get(_uri('/api/v1/auth/me'), headers: _headers()),
    );
    if (response.statusCode == 401) {
      _sessionCookie = null;
      _persistSession();
      return null;
    }
    _ensureOk(response);
    return SessionUser.fromJson(_decode(response));
  }

  Future<void> logout() async {
    try {
      await _send(() => _client.post(
            _uri('/api/v1/auth/logout'),
            headers: _headers(),
          ));
    } finally {
      _sessionCookie = null;
      _persistSession();
    }
  }

  /// Absolute URL that starts the browser Google OAuth flow.
  ///
  /// [redirectUri] is the app's custom-scheme deep link (``moali://auth``); the
  /// backend validates it and, after sign-in, redirects the device back to it
  /// with a short-lived handoff token.
  String googleAuthUrl({String redirectUri = 'moali://auth'}) {
    final uri = Uri.parse('$baseUrl/api/v1/auth/google')
        .replace(queryParameters: {'redirect_uri': redirectUri});
    return uri.toString();
  }

  /// Whether the server has Google sign-in configured.
  ///
  /// The ``/auth/google`` endpoint returns 501 when the server has no Google
  /// client credentials. We probe it *without* following the redirect so the app
  /// can show a clear message instead of opening a browser page that errors.
  Future<bool> googleAuthConfigured() async {
    try {
      final request = http.Request('GET', Uri.parse(googleAuthUrl()))
        ..followRedirects = false;
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 8));
      // Drain the body so the connection can be reused.
      await streamed.stream.drain<void>();
      return streamed.statusCode != 501 && streamed.statusCode != 404;
    } catch (_) {
      // Unknown (e.g. offline): let the browser attempt the flow rather than
      // blocking a possibly-working sign-in.
      return true;
    }
  }

  /// Exchange a native OAuth handoff token for a real session and return the
  /// signed-in user. The session is installed on success.
  Future<SessionUser> exchangeHandoffToken(String handoffToken) async {
    final response = await _send(() => _client.post(
          _uri('/api/v1/auth/session/exchange'),
          headers: _headers(withBody: true),
          body: jsonEncode({'token': handoffToken}),
        ));
    _ensureOk(response);
    final body = _decode(response);
    final token = body['token'];
    if (token is! String || token.isEmpty) {
      throw ApiException(response.statusCode, 'Malformed exchange response');
    }
    setSessionToken(token);
    final user = body['user'];
    if (user is! Map) {
      throw ApiException(response.statusCode, 'Malformed exchange response');
    }
    return SessionUser.fromJson(Map<String, dynamic>.from(user));
  }

  // ------------------------------------------------------------------
  // dashboard
  // ------------------------------------------------------------------
  Future<Map<String, dynamic>> dashboardKpi() async {
    final response = await _send(
      () => _client.get(_uri('/api/v1/dashboard/kpi'), headers: _headers()),
    );
    _ensureOk(response);
    return _decode(response);
  }

  Future<Map<String, dynamic>> dashboardRecent({int limit = 8}) async {
    final response = await _send(() => _client.get(
          _uri('/api/v1/dashboard/recent', {'limit': '$limit'}),
          headers: _headers(),
        ));
    _ensureOk(response);
    return _decode(response);
  }

  // ------------------------------------------------------------------
  // reference data (census survey masters)
  // ------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final response =
        await _send(() => _client.get(_uri(path), headers: _headers()));
    _ensureOk(response);
    final body = _decode(response);
    if (body['data'] is List) return List<Map<String, dynamic>>.from(body['data']);
    final items = body['items'];
    if (items is List) return List<Map<String, dynamic>>.from(items);
    throw ApiException(response.statusCode, 'Malformed list response: $path');
  }

  Future<List<Map<String, dynamic>>> genders() =>
      _getList('/api/v1/master/genders');

  Future<List<Map<String, dynamic>>> animalTypes() =>
      _getList('/api/v1/master/animal-types');

  Future<List<Map<String, dynamic>>> animalCategories() =>
      _getList('/api/v1/master/animal-categories');

  Future<List<Map<String, dynamic>>> species() =>
      _getList('/api/v1/master/species');

  Future<List<Map<String, dynamic>>> ageGroups() =>
      _getList('/api/v1/master/age-groups');

  Future<List<Map<String, dynamic>>> breedingCategories() =>
      _getList('/api/v1/master/breeding-categories');

  /// Current published census form (id + version).
  Future<Map<String, dynamic>> currentForm() async {
    final response = await _send(
        () => _client.get(_uri('/api/v1/meta/form/current'), headers: _headers()));
    _ensureOk(response);
    return _decode(response);
  }

  /// Region → district → township → tract → ward tree.
  Future<List<Map<String, dynamic>>> geography() async {
    final response = await _send(
        () => _client.get(_uri('/api/v1/meta/geography'), headers: _headers()));
    _ensureOk(response);
    final body = _decode(response);
    if (body['data'] is List) {
      return List<Map<String, dynamic>>.from(body['data'] as List);
    }
    return List<Map<String, dynamic>>.from(body['geography'] as List? ??
        (body['regions'] as List? ?? const []));
  }

  /// Paged submission history for the mobile "history" screen.
  Future<Map<String, dynamic>> listSubmissions({
    int page = 1,
    int pageSize = 25,
    String? search,
    int? stateRegionId,
    bool mine = false,
  }) async {
    final response = await _send(() => _client.get(
          _uri('/api/v1/submissions', {
            'page': '$page',
            'page_size': '$pageSize',
            if (search != null && search.isNotEmpty) 'q': search,
            if (stateRegionId != null) 'state_region_id': '$stateRegionId',
            if (mine) 'mine': 'true',
          }),
          headers: _headers(),
        ));
    _ensureOk(response);
    return _decode(response);
  }

  /// Submit a completed census survey and return the created record.
  ///
  /// [allowDuplicate] bypasses the household+township+date duplicate guard for
  /// an intentional re-survey after a rejection.
  Future<Map<String, dynamic>> submitSurvey(
    Map<String, dynamic> payload, {
    bool allowDuplicate = false,
  }) async {
    if (allowDuplicate) payload['allow_duplicate'] = true;
    final response = await _send(() => _client.post(
          _uri('/api/v1/submissions'),
          headers: _headers(withBody: true),
          body: jsonEncode(payload),
        ));
    _ensureOk(response);
    return _decode(response);
  }
}

/// Shared client instance for the whole app.
final ApiClient api = ApiClient();
