// lib/viewmodels/pet_viewmodel.dart

import 'package:flutter/material.dart';
import '../data/local/database_helper.dart';
import '../data/remote/firebase_service.dart';
import '../services/ai_insight_engine.dart';
import '../models/models.dart';

enum PetMood { happy, neutral, sad, angry }

class PetViewModel extends ChangeNotifier {
  // ── Today state ───────────────────────────────────────
  int _todayUsageMinutes = 0;
  int _streak = 0;
  int _bestStreak = 0;
  PetMood _currentMood = PetMood.happy;
  int _dailyLimit = 120;
  Map<String, int> _appUsageBreakdown = {};
  List<AiInsight> _insights = [];
  List<Map<String, dynamic>> _weeklyData = [];
  bool _isLoading = false;
  String _lastSyncDate = '';

  // ── Analytics state ───────────────────────────────────
  AnalyticsData _analytics = AnalyticsData.empty;
  double _addictionScore = 0;

  // ── Getters ───────────────────────────────────────────
  int get todayUsageMinutes => _todayUsageMinutes;
  int get streak => _streak;
  int get bestStreak => _bestStreak;
  PetMood get currentMood => _currentMood;
  int get dailyLimit => _dailyLimit;
  Map<String, int> get appUsageBreakdown => _appUsageBreakdown;
  List<AiInsight> get insights => _insights;
  List<Map<String, dynamic>> get weeklyData => _weeklyData;
  bool get isLoading => _isLoading;
  double get progressToLimit => (_todayUsageMinutes / _dailyLimit).clamp(0.0, 1.0);
  AnalyticsData get analytics => _analytics;
  double get addictionScore => _addictionScore;

  // ── Load ──────────────────────────────────────────────
  Future<void> loadTodayData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _todayUsageMinutes = await DatabaseHelper.instance
          .getTodayTotalUsage()
          .timeout(const Duration(seconds: 3));
      _appUsageBreakdown = await DatabaseHelper.instance
          .getTodayAppBreakdown()
          .timeout(const Duration(seconds: 3));
      _weeklyData = (await DatabaseHelper.instance
          .getWeeklyData()
          .timeout(const Duration(seconds: 3)))
          .reversed
          .toList();
      await _calculateStreak().timeout(const Duration(seconds: 3));
    } catch (e) {
      _todayUsageMinutes = 0;
      _appUsageBreakdown = {};
      _weeklyData = [];
      _streak = 0;
    }

    _calculateMood();

    try {
      await _buildAnalytics().timeout(const Duration(seconds: 5));
    } catch (_) {
      _insights = [];
    }

    try {
      await _cloudSync().timeout(const Duration(seconds: 4));
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  // ── Usage tracking ────────────────────────────────────
  // Handles multiple rapid app switches correctly:
  // Each call to addUsage is independent, so switching A→B→A→C
  // all get logged correctly as separate sessions.
  void addUsage(String appName, int minutes) async {
    if (minutes < 1) return;
    await DatabaseHelper.instance.insertLog(appName, minutes);
    await loadTodayData();
  }

  Future<void> resetStats() async {
    await DatabaseHelper.instance.deleteAllLogs();
    _todayUsageMinutes = 0;
    _streak = 0;
    _bestStreak = 0;
    _appUsageBreakdown = {};
    _insights = [];
    _weeklyData = [];
    _currentMood = PetMood.happy;
    _analytics = AnalyticsData.empty;
    _addictionScore = 0;
    _lastSyncDate = '';
    notifyListeners();
  }

  Future<void> injectDemoData() async {
    await DatabaseHelper.instance.seedDemoData();
    _lastSyncDate = '';
    await loadTodayData();
  }

  void updateDailyLimit(int minutes) {
    _dailyLimit = minutes;
    _calculateMood();
    notifyListeners();
  }

  // ── Mood ──────────────────────────────────────────────
  void _calculateMood() {
    if (_todayUsageMinutes <= 60) {
      _currentMood = PetMood.happy;
    } else if (_todayUsageMinutes <= _dailyLimit) {
      _currentMood = PetMood.neutral;
    } else if (_todayUsageMinutes <= _dailyLimit + 60) {
      _currentMood = PetMood.sad;
    } else {
      _currentMood = PetMood.angry;
    }
  }

  // ── Streak ────────────────────────────────────────────
  Future<void> _calculateStreak() async {
    int count = 0;
    while (true) {
      final date = DateTime.now().subtract(Duration(days: count + 1));
      final usage = await DatabaseHelper.instance.getUsageByDate(date);
      if (usage > 0 && usage <= _dailyLimit) {
        count++;
      } else {
        break;
      }
    }
    _streak = count;
    if (_streak > _bestStreak) _bestStreak = _streak;
  }

  // ── Analytics Build ───────────────────────────────────
  Future<void> _buildAnalytics() async {
    final db = DatabaseHelper.instance;

    final dailyTotals = await db.getDailyTotalsForDays(14);
    final weekBreakdown = await db.getAppBreakdownForDays(7);
    final heatmap = await db.getTimeOfDayHeatmap();
    final nightMins = await db.getNightUsageMinutes(7);
    final wkData = await db.getWeekendVsWeekdayUsage();
    final weekendMins = wkData['weekend'] ?? 0;
    final weekdayMins = wkData['weekday'] ?? 0;

    // Count streak breaks in last 7 days
    int streakBreaks = 0;
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final usage = await db.getUsageByDate(date);
      if (usage > _dailyLimit && usage > 0) streakBreaks++;
    }

    _addictionScore = AiInsightEngine.instance.computeAddictionScore(
      weekendTotalMins: weekendMins,
      weekdayTotalMins: weekdayMins,
      nightMins7Days: nightMins,
      streakBreaks: streakBreaks,
    );

    // Improvement % — compare last 3 days avg vs 3 days before that
    double improvementPct = 0;
    String trend = '→';
    if (dailyTotals.length >= 6) {
      final recent = dailyTotals.sublist(dailyTotals.length - 3);
      final older = dailyTotals.sublist(dailyTotals.length - 6, dailyTotals.length - 3);
      final avgRecent = _avg(recent);
      final avgOlder = _avg(older);
      if (avgOlder > 0) {
        improvementPct = ((avgOlder - avgRecent) / avgOlder * 100);
        trend = improvementPct > 5
            ? '↓'
            : improvementPct < -5
            ? '↑'
            : '→';
      }
    }

    _analytics = AnalyticsData(
      weeklyData: _weeklyData,
      appBreakdown: weekBreakdown,
      heatmap: heatmap,
      addictionScore: _addictionScore,
      addictionLevel: AiInsightEngine.instance.addictionLevel(_addictionScore),
      improvementPct: improvementPct,
      trendDirection: trend,
      nightMins: nightMins,
      weekendMins: weekendMins,
    );

    _insights = AiInsightEngine.instance.analyse(
      dailyTotals: dailyTotals,
      streak: _streak,
      dailyLimit: _dailyLimit,
      appBreakdown: weekBreakdown,
      addictionScore: _addictionScore,
      nightMins: nightMins,
      weekendMins: weekendMins,
      weekdayMins: weekdayMins,
    );
  }

  // ── Offline-first cloud sync ──────────────────────────
  Future<void> _cloudSync() async {
    final today =
    DateTime.now().toIso8601String().split('T')[0];
    if (_lastSyncDate == today) return;

    // 1. Write to local sync queue first (offline-first)
    await DatabaseHelper.instance.upsertSyncQueue(
      date: today,
      totalUsage: _todayUsageMinutes,
      mood: _currentMood.name,
      streak: _streak,
      addictionScore: _addictionScore,
    );

    // 2. Process all unsynced records
    final pending =
    await DatabaseHelper.instance.getUnsyncedRecords();
    for (final record in pending) {
      try {
        await FirebaseService.instance.syncDailySummary(
          date: record['date'] as String,
          totalMinutes: record['total_usage'] as int,
          streak: record['streak'] as int,
          mood: record['mood'] as String,
          addictionScore:
          (record['addiction_score'] as num).toDouble(),
          appBreakdown: _appUsageBreakdown,
        );
        await DatabaseHelper.instance
            .markSynced(record['date'] as String);
      } catch (_) {
        // Will retry next time
      }
    }

    await FirebaseService.instance.updateBestStreak(_streak);
    _lastSyncDate = today;
  }

  // ── Pet display ───────────────────────────────────────
  String get imagePath {
    switch (_currentMood) {
      case PetMood.happy:   return 'assets/memes/happy.png';
      case PetMood.neutral: return 'assets/memes/neutral.png';
      case PetMood.sad:     return 'assets/memes/sad.png';
      case PetMood.angry:   return 'assets/memes/angry.png';
    }
  }

  String get moodStatus {
    switch (_currentMood) {
      case PetMood.happy:   return "Vibing! Keep it up!";
      case PetMood.neutral: return "I'm bored from watching you scrolling.";
      case PetMood.sad:     return "Bro... put the phone down 😭";
      case PetMood.angry:   return "THAT'S IT. I'M ANGRY.";
    }
  }

  Color get moodColor {
    switch (_currentMood) {
      case PetMood.happy:   return const Color(0xFF43D97B);
      case PetMood.neutral: return const Color(0xFFFFD93D);
      case PetMood.sad:     return const Color(0xFFFF9A3C);
      case PetMood.angry:   return const Color(0xFFFF006E);
    }
  }

  void debugSetUsage(int minutes) {
    _todayUsageMinutes = minutes;
    _calculateMood();
    notifyListeners();
  }

  double _avg(List<int> v) =>
      v.isEmpty ? 0 : v.fold(0, (a, b) => a + b) / v.length;
}
