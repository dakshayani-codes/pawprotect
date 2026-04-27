// lib/data/local/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pawprotect.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usage_logs (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        date      TEXT    NOT NULL,
        app_name  TEXT    NOT NULL,
        minutes   INTEGER NOT NULL,
        timestamp TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sync_queue (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        date        TEXT    NOT NULL UNIQUE,
        total_usage INTEGER NOT NULL DEFAULT 0,
        mood        TEXT    NOT NULL DEFAULT 'happy',
        streak      INTEGER NOT NULL DEFAULT 0,
        addiction_score REAL NOT NULL DEFAULT 0,
        synced      INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldV, int newV) async {
    if (oldV < 3) {
      // Add sync_queue if upgrading from older version
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sync_queue (
          id          INTEGER PRIMARY KEY AUTOINCREMENT,
          date        TEXT    NOT NULL UNIQUE,
          total_usage INTEGER NOT NULL DEFAULT 0,
          mood        TEXT    NOT NULL DEFAULT 'happy',
          streak      INTEGER NOT NULL DEFAULT 0,
          addiction_score REAL NOT NULL DEFAULT 0,
          synced      INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  // ── Core CRUD ─────────────────────────────────────────────────────────────

  Future<void> insertLog(String appName, int minutes) async {
    final db = await database;
    final today = _dateKey(DateTime.now());
    await db.insert('usage_logs', {
      'date': today,
      'app_name': appName,
      'minutes': minutes,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteAllLogs() async {
    final db = await database;
    await db.delete('usage_logs');
    await db.delete('sync_queue');
  }

  // ── Today Queries ─────────────────────────────────────────────────────────

  Future<int> getTodayTotalUsage() async {
    final db = await database;
    final today = _dateKey(DateTime.now());
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(minutes),0) as total FROM usage_logs WHERE date=?',
      [today],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<Map<String, int>> getTodayAppBreakdown() async {
    final db = await database;
    final today = _dateKey(DateTime.now());
    final maps = await db.rawQuery(
      'SELECT app_name, SUM(minutes) as total FROM usage_logs WHERE date=? GROUP BY app_name',
      [today],
    );
    return {for (var m in maps) m['app_name'] as String: m['total'] as int};
  }

  // ── History Queries ───────────────────────────────────────────────────────

  Future<int> getUsageByDate(DateTime date) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(minutes),0) as total FROM usage_logs WHERE date=?',
      [_dateKey(date)],
    );
    return (result.first['total'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getWeeklyData() async {
    final db = await database;
    return db.rawQuery(
      'SELECT date, SUM(minutes) as total_minutes FROM usage_logs GROUP BY date ORDER BY date DESC LIMIT 7',
    );
  }

  Future<Map<String, int>> getAppBreakdownForDays(int days) async {
    final db = await database;
    final cutoff = _dateKey(DateTime.now().subtract(Duration(days: days)));
    final maps = await db.rawQuery(
      'SELECT app_name, SUM(minutes) as total FROM usage_logs WHERE date>=? GROUP BY app_name',
      [cutoff],
    );
    return {for (var m in maps) m['app_name'] as String: m['total'] as int};
  }

  /// Returns daily totals oldest→newest for the last [days].
  /// If a day has no data, returns 0 — so AI works even with 1 day of real data.
  Future<List<int>> getDailyTotalsForDays(int days) async {
    final totals = <int>[];
    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      totals.add(await getUsageByDate(date));
    }
    return totals;
  }

  // ── Night Usage ───────────────────────────────────────────────────────────
  // Night = hour >= 23 OR hour < 5

  Future<int> getNightUsageMinutes(int daysBack) async {
    final db = await database;
    final cutoff = _dateKey(DateTime.now().subtract(Duration(days: daysBack)));
    final rows = await db.rawQuery(
      'SELECT minutes, timestamp FROM usage_logs WHERE date>=?',
      [cutoff],
    );
    int nightMins = 0;
    for (final row in rows) {
      final ts = DateTime.tryParse(row['timestamp'] as String);
      if (ts != null && (ts.hour >= 23 || ts.hour < 5)) {
        nightMins += row['minutes'] as int;
      }
    }
    return nightMins;
  }

  // ── Heatmap: time-of-day buckets ──────────────────────────────────────────
  // Returns {morning, afternoon, evening, night} minute totals for last 7 days

  Future<Map<String, int>> getTimeOfDayHeatmap() async {
    final db = await database;
    final cutoff = _dateKey(DateTime.now().subtract(const Duration(days: 7)));
    final rows = await db.rawQuery(
      'SELECT minutes, timestamp FROM usage_logs WHERE date>=?',
      [cutoff],
    );

    int morning = 0, afternoon = 0, evening = 0, night = 0;
    for (final row in rows) {
      final ts = DateTime.tryParse(row['timestamp'] as String);
      final mins = row['minutes'] as int;
      if (ts == null) continue;
      if (ts.hour >= 5 && ts.hour < 12) {
        morning += mins;
      } else if (ts.hour >= 12 && ts.hour < 17) {
        afternoon += mins;
      } else if (ts.hour >= 17 && ts.hour < 23) {
        evening += mins;
      } else {
        night += mins;
      }
    }
    return {
      'Morning': morning,
      'Afternoon': afternoon,
      'Evening': evening,
      'Night': night,
    };
  }

  // ── Weekend vs Weekday usage ──────────────────────────────────────────────

  Future<Map<String, int>> getWeekendVsWeekdayUsage() async {
    int weekend = 0, weekday = 0;
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final usage = await getUsageByDate(date);
      if (date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday) {
        weekend += usage;
      } else {
        weekday += usage;
      }
    }
    return {'weekend': weekend, 'weekday': weekday};
  }

  // ── Sync Queue ────────────────────────────────────────────────────────────

  Future<void> upsertSyncQueue({
    required String date,
    required int totalUsage,
    required String mood,
    required int streak,
    required double addictionScore,
  }) async {
    final db = await database;
    await db.insert(
      'sync_queue',
      {
        'date': date,
        'total_usage': totalUsage,
        'mood': mood,
        'streak': streak,
        'addiction_score': addictionScore,
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    final db = await database;
    return db.query('sync_queue', where: 'synced=0');
  }

  Future<void> markSynced(String date) async {
    final db = await database;
    await db.update(
      'sync_queue',
      {'synced': 1},
      where: 'date=?',
      whereArgs: [date],
    );
  }

  // ── Demo Seed ─────────────────────────────────────────────────────────────

  Future<void> seedDemoData() async {
    final db = await database;
    await db.delete('usage_logs');
    await db.delete('sync_queue');

    // Improvement arc with realistic weekend spikes
    // timestamps include varied hours so heatmap works
    final Map<int, Map<String, dynamic>> demoData = {
      14: {'Instagram': 180, 'YouTube': 100, 'hour': 21},
      13: {'Instagram': 150, 'YouTube': 95,  'hour': 20},
      12: {'Instagram': 200, 'YouTube': 80,  'hour': 23}, // night + weekend
      11: {'Instagram': 220, 'YouTube': 90,  'hour': 22}, // weekend
      10: {'Instagram': 140, 'YouTube': 70,  'hour': 19},
      9:  {'Instagram': 120, 'YouTube': 60,  'hour': 14},
      8:  {'Instagram': 110, 'YouTube': 50,  'hour': 10},
      7:  {'Instagram': 130, 'YouTube': 80,  'hour': 23}, // night + weekend
      6:  {'Instagram': 160, 'YouTube': 75,  'hour': 21}, // weekend
      5:  {'Instagram': 100, 'YouTube': 40,  'hour': 18},
      4:  {'Instagram': 90,  'YouTube': 35,  'hour': 15},
      3:  {'Instagram': 80,  'YouTube': 30,  'hour': 11},
      2:  {'Instagram': 70,  'YouTube': 25,  'hour': 13},
      1:  {'Instagram': 60,  'YouTube': 20,  'hour': 16},
      0:  {'Instagram': 45,  'YouTube': 15,  'hour': 9},
    };

    for (final entry in demoData.entries) {
      final date = DateTime.now().subtract(Duration(days: entry.key));
      final dateStr = _dateKey(date);
      final hour = entry.value['hour'] as int;
      final ts = DateTime(date.year, date.month, date.day, hour);

      for (final appEntry in entry.value.entries) {
        if (appEntry.key == 'hour') continue;
        await db.insert('usage_logs', {
          'date': dateStr,
          'app_name': appEntry.key,
          'minutes': appEntry.value,
          'timestamp': ts.toIso8601String(),
        });
      }
    }
  }

  Future<bool> hasData() async {
    final db = await database;
    final result =
    await db.rawQuery('SELECT COUNT(*) as count FROM usage_logs');
    return (result.first['count'] as int) > 0;
  }

  // ── Helper ────────────────────────────────────────────────────────────────
  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
