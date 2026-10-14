import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../api/api_client.dart';
import '../../core/storage/local_store.dart';

/// A submission that could not be uploaded yet because the network was down.
///
/// It is stored locally (so it survives a restart) and shown at the top of the
/// history as *Pending* until [SubmissionRepository.flushPending] succeeds.
class PendingSubmission {
  PendingSubmission({
    required this.localId,
    required this.payload,
    required this.householdNo,
    required this.createdAt,
    required this.allowDuplicate,
  });

  final String localId;
  final Map<String, dynamic> payload;
  final String householdNo;
  final DateTime createdAt;
  final bool allowDuplicate;

  Map<String, dynamic> toJson() => {
        'local_id': localId,
        'payload': payload,
        'household_no': householdNo,
        'created_at': createdAt.toIso8601String(),
        'allow_duplicate': allowDuplicate,
      };

  factory PendingSubmission.fromJson(Map<String, dynamic> json) {
    return PendingSubmission(
      localId: '${json['local_id'] ?? ''}',
      payload: Map<String, dynamic>.from(
          (json['payload'] as Map?) ?? const <String, dynamic>{}),
      householdNo: '${json['household_no'] ?? '—'}',
      createdAt:
          DateTime.tryParse('${json['created_at']}') ?? DateTime.now(),
      allowDuplicate: json['allow_duplicate'] == true,
    );
  }

  /// Shape the local submission like a server row so the UI can render it with
  /// the same card widget.
  Map<String, dynamic> toRow() => {
        'id': localId,
        'household_no': householdNo,
        'collection_status': 'pending',
        'interview_date': payload['interview_date'],
        'respondent_name_burmese': payload['respondent_name_burmese'],
        'township': payload['township'],
        'state_region': payload['state_region'],
        '_local': true,
      };
}

/// Result of a submission attempt: either stored on the server, or queued
/// locally for automatic retry.
class SubmitOutcome {
  const SubmitOutcome({required this.queued, required this.record});

  final bool queued;
  final Map<String, dynamic> record;
}

/// Owns the enumerator's own submissions: a short in-memory list, a durable
/// offline cache, the pending-upload queue and optimistic updates driven by the
/// real-time WebSocket events.
///
/// The backend enforces per-user isolation, so every fetch asks for `mine=true`:
/// the app never sees another enumerator's records.
class SubmissionRepository extends ChangeNotifier {
  SubmissionRepository({ApiClient? client, LocalStore? store})
      : _api = client ?? api,
        _store = store ?? LocalStore.instance;

  final ApiClient _api;
  final LocalStore _store;

  // Keys are scoped by user id so one account can never surface (or, worse,
  // upload) another account's cached rows or queued submissions.
  String get _cacheKey => 'moali_history_cache_v1:${_userId ?? 'anon'}';
  String get _pendingKey => 'moali_pending_submissions_v1:${_userId ?? 'anon'}';

  static const String _autoSyncKey = 'moali_auto_sync_v1';

  final List<Map<String, dynamic>> _server = [];
  final List<PendingSubmission> _pending = [];

  String? _userId;
  bool _loading = false;
  bool _offline = false;
  bool _autoSync = true;
  String? _error;
  DateTime? _cachedAt;
  Timer? _refreshDebounce;
  bool _disposed = false;

  /// `notifyListeners` throws if called after [dispose]; network callbacks can
  /// land after the shell is torn down (e.g. sign-out), so funnel everything
  /// through this guard.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ------------------------------------------------------------------
  // read model
  // ------------------------------------------------------------------

  /// Pending (unsynced) rows first, then the server rows.
  List<Map<String, dynamic>> get items => [
        for (final p in _pending) p.toRow(),
        ..._server,
      ];

  List<Map<String, dynamic>> get serverItems => List.unmodifiable(_server);
  int get pendingCount => _pending.length;
  bool get loading => _loading;
  bool get hasCache => _cachedAt != null;
  bool get showingCachedData => _offline && _server.isNotEmpty;

  /// Whether queued submissions are uploaded automatically when the connection
  /// returns. Toggled from the settings screen and persisted on the device.
  bool get autoSync => _autoSync;
  String? get error => _error;
  DateTime? get cachedAt => _cachedAt;

  /// Personal, on-device summary of the enumerator's own work.
  Map<String, int> get summary {
    var today = 0;
    final now = DateTime.now();
    for (final s in _server) {
      final raw = '${s['interview_date'] ?? s['created_at'] ?? ''}';
      final d = DateTime.tryParse(raw);
      if (d != null &&
          d.year == now.year &&
          d.month == now.month &&
          d.day == now.day) {
        today++;
      }
    }
    return {
      'total': _server.length,
      'today': today,
      'pending': _pending.length,
      'synced': _server
          .where((s) => '${s['collection_status']}'.toLowerCase() != 'approved')
          .length,
      'live': _server
          .where((s) => '${s['collection_status']}'.toLowerCase() == 'approved')
          .length,
    };
  }

  // ------------------------------------------------------------------
  // lifecycle
  // ------------------------------------------------------------------

  /// Load the offline cache then refresh from the server.
  Future<void> init(String userId) async {
    _userId = userId;
    await _loadAutoSync();
    await _loadCache();
    _notify();
    await refresh(silent: _server.isNotEmpty || _pending.isNotEmpty);
  }

  /// Toggle automatic background upload of the offline queue.
  Future<void> setAutoSync(bool value) async {
    if (_autoSync == value) return;
    _autoSync = value;
    _notify();
    await _store.writeString(_autoSyncKey, value ? '1' : '0');
    if (value && _pending.isNotEmpty) unawaited(flushPending());
  }

  Future<void> _loadAutoSync() async {
    final raw = await _store.readString(_autoSyncKey);
    if (raw != null) _autoSync = raw == '1';
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshDebounce?.cancel();
    super.dispose();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce =
        Timer(const Duration(milliseconds: 400), () => refresh(silent: true));
  }

  Future<void> _loadCache() async {
    final cache = await _store.readJson(_cacheKey);
    if (cache != null) {
      final items = (cache['items'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const [];
      _server
        ..clear()
        ..addAll(items);
      _cachedAt = DateTime.tryParse('${cache['cached_at']}');
    }

    final pending = await _store.readJsonList(_pendingKey);
    if (pending != null) {
      _pending
        ..clear()
        ..addAll(pending.whereType<Map>().map(
            (e) => PendingSubmission.fromJson(Map<String, dynamic>.from(e))));
    }
  }

  Future<void> _saveCache() async {
    await _store.writeJson(_cacheKey, {
      'user_id': _userId,
      'cached_at': (_cachedAt ?? DateTime.now()).toIso8601String(),
      'items': _server,
    });
  }

  Future<void> _savePending() async {
    await _store.writeJson(
        _pendingKey, [for (final p in _pending) p.toJson()]);
  }

  // ------------------------------------------------------------------
  // network
  // ------------------------------------------------------------------

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final data = await _api.listSubmissions(pageSize: 100, mine: true);
      _server
        ..clear()
        ..addAll((data['items'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e)) ??
            const []);
      _offline = false;
      _error = null;
      _cachedAt = DateTime.now();
      await _saveCache();
      // A successful fetch means we are online again: drain the queue.
      if (_pending.isNotEmpty && _autoSync) unawaited(flushPending());
    } on ApiException catch (e) {
      if (e.statusCode == 0) {
        _offline = true;
      } else {
        _error = e.message;
        _offline = false;
      }
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Submit a census.
  ///
  /// Returns a [SubmitOutcome] which is `queued: true` when the network was
  /// unreachable (the payload is stored locally and retried automatically).
  /// A duplicate (HTTP 409) or a validation error is rethrown so the survey
  /// screen can react to it exactly as before.
  Future<SubmitOutcome> submit(
    Map<String, dynamic> payload, {
    bool allowDuplicate = false,
  }) async {
    try {
      final created = await _api.submitSurvey(payload,
          allowDuplicate: allowDuplicate);
      _server.insert(0, created);
      _cachedAt = DateTime.now();
      _offline = false;
      await _saveCache();
      _notify();
      return SubmitOutcome(queued: false, record: created);
    } on ApiException catch (e) {
      if (e.statusCode != 0) rethrow;
      final pending = PendingSubmission(
        localId: 'local-${DateTime.now().microsecondsSinceEpoch}',
        payload: Map<String, dynamic>.from(payload),
        householdNo: '${payload['household_no'] ?? '—'}',
        createdAt: DateTime.now(),
        allowDuplicate: allowDuplicate,
      );
      _pending.insert(0, pending);
      _offline = true;
      await _savePending();
      _notify();
      return SubmitOutcome(queued: true, record: pending.toRow());
    }
  }

  /// Upload every queued submission. Returns how many succeeded.
  ///
  /// Transient failures (network / 5xx) stay in the queue; permanent rejection
  /// (4xx other than a duplicate) is dropped so one bad record cannot block the
  /// rest of the queue forever.
  Future<int> flushPending({void Function(int done, int total)? onProgress}) async {
    if (_pending.isEmpty) return 0;
    var uploaded = 0;
    final total = _pending.length;
    final remaining = <PendingSubmission>[];
    for (var i = 0; i < _pending.length; i++) {
      final p = _pending[i];
      try {
        final created = await _api.submitSurvey(p.payload,
            allowDuplicate: p.allowDuplicate);
        _server.insert(0, created);
        uploaded++;
      } on ApiException catch (e) {
        if (e.statusCode == 0 || e.statusCode >= 500) {
          remaining.add(p);
        } else if (e.statusCode == 409) {
          // Already on the server from a previous attempt.
          uploaded++;
        }
        // Any other 4xx is a permanent rejection — drop it.
      }
      onProgress?.call(i + 1, total);
    }
    _pending
      ..clear()
      ..addAll(remaining);
    _cachedAt = DateTime.now();
    _offline = remaining.isNotEmpty && uploaded == 0;
    await _savePending();
    await _saveCache();
    _notify();
    return uploaded;
  }

  // ------------------------------------------------------------------
  // realtime
  // ------------------------------------------------------------------

  /// Apply a WebSocket event (`{type, data}`) to the local view.
  ///
  /// New/updated records are merged optimistically; anything we cannot map to a
  /// known row triggers a debounced background refresh.
  void handleEvent(Map<String, dynamic> event) {
    final type = '${event['type']}';
    final data = event['data'];
    if (data is! Map || data['id'] == null) {
      if (type == 'submission.created' || type == 'submission.status_changed') {
        _scheduleRefresh();
      }
      return;
    }
    final id = '${data['id']}';
    final index = _server.indexWhere((row) => '${row['id']}' == id);
    if (index >= 0) {
      _server[index] = {
        ..._server[index],
        ...Map<String, dynamic>.from(data),
      };
      _cachedAt = DateTime.now();
      unawaited(_saveCache());
      _notify();
    } else {
      // A record we do not hold in full (e.g. created on another device):
      // pull the authoritative row.
      _scheduleRefresh();
    }
  }

  /// Localized tag for a history row: Pending / Synced / Live.
  static String statusTag(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'approved':
        return 'live';
      case 'pending':
        return 'pending';
      default:
        return 'synced';
    }
  }

  /// Exposed for tests: the raw JSON stored under the pending key.
  @visibleForTesting
  static String encodePendingForTest(List<PendingSubmission> items) =>
      jsonEncode([for (final p in items) p.toJson()]);
}
