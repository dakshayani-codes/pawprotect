// lib/views/home/home_screen.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../viewmodels/pet_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/models.dart';
import '../analytics/analytics_screen.dart';
import '../settings/settings_screen.dart';
import 'animated_pet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime? _sessionStartTime;
  String _currentActiveApp = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PetViewModel>().loadTodayData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      final minutes = (duration.inSeconds / 60).ceil();
      if (minutes > 0 && mounted) {
        context.read<PetViewModel>().addUsage(_currentActiveApp, minutes);
      }
      _sessionStartTime = null;
      _currentActiveApp = '';
    }
  }

  Future<void> _launchMonitoredApp(String url, String name) async {
    _sessionStartTime = DateTime.now();
    _currentActiveApp = name;
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _sessionStartTime = null;
      _currentActiveApp = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final petVM = context.watch<PetViewModel>();
    final authVM = context.watch<AuthViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: petVM.isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Colors.black))
            : RefreshIndicator(
          color: Colors.black,
          onRefresh: petVM.loadTodayData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // ── Header ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'hey, ${authVM.displayName.toLowerCase()} 👋',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                        ),
                        Text(
                          'PAWPROTECT',
                          style: GoogleFonts.vt323(
                              fontSize: 28,
                              letterSpacing: 4,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _NavIcon(
                          icon: Icons.bar_chart_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                const AnalyticsScreen()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _NavIcon(
                          icon: Icons.settings_outlined,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                const SettingsScreen()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Usage Card ───────────────────────────
                _UsageCard(petVM: petVM),

                const SizedBox(height: 24),

                // ── Pet ──────────────────────────────────
                Center(
                  child: AnimatedPet(
                    imagePath: petVM.imagePath,
                    mood: petVM.currentMood,
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: Text(
                    petVM.moodStatus.toUpperCase(),
                    style: GoogleFonts.vt323(
                      fontSize: 22,
                      color: petVM.moodColor,
                      letterSpacing: 1,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 28),

                // ── App Launch Buttons ───────────────────
                _SectionLabel('LAUNCH & TRACK'),
                const SizedBox(height: 12),
                _AppButton(
                  name: 'INSTAGRAM',
                  color: const Color(0xFFFF006E),
                  onTap: () => _launchMonitoredApp(
                      'https://www.instagram.com', 'Instagram'),
                ),
                const SizedBox(height: 10),
                _AppButton(
                  name: 'YOUTUBE',
                  color: const Color(0xFFFF5C00),
                  onTap: () => _launchMonitoredApp(
                      'https://www.youtube.com', 'YouTube'),
                ),
                const SizedBox(height: 10),
                _AppButton(
                  name: 'TWITTER / X',
                  color: Colors.black,
                  onTap: () => _launchMonitoredApp(
                      'https://www.x.com', 'Twitter'),
                ),

                const SizedBox(height: 28),

                // ── App Breakdown ────────────────────────
                if (petVM.appUsageBreakdown.isNotEmpty) ...[
                  _SectionLabel('TODAY\'S APP BREAKDOWN'),
                  const SizedBox(height: 12),
                  _AppBreakdownCard(
                      breakdown: petVM.appUsageBreakdown),
                  const SizedBox(height: 28),
                ],

                // ── AI Insights ──────────────────────────
                if (petVM.insights.isNotEmpty) ...[
                  _SectionLabel('AI INSIGHTS 🤖'),
                  const SizedBox(height: 12),
                  ...petVM.insights
                      .map((i) => _InsightCard(insight: i)),
                  const SizedBox(height: 28),
                ],

                // ── Dev Tools (debug builds only) ─────────
                if (kDebugMode) ...[
                  const Divider(thickness: 1, color: Colors.black12),
                  _SectionLabel('DEV TOOLS'),
                  const SizedBox(height: 8),
                  Slider(
                    value: petVM.todayUsageMinutes
                        .toDouble()
                        .clamp(0, 300),
                    min: 0,
                    max: 300,
                    divisions: 10,
                    activeColor: Colors.black,
                    inactiveColor: Colors.black12,
                    onChanged: (v) =>
                        petVM.debugSetUsage(v.toInt()),
                  ),
                  Center(
                    child: Text(
                      'SIMULATING: ${petVM.todayUsageMinutes} MIN',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Reusable Widgets ─────────────────────────────────────────────────────────

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 22),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
        fontSize: 11,
        color: Colors.grey,
        letterSpacing: 2,
        fontWeight: FontWeight.bold),
  );
}

class _UsageCard extends StatelessWidget {
  final PetViewModel petVM;
  const _UsageCard({required this.petVM});

  @override
  Widget build(BuildContext context) {
    final isOver = petVM.todayUsageMinutes > petVM.dailyLimit;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOver ? const Color(0xFFFFF0F5) : Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOver
              ? const Color(0xFFFF006E).withOpacity(0.3)
              : Colors.black12,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('USED TODAY',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(
                    '${petVM.todayUsageMinutes ~/ 60}H ${petVM.todayUsageMinutes % 60}M',
                    style: GoogleFonts.vt323(
                        fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 18),
                      Text(' ${petVM.streak} DAY STREAK',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LIMIT: ${petVM.dailyLimit ~/ 60}H ${petVM.dailyLimit % 60}M',
                    style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                        letterSpacing: 1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: petVM.progressToLimit),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: Colors.black12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? const Color(0xFFFF006E) : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppButton extends StatelessWidget {
  final String name;
  final Color color;
  final VoidCallback onTap;
  const _AppButton(
      {required this.name, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100)),
        elevation: 0,
      ),
      child: Text(name,
          style: GoogleFonts.vt323(fontSize: 20, letterSpacing: 2)),
    ),
  );
}

class _AppBreakdownCard extends StatelessWidget {
  final Map<String, int> breakdown;
  const _AppBreakdownCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: breakdown.entries.map((e) {
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key.toUpperCase(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${e.value} MIN',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.black12,
                    valueColor:
                    const AlwaysStoppedAnimation(Colors.black),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final AiInsight insight;
  const _InsightCard({required this.insight});

  Color get _bgColor {
    switch (insight.type) {
      case InsightType.positive:
        return const Color(0xFFF0FFF5);
      case InsightType.warning:
        return const Color(0xFFFFFBF0);
      case InsightType.critical:
        return const Color(0xFFFFF0F5);
      case InsightType.tip:
        return const Color(0xFFF0F5FF);
    }
  }

  Color get _borderColor {
    switch (insight.type) {
      case InsightType.positive:
        return const Color(0xFF43D97B);
      case InsightType.warning:
        return const Color(0xFFFFB347);
      case InsightType.critical:
        return const Color(0xFFFF006E);
      case InsightType.tip:
        return const Color(0xFF6C8EFF);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _bgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _borderColor.withOpacity(0.4)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(insight.emoji,
            style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(insight.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(insight.description,
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}
