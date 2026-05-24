import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/supabase_service.dart';

void main() => runApp(const HabitApp());

class HabitApp extends StatelessWidget {
  const HabitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF50fa7b),
          surface: Color(0xFF0f0f1a),
        ),
        scaffoldBackgroundColor: const Color(0xFF0f0f1a),
        cardTheme: CardThemeData(
          color: const Color(0xFF1a1a2e),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ── Ana ekran ──────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HabitData? _data;
  String _supabaseUrl = '';
  String _supabaseAnonKey = '';
  bool _syncing = false;
  bool _syncError = false;
  bool _editMode = false;
  bool _syncRunning = false;
  int _syncVersion = 0;
  String _syncMessage = '';
  late String _todayStr;

  @override
  void initState() {
    super.initState();
    _todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadPrefs().then((_) => _syncFromSupabase());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _supabaseUrl = prefs.getString('supabaseUrl') ?? '';
      _supabaseAnonKey = prefs.getString('supabaseAnonKey') ?? '';
      final raw = prefs.getString('habitData');
      if (raw != null) {
        _data = HabitData.fromJson(jsonDecode(raw));
      }
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabaseUrl', _supabaseUrl);
    await prefs.setString('supabaseAnonKey', _supabaseAnonKey);
    if (_data != null) {
      await prefs.setString('habitData', jsonEncode(_data!.toJson()));
    }
  }

  SupabaseService? get _service {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) return null;
    return SupabaseService(
      projectUrl: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
  }

  Future<void> _syncFromSupabase() async {
    final svc = _service;
    if (svc == null) return;
    setState(() {
      _syncing = true;
      _syncError = false;
    });
    final remote = await svc.fetch();
    if (remote == null) {
      final seed = _data != null && _data!.habits.isNotEmpty
          ? _data!
          : HabitData.defaults();
      setState(() {
        _data = seed;
      });
      await _savePrefs();
      final ok = await svc.push(seed);
      setState(() {
        _syncing = false;
        _syncError = !ok;
      });
      return;
    }
    if (remote.habits.isEmpty) {
      final seed = _data != null && _data!.habits.isNotEmpty
          ? _data!
          : HabitData.defaults();
      setState(() {
        _data = seed;
      });
      await _savePrefs();
      final ok = await svc.push(seed);
      setState(() {
        _syncing = false;
        _syncError = !ok;
      });
      return;
    }
    final merged = _data != null && _data!.habits.isNotEmpty
        ? svc.merge(_data!, remote)
        : remote;
    setState(() {
      _data = merged;
      _syncing = false;
    });
    await _savePrefs();
  }

  Future<void> _syncToSupabase() async {
    _syncVersion++;
    if (_syncRunning) return;

    final svc = _service;
    if (svc == null) return;
    _syncRunning = true;
    setState(() {
      _syncing = true;
      _syncError = false;
    });

    var result = const PushResult(ok: true);
    while (true) {
      final version = _syncVersion;
      final snapshot = _data;
      if (snapshot == null) break;

      result = await svc.pushDetailed(snapshot);
      if (!result.ok || version == _syncVersion) break;
    }

    _syncRunning = false;
    setState(() {
      _syncing = false;
      _syncError = !result.ok;
      _syncMessage = result.ok ? '' : result.message;
    });
  }

  Future<void> _addHabit(String name, int points, bool isExtra) async {
    final habits = List<Map<String, dynamic>>.from(_data?.habits ?? []);
    final maxId = habits.isEmpty
        ? 0
        : habits.map((h) => h['id'] as int).reduce((a, b) => a > b ? a : b);
    habits.add({
      'id': maxId + 1,
      'name': name,
      'points': isExtra ? 0 : points,
      'isExtra': isExtra ? 1 : 0,
    });
    setState(() {
      _data = HabitData(
        habits: habits,
        dailyRecords: _data?.dailyRecords ?? {},
        scoreHistory: _data?.scoreHistory ?? {},
        lastModified: DateTime.now().toUtc().toIso8601String(),
      );
    });
    await _savePrefs();
    await _syncToSupabase();
  }

  Future<void> _deleteHabit(int index) async {
    if (_data == null) return;
    final habits = List<Map<String, dynamic>>.from(_data!.habits)
      ..removeAt(index);
    setState(() {
      _data = HabitData(
        habits: habits,
        dailyRecords: _data!.dailyRecords,
        scoreHistory: _data!.scoreHistory,
        lastModified: DateTime.now().toUtc().toIso8601String(),
      );
    });
    await _savePrefs();
    await _syncToSupabase();
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final pointsCtrl = TextEditingController(text: '20');
    bool isExtra = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text('Habit Ekle', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('İsim:',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(fontSize: 13),
                decoration: _inputDec('Habit adı'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Puan:',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 12)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: pointsCtrl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 13),
                          decoration: _inputDec('20'),
                          enabled: !isExtra,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      const Text('Extra ★',
                          style:
                              TextStyle(color: Colors.white54, fontSize: 12)),
                      Switch(
                        value: isExtra,
                        activeThumbColor: const Color(0xFFf1fa8c),
                        onChanged: (v) => setLocal(() => isExtra = v),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            TextButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final pts = int.tryParse(pointsCtrl.text) ?? 20;
                Navigator.pop(ctx);
                _addHabit(name, pts.clamp(1, 100), isExtra);
              },
              child: const Text('Ekle',
                  style: TextStyle(color: Color(0xFF50fa7b))),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleHabit(Map<String, dynamic> habit) async {
    if (_data == null) return;
    final id = habit['id'].toString();
    final records = Map<String, dynamic>.from(_data!.dailyRecords);
    final today = Map<String, dynamic>.from(
        (records[_todayStr] as Map<String, dynamic>?) ?? {});
    if (today[id] == true) {
      today.remove(id);
    } else {
      today[id] = true;
    }
    records[_todayStr] = today;

    // Bugünün puanını hesapla ve history'e yaz
    final history = Map<String, dynamic>.from(_data!.scoreHistory);
    final completed =
        today.entries.where((e) => e.value == true).map((e) => e.key).toSet();
    int score = 0;
    for (final h in _data!.habits) {
      if (h['isExtra'] == 1) continue;
      if (completed.contains(h['id'].toString())) score += (h['points'] as int);
    }
    history[_todayStr] = score.clamp(0, 100);

    setState(() {
      _data = HabitData(
        habits: _data!.habits,
        dailyRecords: records,
        scoreHistory: history,
        lastModified: DateTime.now().toUtc().toIso8601String(),
      );
    });
    await _savePrefs();
    await _syncToSupabase();
  }

  // Son 7 günün puan listesi
  List<int> get _chartData {
    if (_data == null) return List.filled(7, 0);
    final history = _data!.scoreHistory;
    return List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      final key = DateFormat('yyyy-MM-dd').format(d);
      if (i == 6) return _data!.todayScore(_todayStr);
      return (history[key] as num?)?.toInt() ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final score = _data?.todayScore(_todayStr) ?? 0;
    final star = _data?.todayStar(_todayStr) ?? false;
    final completed = _data?.todayCompleted(_todayStr) ?? {};
    final habits = _data?.habits ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f1a),
        title: Row(
          children: [
            Text(
              DateFormat('d MMM').format(DateTime.now()),
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const Spacer(),
            if (_syncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFFf1fa8c)),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty
                      ? Colors.transparent
                      : _syncError
                          ? const Color(0xFFff5555)
                          : const Color(0xFF50fa7b),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              star ? '⭐' : '$score/100',
              style: TextStyle(
                color: star ? const Color(0xFFf1fa8c) : const Color(0xFF50fa7b),
                fontWeight: FontWeight.bold,
                fontSize: star ? 22 : 16,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_editMode ? Icons.check : Icons.edit, size: 20),
            onPressed: () => setState(() => _editMode = !_editMode),
            tooltip: _editMode ? 'Bitti' : 'Düzenle',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _syncFromSupabase,
            tooltip: 'Supabase\'den al',
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: () => _openSettings(),
            tooltip: 'Ayarlar',
          ),
        ],
      ),
      floatingActionButton: _editMode
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: const Color(0xFF50fa7b),
              foregroundColor: Colors.black,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Grafik
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child:
                SizedBox(height: 70, child: _ChartWidget(points: _chartData)),
          ),
          const SizedBox(height: 8),
          if (_syncError && _syncMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _syncMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFff5555), fontSize: 11),
              ),
            ),
          // Habit listesi
          Expanded(
            child: habits.isEmpty
                ? const Center(
                    child: Text('Supabase ayarlarını girin\nve veriyi çekin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white38)))
                : ListView.separated(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemCount: habits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final h = habits[i];
                      final id = h['id'].toString();
                      final isExtra = h['isExtra'] == 1;
                      final done = completed.contains(id);
                      return _HabitTile(
                        name: h['name'] as String,
                        points: h['points'] as int,
                        isExtra: isExtra,
                        completed: done,
                        editMode: _editMode,
                        onTap: _editMode ? null : () => _toggleHabit(h),
                        onDelete: () => _deleteHabit(i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _normalizeSupabaseUrl(String url) {
    var normalized = url;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  void _openSettings() {
    final urlCtrl = TextEditingController(text: _supabaseUrl);
    final keyCtrl = TextEditingController(text: _supabaseAnonKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text('Supabase Ayarları', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Project URL:',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            TextField(
              controller: urlCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDec('https://proje.supabase.co'),
            ),
            const SizedBox(height: 12),
            const Text('Anon/Public Key:',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              style: const TextStyle(fontSize: 13),
              decoration: _inputDec('eyJ...'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Supabase → Settings → API\nTablo: public.habittracker_state',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          TextButton(
            onPressed: () async {
              setState(() {
                _supabaseUrl = _normalizeSupabaseUrl(urlCtrl.text.trim());
                _supabaseAnonKey = keyCtrl.text.trim();
              });
              Navigator.pop(ctx);
              await _savePrefs();
              await _syncFromSupabase();
            },
            child: const Text('Kaydet & Senkronize Et',
                style: TextStyle(color: Color(0xFF50fa7b))),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );
}

// ── Habit satırı ───────────────────────────────────────────────────────────────

class _HabitTile extends StatelessWidget {
  final String name;
  final int points;
  final bool isExtra;
  final bool completed;
  final bool editMode;
  final VoidCallback? onTap;
  final VoidCallback onDelete;

  const _HabitTile({
    required this.name,
    required this.points,
    required this.isExtra,
    required this.completed,
    required this.editMode,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isExtra
              ? const Color(0xFFf1fa8c).withValues(alpha: 0.06)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isExtra
                ? const Color(0xFFf1fa8c).withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          children: [
            if (editMode)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFff5555), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onDelete,
              )
            else ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color:
                      completed ? const Color(0xFF50fa7b) : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: completed ? const Color(0xFF50fa7b) : Colors.white30,
                  ),
                ),
                child: completed
                    ? const Icon(Icons.check, size: 14, color: Colors.black)
                    : null,
              ),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color:
                      (!editMode && completed) ? Colors.white30 : Colors.white,
                  fontSize: 14,
                  decoration: (!editMode && completed)
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            isExtra
                ? const Text('★',
                    style: TextStyle(color: Color(0xFFf1fa8c), fontSize: 16))
                : Text(
                    '$points',
                    style: const TextStyle(color: Colors.white30, fontSize: 12),
                  ),
          ],
        ),
      ),
    );
  }
}

// ── Haftalık grafik ────────────────────────────────────────────────────────────

class _ChartWidget extends StatelessWidget {
  final List<int> points;
  const _ChartWidget({required this.points});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(points),
      child: Container(),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<int> points;
  _ChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const pad = 4.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF50fa7b).withValues(alpha: 0.25),
          const Color(0xFF50fa7b).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final linePaint = Paint()
      ..color = const Color(0xFF50fa7b)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()..color = const Color(0xFF50fa7b);
    final dimPaint = Paint()..color = Colors.white30;

    Offset pt(int i) {
      final x = pad + (i / (points.length - 1)) * w;
      final y = pad + h - (points[i].clamp(0, 100) / 100) * h;
      return Offset(x, y);
    }

    // Fill path
    final fill = Path();
    fill.moveTo(pad, size.height - pad);
    for (int i = 0; i < points.length; i++) {
      final p = pt(i);
      if (i == 0) {
        fill.lineTo(p.dx, p.dy);
      } else {
        final prev = pt(i - 1);
        final cpx = prev.dx + (p.dx - prev.dx) / 2;
        fill.cubicTo(cpx, prev.dy, cpx, p.dy, p.dx, p.dy);
      }
    }
    fill.lineTo(size.width - pad, size.height - pad);
    fill.close();
    canvas.drawPath(fill, fillPaint);

    // Line path
    final line = Path();
    for (int i = 0; i < points.length; i++) {
      final p = pt(i);
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
      } else {
        final prev = pt(i - 1);
        final cpx = prev.dx + (p.dx - prev.dx) / 2;
        line.cubicTo(cpx, prev.dy, cpx, p.dy, p.dx, p.dy);
      }
    }
    canvas.drawPath(line, linePaint);

    // Dots
    for (int i = 0; i < points.length; i++) {
      final p = pt(i);
      canvas.drawCircle(p, 2.5, i == points.length - 1 ? dotPaint : dimPaint);
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.points != points;
}
