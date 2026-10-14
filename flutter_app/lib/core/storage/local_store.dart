import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin, test-safe wrapper around [SharedPreferences].
///
/// Two problems motivate this helper:
///  * The preference platform channel never answers in a plain unit-test
///    environment, so a bare `await SharedPreferences.getInstance()` hangs
///    forever. Every access here is bounded by a timeout and a "give up"
///    flag, so a missing store degrades to no-op instead of freezing the UI.
///  * Callers would otherwise re-implement JSON encode/decode and error
///    handling for caching. [readJson]/[writeJson] centralise that.
class LocalStore {
  LocalStore({Future<SharedPreferences> Function()? opener})
      : _opener = opener ?? SharedPreferences.getInstance;

  static final LocalStore instance = LocalStore();

  final Future<SharedPreferences> Function() _opener;
  static const Duration _timeout = Duration(seconds: 3);

  SharedPreferences? _prefs;
  bool _unavailable = false;

  Future<SharedPreferences?> _store() async {
    if (_prefs != null) return _prefs;
    if (_unavailable) return null;
    try {
      _prefs = await _opener().timeout(_timeout);
    } catch (_) {
      _unavailable = true;
    }
    return _prefs;
  }

  Future<String?> readString(String key) async {
    final prefs = await _store();
    if (prefs == null) return null;
    try {
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeString(String key, String value) async {
    final prefs = await _store();
    if (prefs == null) return;
    try {
      await prefs.setString(key, value);
    } catch (_) {
      // Non-fatal: the change still lives in memory for this session.
    }
  }

  Future<void> remove(String key) async {
    final prefs = await _store();
    if (prefs == null) return;
    try {
      await prefs.remove(key);
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<Map<String, dynamic>?> readJson(String key) async {
    final raw = await readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Corrupt cache — treat as absent.
    }
    return null;
  }

  Future<List<dynamic>?> readJsonList(String key) async {
    final raw = await readString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {
      // Corrupt cache — treat as absent.
    }
    return null;
  }

  Future<void> writeJson(String key, Object? value) async {
    try {
      await writeString(key, jsonEncode(value));
    } catch (_) {
      // Non-fatal.
    }
  }
}
