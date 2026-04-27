// test/widget_test.dart
/*

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pawprotect/widgets/usage_card.dart';
import 'package:pawprotect/utils/app_theme.dart';

void main() {
  testWidgets('UsageCard renders formatted time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: UsageCard(
            todayMinutes: 75,
            dailyLimit: 120,
            streak: 3,
            points: 50,
          ),
        ),
      ),
    );

    // 75 min = 1h 15m
    expect(find.text('1h 15m'), findsOneWidget);
    expect(find.text('3 day streak'), findsOneWidget);
    expect(find.text('50 pts'), findsOneWidget);
  });

  testWidgets('UsageCard shows limit badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: UsageCard(
            todayMinutes: 30,
            dailyLimit: 120,
            streak: 0,
            points: 0,
          ),
        ),
      ),
    );

    expect(find.text('Limit: 2h'), findsOneWidget);
  });
}
*/