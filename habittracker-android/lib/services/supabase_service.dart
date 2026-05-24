import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HabitData {
  final List<Map<String, dynamic>> habits;
  final Map<String, dynamic> dailyRecords;
  final Map<String, dynamic> scoreHistory;
  final String lastModified;

  HabitData({
    required this.habits,
    required this.dailyRecords,
    required this.scoreHistory,
    required this.lastModified,
  });

  factory HabitData.fromJson(Map<String, dynamic> json) {
    return HabitData(
      habits: List<Map<String, dynamic>>.from(json['habits'] ?? []),
      dailyRecords: Map<String, dynamic>.from(json['dailyRecords'] ?? {}),
      scoreHistory: Map<String, dynamic>.from(json['scoreHistory'] ?? {}),
      lastModified: json['lastModified'] ?? '',
    );
  }

  factory HabitData.defaults() {
    return HabitData(
      habits: [
        {'id': 1, 'name': 'Drink Water', 'points': 20, 'isExtra': 0},
        {'id': 2, 'name': 'Walk 5k', 'points': 20, 'isExtra': 0},
        {'id': 3, 'name': 'Push-ups', 'points': 20, 'isExtra': 0},
        {'id': 4, 'name': 'Read', 'points': 20, 'isExtra': 0},
        {'id': 5, 'name': 'Meditate', 'points': 20, 'isExtra': 0},
        {'id': 6, 'name': 'Extra', 'points': 0, 'isExtra': 1},
      ],
      dailyRecords: {},
      scoreHistory: {},
      lastModified: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'habits': habits,
        'dailyRecords': dailyRecords,
        'scoreHistory': scoreHistory,
        'lastModified': lastModified,
      };

  Set<String> todayCompleted(String todayStr) {
    final record = dailyRecords[todayStr];
    if (record == null) return {};
    return Map<String, dynamic>.from(record)
        .entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toSet();
  }

  int todayScore(String todayStr) {
    final completed = todayCompleted(todayStr);
    int score = 0;
    for (final h in habits) {
      if (h['isExtra'] == 1) continue;
      if (completed.contains(h['id'].toString())) {
        score += (h['points'] as int);
      }
    }
    return score.clamp(0, 100);
  }

  bool todayStar(String todayStr) {
    final completed = todayCompleted(todayStr);
    final score = todayScore(todayStr);
    final extraDone = habits
        .where((h) => h['isExtra'] == 1)
        .any((h) => completed.contains(h['id'].toString()));
    return score >= 100 && extraDone;
  }
}

class PushResult {
  final bool ok;
  final int? statusCode;
  final String? body;
  final String? error;

  const PushResult({
    required this.ok,
    this.statusCode,
    this.body,
    this.error,
  });

  String get message {
    if (ok) return 'sync ok';
    if (statusCode != null) {
      final detail = body == null || body!.isEmpty ? '' : ': $body';
      return 'HTTP $statusCode$detail';
    }
    return error ?? 'sync failed';
  }
}

class _HttpResult {
  final int statusCode;
  final String body;

  const _HttpResult(this.statusCode, this.body);
}

class SupabaseService {
  final String projectUrl;
  final String anonKey;

  SupabaseService({required this.projectUrl, required this.anonKey});

  String get _baseUrl {
    var url = projectUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  String get _readPath =>
      '$_baseUrl/rest/v1/habittracker_state?id=eq.default&select=data';

  String get _writePath =>
      '$_baseUrl/rest/v1/habittracker_state?on_conflict=id';

  void _setHeaders(HttpClientRequest req) {
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    req.headers.set(HttpHeaders.connectionHeader, 'close');
    req.headers.set('apikey', anonKey);
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $anonKey');
  }

  Future<String?> _rawGet() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.idleTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(Uri.parse(_readPath));
      _setHeaders(req);
      final res = await req.close().timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        stderr.writeln('[Supabase] fetch failed: ${res.statusCode}');
        await res.drain();
        return null;
      }
      return await res.transform(const Utf8Decoder()).join();
    } finally {
      client.close(force: true);
    }
  }

  Future<_HttpResult> _rawUpsert(String body) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.idleTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(Uri.parse(_writePath));
      final bytes = utf8.encode(body);
      _setHeaders(req);
      req.headers.contentLength = bytes.length;
      req.headers.set('Prefer', 'resolution=merge-duplicates,return=minimal');
      req.add(bytes);
      final res = await req.close().timeout(const Duration(seconds: 15));
      final responseBody = await res.transform(const Utf8Decoder()).join();
      return _HttpResult(res.statusCode, responseBody);
    } finally {
      client.close(force: true);
    }
  }

  Future<HabitData?> fetch({int retries = 3}) async {
    for (int i = 0; i < retries; i++) {
      try {
        final raw = await _rawGet();
        if (raw == null) return null;
        final rows = jsonDecode(raw);
        if (rows is! List || rows.isEmpty) return null;
        final row = Map<String, dynamic>.from(rows.first as Map);
        final data = row['data'];
        if (data is! Map) return null;
        return HabitData.fromJson(Map<String, dynamic>.from(data));
      } catch (e) {
        stderr.writeln('[Supabase] fetch error (attempt ${i + 1}): $e');
        if (i < retries - 1) await Future.delayed(const Duration(seconds: 2));
      }
    }
    return null;
  }

  Future<bool> push(HabitData data, {int retries = 3}) async {
    final result = await pushDetailed(data, retries: retries);
    return result.ok;
  }

  Future<PushResult> pushDetailed(HabitData data, {int retries = 3}) async {
    final body = jsonEncode({
      'id': 'default',
      'data': data.toJson(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    for (int i = 0; i < retries; i++) {
      try {
        final response = await _rawUpsert(body);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return const PushResult(ok: true);
        }
        stderr.writeln(
          '[Supabase] push failed: ${response.statusCode} ${response.body}',
        );
        return PushResult(
          ok: false,
          statusCode: response.statusCode,
          body: response.body,
        );
      } catch (e) {
        stderr.writeln('[Supabase] push error (attempt ${i + 1}): $e');
        if (i < retries - 1) await Future.delayed(const Duration(seconds: 2));
        if (i == retries - 1) {
          return PushResult(ok: false, error: e.toString());
        }
      }
    }
    return const PushResult(ok: false);
  }

  HabitData merge(HabitData local, HabitData remote) {
    final source =
        _isAfter(local.lastModified, remote.lastModified) ? local : remote;

    return HabitData(
      habits: source.habits.isNotEmpty ? source.habits : remote.habits,
      dailyRecords: Map<String, dynamic>.from(source.dailyRecords),
      scoreHistory: Map<String, dynamic>.from(source.scoreHistory),
      lastModified: source.lastModified.isNotEmpty
          ? source.lastModified
          : DateTime.now().toUtc().toIso8601String(),
    );
  }

  bool _isAfter(String left, String right) {
    final leftTime = DateTime.tryParse(left);
    final rightTime = DateTime.tryParse(right);
    if (leftTime == null) return false;
    if (rightTime == null) return true;
    return leftTime.isAfter(rightTime);
  }
}
