// lib/views/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/pet_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _limitValue;

  @override
  void initState() {
    super.initState();
    _limitValue = context.read<PetViewModel>().dailyLimit.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final petVM = context.watch<PetViewModel>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text('SETTINGS',
            style: GoogleFonts.vt323(fontSize: 24, letterSpacing: 4)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Account Card ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  // User info row
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: const BoxDecoration(
                            color: Colors.black, shape: BoxShape.circle),
                        child: const Center(
                            child: Text('🐾',
                                style: TextStyle(fontSize: 22))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(authVM.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            if (authVM.email.isNotEmpty)
                              Text(authVM.email,
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () async => await authVM.signOut(),
                        child: const Text('SIGN OUT',
                            style: TextStyle(
                                color: Color(0xFFFF006E),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 14),

                  // Stats grid
                  Row(children: [
                    _StatBox(
                      label: 'TODAY',
                      value: _formatMins(petVM.todayUsageMinutes),
                      color: petVM.moodColor,
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'STREAK',
                      value: '${petVM.streak}🔥',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'BEST',
                      value: '${petVM.bestStreak}🏆',
                      color: const Color(0xFFFFD700),
                    ),
                  ]),

                  const SizedBox(height: 10),

                  // Addiction score mini
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _addictionColor(
                          petVM.analytics.addictionLevel)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _addictionColor(
                            petVM.analytics.addictionLevel)
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Addiction Level',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                        Row(children: [
                          Text(
                            petVM.analytics.addictionLevel,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _addictionColor(
                                    petVM.analytics.addictionLevel)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${petVM.addictionScore.round()}/100)',
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 12),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Daily Limit ───────────────────────────────────────────────
            const _Label('DAILY USAGE LIMIT'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('30m',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      Text(
                        '${_limitValue.toInt() ~/ 60}H ${_limitValue.toInt() % 60}M',
                        style: GoogleFonts.vt323(fontSize: 32),
                      ),
                      const Text('5h',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: _limitValue,
                    min: 30, max: 300, divisions: 9,
                    activeColor: Colors.black,
                    inactiveColor: Colors.black12,
                    onChanged: (v) =>
                        setState(() => _limitValue = v),
                    onChangeEnd: (v) =>
                        petVM.updateDailyLimit(v.toInt()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Data ──────────────────────────────────────────────────────
            const _Label('DATA'),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.download_rounded,
              label: 'Load Demo Data',
              subtitle: '15 days of realistic usage history',
              onTap: () async {
                await petVM.injectDemoData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Demo data loaded! Pull to refresh.'),
                        backgroundColor: Colors.black),
                  );
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.delete_outline,
              label: 'Reset All Data',
              subtitle: 'Wipe usage history and streaks',
              isDestructive: true,
              onTap: () => _confirmReset(context, petVM),
            ),

            const SizedBox(height: 28),

            // ── About ─────────────────────────────────────────────────────
            const _Label('ABOUT'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: const [
                  _AboutRow('App',           'PawProtect v2.0'),
                  _AboutRow('Architecture',  'MVVM + Provider'),
                  _AboutRow('Local DB',      'SQLite + sync_queue'),
                  _AboutRow('Cloud',         'Firebase Auth + Firestore'),
                  _AboutRow('AI Engine',     'On-device behavioral analytics'),
                  _AboutRow('Tracking',      'AppLifecycleState monitoring'),
                  _AboutRow('Sync',          'Offline-first eventual consistency'),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, PetViewModel petVM) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('RESET DATA?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            'This will delete all usage history, streaks, and insights.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              await petVM.resetStats();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('RESET',
                style: TextStyle(color: Color(0xFFFF006E))),
          ),
        ],
      ),
    );
  }

  String _formatMins(int m) {
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h${m % 60 > 0 ? '${m % 60}m' : ''}';
  }

  Color _addictionColor(String level) {
    switch (level) {
      case 'Low':      return const Color(0xFF43D97B);
      case 'Medium':   return const Color(0xFFFFD93D);
      case 'High':     return const Color(0xFFFF9A3C);
      default:         return const Color(0xFFFF006E);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                  letterSpacing: 1)),
        ],
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          color: Colors.grey,
          letterSpacing: 2,
          fontWeight: FontWeight.bold));
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isDestructive;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDestructive
              ? const Color(0xFFFF006E).withOpacity(0.3)
              : Colors.black12,
        ),
      ),
      child: Row(children: [
        Icon(icon,
            size: 20,
            color: isDestructive ? const Color(0xFFFF006E) : Colors.black),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDestructive
                          ? const Color(0xFFFF006E)
                          : Colors.black)),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.grey[500], fontSize: 12)),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: Colors.grey[300], size: 20),
      ]),
    ),
  );
}

class _AboutRow extends StatelessWidget {
  final String key_;
  final String value;
  const _AboutRow(this.key_, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key_,
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    ),
  );
}
