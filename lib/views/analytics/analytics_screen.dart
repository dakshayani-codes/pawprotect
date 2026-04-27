// lib/views/analytics/analytics_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/remote/firebase_service.dart';
import '../../models/models.dart';
import '../../viewmodels/pet_viewmodel.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _leaderboard = [];
  bool _lbLoading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    final lb = await FirebaseService.instance.fetchLeaderboard();
    if (mounted) setState(() { _leaderboard = lb; _lbLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final petVM = context.watch<PetViewModel>();
    final data = petVM.analytics;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text('ANALYTICS',
            style: GoogleFonts.vt323(fontSize: 24, letterSpacing: 4)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.black,
          indicatorWeight: 2,
          labelStyle: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          tabs: const [
            Tab(text: 'USAGE'),
            Tab(text: 'APPS'),
            Tab(text: 'HEATMAP'),
            Tab(text: 'LEADERS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _UsageTab(data: data, dailyLimit: petVM.dailyLimit),
          _AppsTab(breakdown: data.appBreakdown),
          _HeatmapTab(data: data),
          _LeaderboardTab(
              leaderboard: _leaderboard, isLoading: _lbLoading),
        ],
      ),
    );
  }
}

// ── Usage Tab ─────────────────────────────────────────────────────────────────

class _UsageTab extends StatelessWidget {
  final AnalyticsData data;
  final int dailyLimit;
  const _UsageTab({required this.data, required this.dailyLimit});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Addiction Score Card ────────────────────────────────────────
          _AddictionCard(
            score: data.addictionScore,
            level: data.addictionLevel,
            nightMins: data.nightMins,
            weekendMins: data.weekendMins,
          ),

          const SizedBox(height: 16),

          // ── Improvement + Trend ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'IMPROVEMENT',
                  value: data.improvementPct >= 0
                      ? '+${data.improvementPct.round()}%'
                      : '${data.improvementPct.round()}%',
                  color: data.improvementPct >= 0
                      ? const Color(0xFF43D97B)
                      : const Color(0xFFFF006E),
                  subtitle: data.improvementPct >= 0
                      ? 'Reduced usage'
                      : 'Increased usage',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'TREND',
                  value: data.trendDirection, // ↓ ↑ →
                  color: data.trendDirection == '↓'
                      ? const Color(0xFF43D97B)
                      : data.trendDirection == '↑'
                      ? const Color(0xFFFF006E)
                      : const Color(0xFFFFD93D),
                  subtitle: 'Usage direction',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (data.weeklyData.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(children: [
                const Text('📊', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text('No data yet.',
                    style: TextStyle(color: Colors.grey[500])),
                Text('Launch an app from the home screen to start tracking.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    textAlign: TextAlign.center),
              ]),
            )
          else ...[
            // Summary stat pills
            Builder(builder: (context) {
              final totals = data.weeklyData
                  .map((d) => (d['total_minutes'] as num).toInt())
                  .toList();
              final avg = totals.fold(0, (a, b) => a + b) ~/ totals.length;
              final best = totals.reduce((a, b) => a < b ? a : b);
              final worst = totals.reduce((a, b) => a > b ? a : b);
              return Row(children: [
                _StatPill('AVG/DAY', '${avg}m', Colors.black),
                const SizedBox(width: 8),
                _StatPill('BEST', '${best}m', const Color(0xFF43D97B)),
                const SizedBox(width: 8),
                _StatPill('WORST', '${worst}m', const Color(0xFFFF006E)),
              ]);
            }),

            const SizedBox(height: 20),

            const _SectionLabel('LAST 7 DAYS'),
            const SizedBox(height: 12),
            _BarChart(weeklyData: data.weeklyData, dailyLimit: dailyLimit),

            const SizedBox(height: 8),
            Row(children: [
              _Legend(color: const Color(0xFF43D97B), label: 'Under limit'),
              const SizedBox(width: 12),
              _Legend(color: const Color(0xFFFFB347), label: 'Getting close'),
              const SizedBox(width: 12),
              _Legend(color: const Color(0xFFFF006E), label: 'Over limit'),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Addiction Score Card ──────────────────────────────────────────────────────

class _AddictionCard extends StatelessWidget {
  final double score;
  final String level;
  final int nightMins;
  final int weekendMins;
  const _AddictionCard({
    required this.score,
    required this.level,
    required this.nightMins,
    required this.weekendMins,
  });

  Color get _color {
    switch (level) {
      case 'Low':      return const Color(0xFF43D97B);
      case 'Medium':   return const Color(0xFFFFD93D);
      case 'High':     return const Color(0xFFFF9A3C);
      default:         return const Color(0xFFFF006E);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ADDICTION SCORE',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(level.toUpperCase(),
                    style: TextStyle(
                        color: _color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${score.round()}',
                  style: GoogleFonts.vt323(
                      fontSize: 52,
                      color: _color,
                      fontWeight: FontWeight.bold)),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text('/100',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 16)),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: score / 100),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: _color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(_color),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            _ScoreContrib(label: '🌙 Night', value: '${nightMins}m',
                sub: '× 1.5 weight'),
            const SizedBox(width: 16),
            _ScoreContrib(label: '📅 Weekend', value: '${weekendMins}m',
                sub: '× 1.3 weight'),
          ]),
          const SizedBox(height: 4),
          Text(
            'Score = (weekend × 1.3) + (night × 1.5) + (streak breaks × 2)',
            style: TextStyle(
                color: Colors.grey[400], fontSize: 10, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _ScoreContrib extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  const _ScoreContrib({required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      Text(value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      Text(sub,
          style: TextStyle(color: Colors.grey[400], fontSize: 10)),
    ],
  );
}

// ── Metric Cards ──────────────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String subtitle;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 9,
          ),
        ),
      ],
    ),
  );
}


// ── Bar Chart ─────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyData;
  final int dailyLimit;
  const _BarChart({required this.weeklyData, required this.dailyLimit});

  @override
  Widget build(BuildContext context) {
    final maxY = weeklyData
        .map((d) => (d['total_minutes'] as num).toDouble())
        .fold(0.0, (a, b) => a > b ? a : b) *
        1.2;

    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        maxY: maxY > 0 ? maxY : 300,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                if (v.toInt() >= weeklyData.length) return const Text('');
                final date = weeklyData[v.toInt()]['date'] as String;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(date.split('-')[2],
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, _) => Text('${v.toInt()}m',
                  style: const TextStyle(fontSize: 9, color: Colors.grey)),
            ),
          ),
        ),
        gridData: FlGridData(
          drawHorizontalLine: true,
          getDrawingHorizontalLine: (_) =>
          const FlLine(color: Colors.black12, strokeWidth: 0.5),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: [
          HorizontalLine(
            y: dailyLimit.toDouble(),
            color: Colors.black38,
            strokeWidth: 1,
            dashArray: [6, 4],
            label: HorizontalLineLabel(
              show: true,
              labelResolver: (_) => 'LIMIT',
              style: const TextStyle(
                  fontSize: 9, color: Colors.black54, letterSpacing: 1),
            ),
          ),
        ]),
        barGroups: weeklyData.asMap().entries.map((e) {
          final mins = (e.value['total_minutes'] as num).toDouble();
          final isOver = mins > dailyLimit;
          return BarChartGroupData(x: e.key, barRods: [
            BarChartRodData(
              toY: mins,
              color: isOver
                  ? const Color(0xFFFF006E)
                  : mins > dailyLimit * 0.75
                  ? const Color(0xFFFFB347)
                  : const Color(0xFF43D97B),
              width: 18,
              borderRadius: BorderRadius.circular(6),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY > 0 ? maxY : 300,
                color: Colors.black.withOpacity(0.03),
              ),
            ),
          ]);
        }).toList(),
      )),
    );
  }
}

// ── Apps Tab ──────────────────────────────────────────────────────────────────

class _AppsTab extends StatelessWidget {
  final Map<String, int> breakdown;
  const _AppsTab({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return Center(
          child: Text('No app data this week.',
              style: TextStyle(color: Colors.grey[500])));
    }
    final total = breakdown.values.fold(0, (a, b) => a + b);
    final colors = [
      const Color(0xFFFF006E), const Color(0xFFFF5C00),
      Colors.black, const Color(0xFF6C8EFF), const Color(0xFF43D97B),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('7-DAY APP BREAKDOWN'),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 50,
              sections: breakdown.entries.toList().asMap().entries.map((e) {
                final pct = e.value.value / total * 100;
                return PieChartSectionData(
                  value: e.value.value.toDouble(),
                  title: '${pct.round()}%',
                  color: colors[e.key % colors.length],
                  radius: 60,
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                );
              }).toList(),
            )),
          ),
          const SizedBox(height: 20),
          ...breakdown.entries.toList().asMap().entries.map((e) {
            final pct = e.value.value / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                              color: colors[e.key % colors.length],
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(e.value.key.toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                      Text('${e.value.value} min',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: Colors.black12,
                      valueColor: AlwaysStoppedAnimation(
                          colors[e.key % colors.length]),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Heatmap Tab ───────────────────────────────────────────────────────────────

class _HeatmapTab extends StatelessWidget {
  final AnalyticsData data;
  const _HeatmapTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final heatmap = data.heatmap;

    if (heatmap.isEmpty || heatmap.values.every((v) => v == 0)) {
      return Center(
          child: Text('No heatmap data yet.',
              style: TextStyle(color: Colors.grey[500])));
    }

    final maxVal = heatmap.values.fold(0, (a, b) => a > b ? a : b);

    final timeSlots = [
      {'label': '🌅 Morning', 'key': 'Morning', 'time': '5am – 12pm',
        'color': const Color(0xFFFFD93D)},
      {'label': '☀️ Afternoon', 'key': 'Afternoon', 'time': '12pm – 5pm',
        'color': const Color(0xFFFF5C00)},
      {'label': '🌆 Evening', 'key': 'Evening', 'time': '5pm – 11pm',
        'color': const Color(0xFFFF006E)},
      {'label': '🌙 Night', 'key': 'Night', 'time': '11pm – 5am',
        'color': const Color(0xFF6C8EFF)},
    ];

    final total = heatmap.values.fold(0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('WHEN DO YOU SCROLL?'),
          const SizedBox(height: 4),
          Text('Last 7 days — which hours you use most',
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          const SizedBox(height: 20),

          ...timeSlots.map((slot) {
            final mins = heatmap[slot['key'] as String] ?? 0;
            final pct = maxVal > 0 ? mins / maxVal : 0.0;
            final totalPct =
            total > 0 ? (mins / total * 100).round() : 0;
            final color = slot['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(mins == maxVal ? 0.12 : 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: color.withOpacity(
                        mins == maxVal ? 0.4 : 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(slot['label'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          Text(slot['time'] as String,
                              style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 11)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${mins}m',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: color)),
                          Text('$totalPct% of total',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: pct),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (_, v, __) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: color.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ),
                  if (mins == maxVal)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('⚠️ Peak usage time',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          // Night usage warning
          if ((heatmap['Night'] ?? 0) > 30)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFF006E).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Text('🌙', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Night usage (${heatmap['Night']}m) contributes 1.5× to your addiction score.',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFFF006E)),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

// ── Leaderboard Tab ───────────────────────────────────────────────────────────

class _LeaderboardTab extends StatelessWidget {
  final List<Map<String, dynamic>> leaderboard;
  final bool isLoading;
  const _LeaderboardTab(
      {required this.leaderboard, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.black));
    }
    if (leaderboard.isEmpty) {
      return Center(
          child: Text('No leaderboard data yet.',
              style: TextStyle(color: Colors.grey[500])));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: leaderboard.length,
      itemBuilder: (ctx, i) {
        final entry = leaderboard[i];
        final medals = ['🥇', '🥈', '🥉'];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: i == 0
                ? const Color(0xFFFFF9E6)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: i == 0
                    ? const Color(0xFFFFD700).withOpacity(0.5)
                    : Colors.black12),
          ),
          child: Row(children: [
            Text(i < 3 ? medals[i] : '${i + 1}.',
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Text(entry['name'] ?? 'User',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Row(children: [
              const Icon(Icons.local_fire_department,
                  color: Colors.orange, size: 16),
              const SizedBox(width: 4),
              Text('${entry['streak']} days',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ]),
        );
      },
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
          letterSpacing: 2,
          fontWeight: FontWeight.bold));
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 9, color: Colors.grey, letterSpacing: 1)),
      ]),
    ),
  );
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label,
        style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}
