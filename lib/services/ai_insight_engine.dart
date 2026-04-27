// lib/services/ai_insight_engine.dart
//
// On-device behavioral analytics engine.
// KEY DESIGN: works gracefully with as little as 1 day of real data.
// Does NOT require demo data to produce meaningful output.
//
// Addiction Score Formula:
//   score = (weekend_usage × 1.3) + (night_usage × 1.5) + (streak_breaks × 2)
//   Normalized to a 0–100 scale, then bucketed into Low/Medium/High/Critical.

import '../models/models.dart';

class AiInsightEngine {
  AiInsightEngine._();
  static final AiInsightEngine instance = AiInsightEngine._();

  /// Computes addiction score using the canonical formula.
  /// All inputs are optional — gracefully handles missing data.
  double computeAddictionScore({
    required int weekendTotalMins,
    required int weekdayTotalMins,
    required int nightMins7Days,
    required int streakBreaks,     // how many days out of last 7 streak was broken
  }) {
    final raw = (weekendTotalMins * 1.3) +
        (nightMins7Days * 1.5) +
        (streakBreaks * 2.0);
    // Normalize: 600 raw ≈ 100 score (600 = ~5h weekend + 2h night + 3 breaks)
    return (raw / 6.0).clamp(0.0, 100.0);
  }

  /// Maps addiction score to label
  String addictionLevel(double score) {
    if (score < 20) return 'Low';
    if (score < 45) return 'Medium';
    if (score < 70) return 'High';
    return 'Critical';
  }

  /// Main analysis function.
  /// [dailyTotals]: oldest→newest list (min length 1, ideally 7–14)
  /// Works with real data from day 1 — no demo data dependency.
  List<AiInsight> analyse({
    required List<int> dailyTotals,
    required int streak,
    required int dailyLimit,
    required Map<String, int> appBreakdown,
    required double addictionScore,
    int nightMins = 0,
    int weekendMins = 0,
    int weekdayMins = 0,
  }) {
    final insights = <AiInsight>[];
    if (dailyTotals.isEmpty) return insights;

    // Filter to only days with real data for calculations
    final activeTotals = dailyTotals.where((m) => m > 0).toList();
    final today = dailyTotals.last;

    // Use available data — works from 1 day
    final recent = activeTotals.isNotEmpty ? activeTotals : [today];
    final avgRecent = _avg(recent);

    // ── 1. Addiction Score Card (always shown if any data) ───────────────────
    final level = addictionLevel(addictionScore);
    final Color_emoji = level == 'Low' ? '✅'
        : level == 'Medium' ? '⚠️'
        : level == 'High' ? '🔴'
        : '🆘';
    insights.add(AiInsight(
      title: 'Addiction Level: $level',
      description: _addictionDescription(level, addictionScore.round(),
          nightMins, weekendMins),
      emoji: Color_emoji,
      type: level == 'Low'
          ? InsightType.positive
          : level == 'Medium'
          ? InsightType.tip
          : level == 'High'
          ? InsightType.warning
          : InsightType.critical,
    ));

    // ── 2. Today vs Average ──────────────────────────────────────────────────
    if (activeTotals.length >= 2) {
      final avgExcludingToday =
      _avg(activeTotals.sublist(0, activeTotals.length - 1));
      if (avgExcludingToday > 0) {
        final diff = today - avgExcludingToday;
        final pct = ((diff.abs() / avgExcludingToday) * 100).round();
        if (pct >= 10) {
          if (diff > 0) {
            insights.add(AiInsight(
              title: '$pct% More Than Your Average ↑',
              description:
              'You\'re using ${_fmt(diff.round())} more than your average of ${_fmt(avgExcludingToday.round())}. Your pet is watching.',
              emoji: '📈',
              type: InsightType.warning,
            ));
          } else {
            insights.add(AiInsight(
              title: '$pct% Less Than Your Average ↓',
              description:
              'You\'re using ${_fmt(diff.abs().round())} less than usual. Your pet is literally doing a happy dance.',
              emoji: '📉',
              type: InsightType.positive,
            ));
          }
        }
      }
    }

    // ── 3. Weekly Trend (needs 7+ days) ──────────────────────────────────────
    if (dailyTotals.length >= 7) {
      final recent7 = dailyTotals.sublist(dailyTotals.length - 7);
      final older7 = dailyTotals.length >= 14
          ? dailyTotals.sublist(dailyTotals.length - 14, dailyTotals.length - 7)
          : <int>[];

      if (older7.isNotEmpty) {
        final avgOlder = _avg(older7);
        final avgNewer = _avg(recent7);
        if (avgOlder > 0) {
          final pct = (((avgOlder - avgNewer) / avgOlder) * 100).round();
          if (pct > 10) {
            insights.add(AiInsight(
              title: 'Down $pct% vs Last Week 🎉',
              description:
              'Weekly average dropped from ${_fmt(avgOlder.round())} to ${_fmt(avgNewer.round())}. Real progress.',
              emoji: '🏆',
              type: InsightType.positive,
            ));
          } else if (pct < -10) {
            insights.add(AiInsight(
              title: 'Up ${pct.abs()}% vs Last Week',
              description:
              'Your weekly average climbed from ${_fmt(avgOlder.round())} to ${_fmt(avgNewer.round())}. Time to course-correct.',
              emoji: '📊',
              type: InsightType.warning,
            ));
          }
        }
      }

      // Weekend spike detection
      final weekdayUsages = <int>[];
      final weekendUsages = <int>[];
      for (int i = 0; i < recent7.length; i++) {
        final dayOffset = recent7.length - 1 - i;
        final date = DateTime.now().subtract(Duration(days: dayOffset));
        if (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          if (recent7[i] > 0) weekendUsages.add(recent7[i]);
        } else {
          if (recent7[i] > 0) weekdayUsages.add(recent7[i]);
        }
      }
      if (weekendUsages.isNotEmpty && weekdayUsages.isNotEmpty) {
        final avgWe = _avg(weekendUsages);
        final avgWd = _avg(weekdayUsages);
        if (avgWe > avgWd * 1.4) {
          insights.add(AiInsight(
            title: 'Weekend Binge Detected 📅',
            description:
            'Weekend usage is ${_fmt((avgWe - avgWd).round())} higher than weekdays. Your pet dreads Saturdays.',
            emoji: '📅',
            type: InsightType.warning,
          ));
        }
      }
    }

    // ── 4. Night Usage ────────────────────────────────────────────────────────
    if (nightMins > 30) {
      insights.add(AiInsight(
        title: 'Night Scrolling Detected 🌙',
        description:
        '${_fmt(nightMins)} of usage after 11 PM this week. Late-night screen time disrupts sleep cycles and weights your addiction score.',
        emoji: '🌙',
        type: InsightType.warning,
      ));
    }

    // ── 5. Streak Insight ─────────────────────────────────────────────────────
    if (streak >= 7) {
      insights.add(AiInsight(
        title: '$streak Day Streak! 🔥',
        description:
        'A full week of discipline. Your pet has never been happier. Don\'t ruin it.',
        emoji: '🏆',
        type: InsightType.positive,
      ));
    } else if (streak == 0 && today > dailyLimit) {
      insights.add(AiInsight(
        title: 'Streak Lost — Reset Tomorrow',
        description:
        'You went over your ${_fmt(dailyLimit)} limit. Stay under tomorrow to start a new streak.',
        emoji: '💔',
        type: InsightType.critical,
      ));
    } else if (streak > 0) {
      final remaining = dailyLimit - today;
      if (remaining > 0) {
        insights.add(AiInsight(
          title: 'Protect Your $streak-Day Streak 🔥',
          description:
          'You have ${_fmt(remaining)} left before hitting your limit today. Keep going.',
          emoji: '🔥',
          type: InsightType.tip,
        ));
      }
    }

    // ── 6. AI Prediction (linear regression, needs 5+ non-zero days) ─────────
    final nonZero =
    dailyTotals.where((v) => v > 0).take(7).toList();
    if (nonZero.length >= 5) {
      final n = nonZero.length;
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for (int i = 0; i < n; i++) {
        sumX += i; sumY += nonZero[i];
        sumXY += i * nonZero[i]; sumX2 += i * i;
      }
      final denom = n * sumX2 - sumX * sumX;
      if (denom != 0) {
        final slope = (n * sumXY - sumX * sumY) / denom;
        final intercept = (sumY - slope * sumX) / n;
        final predicted = (intercept + slope * n).round().clamp(0, 600);
        if (slope < -4) {
          insights.add(AiInsight(
            title: 'Downward Trend 🤖',
            description:
            'AI predicts tomorrow: ~${_fmt(predicted)}. You\'re improving. Keep it up.',
            emoji: '🤖',
            type: InsightType.positive,
          ));
        } else if (slope > 5) {
          insights.add(AiInsight(
            title: 'Rising Trend ⚠️',
            description:
            'AI predicts tomorrow: ~${_fmt(predicted)}. Usage is climbing. Time to intervene.',
            emoji: '🤖',
            type: InsightType.warning,
          ));
        }
      }
    }

    // ── 7. Top App ────────────────────────────────────────────────────────────
    if (appBreakdown.isNotEmpty) {
      final top = appBreakdown.entries
          .reduce((a, b) => a.value > b.value ? a : b);
      final totalApp =
      appBreakdown.values.fold(0, (a, b) => a + b);
      final pct = totalApp > 0
          ? (top.value / totalApp * 100).round()
          : 0;
      insights.add(AiInsight(
        title: '${top.key} = $pct% of Your Time',
        description:
        '${top.key} took ${_fmt(top.value)} this week. That\'s your biggest habit to break.',
        emoji: '🔍',
        type: pct > 60 ? InsightType.warning : InsightType.tip,
      ));
    }

    // Return max 5 insights, prioritizing critical > warning > tip > positive
    final sorted = [...insights]..sort((a, b) {
      const order = {
        InsightType.critical: 0,
        InsightType.warning: 1,
        InsightType.tip: 2,
        InsightType.positive: 3,
      };
      return order[a.type]!.compareTo(order[b.type]!);
    });
    return sorted.take(5).toList();
  }

  String _addictionDescription(
      String level, int score, int nightMins, int weekendMins) {
    switch (level) {
      case 'Low':
        return 'Score: $score/100. Your usage patterns are healthy. Your pet is thriving.';
      case 'Medium':
        return 'Score: $score/100. Some risky patterns detected. Watch your weekend and night usage.';
      case 'High':
        return 'Score: $score/100. High night usage ($nightMins min) and weekend spikes are hurting your score.';
      default:
        return 'Score: $score/100. Usage is at a concerning level. Immediate action needed to save your pet.';
    }
  }

  double _avg(List<int> v) =>
      v.isEmpty ? 0 : v.fold(0, (a, b) => a + b) / v.length;

  String _fmt(int minutes) {
    if (minutes < 60) return '${minutes}m';
    return '${minutes ~/ 60}h ${minutes % 60}m';
  }
}
