// lib/models/models.dart

class UsageSession {
  final int? id;
  final String date;
  final String appName;
  final int minutes;
  final String timestamp;

  UsageSession({
    this.id,
    required this.date,
    required this.appName,
    required this.minutes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'app_name': appName,
    'minutes': minutes,
    'timestamp': timestamp,
  };

  factory UsageSession.fromMap(Map<String, dynamic> m) => UsageSession(
    id: m['id'],
    date: m['date'],
    appName: m['app_name'],
    minutes: m['minutes'],
    timestamp: m['timestamp'],
  );
}

class AiInsight {
  final String title;
  final String description;
  final String emoji;
  final InsightType type;

  const AiInsight({
    required this.title,
    required this.description,
    required this.emoji,
    required this.type,
  });
}

enum InsightType { positive, warning, critical, tip }

/// Holds all computed analytics — passed to analytics screen
class AnalyticsData {
  final List<Map<String, dynamic>> weeklyData;
  final Map<String, int> appBreakdown;
  final Map<String, int> heatmap;       // morning/afternoon/evening/night
  final double addictionScore;
  final String addictionLevel;
  final double improvementPct;          // positive = improving
  final String trendDirection;          // '↑' or '↓' or '→'
  final int nightMins;
  final int weekendMins;

  const AnalyticsData({
    required this.weeklyData,
    required this.appBreakdown,
    required this.heatmap,
    required this.addictionScore,
    required this.addictionLevel,
    required this.improvementPct,
    required this.trendDirection,
    required this.nightMins,
    required this.weekendMins,
  });

  static const empty = AnalyticsData(
    weeklyData: [],
    appBreakdown: {},
    heatmap: {},
    addictionScore: 0,
    addictionLevel: 'Low',
    improvementPct: 0,
    trendDirection: '→',
    nightMins: 0,
    weekendMins: 0,
  );
}
