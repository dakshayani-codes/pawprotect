// test/pet_logic_test.dart
//
// Unit tests for the behavioural analytics engine.
// Run with: flutter test
/*
import 'package:flutter_test/flutter_test.dart';
import 'package:pawprotect/models/pet_mood.dart';

void main() {
  group('computeAddictionScore', () {
    test('returns 0 when no usage', () {
      final score = computeAddictionScore(
        totalMinutes: 0,
        nightMinutes: 0,
        streakBroken: false,
      );
      expect(score, equals(0.0));
    });

    test('daily ratio component only — under limit', () {
      // 60 min out of 120 limit → daily ratio = 50 → 0.4 * 50 = 20
      final score = computeAddictionScore(
        totalMinutes: 60,
        nightMinutes: 0,
        streakBroken: false,
        dailyLimitMinutes: 120,
      );
      expect(score, closeTo(20.0, 0.01));
    });

    test('clamped to 100 on extreme usage', () {
      final score = computeAddictionScore(
        totalMinutes: 600,
        nightMinutes: 600,
        streakBroken: true,
        dailyLimitMinutes: 120,
      );
      expect(score, equals(100.0));
    });

    test('streak break contributes 30 pts', () {
      final withBreak = computeAddictionScore(
        totalMinutes: 0,
        nightMinutes: 0,
        streakBroken: true,
      );
      final withoutBreak = computeAddictionScore(
        totalMinutes: 0,
        nightMinutes: 0,
        streakBroken: false,
      );
      expect(withBreak - withoutBreak, closeTo(30.0, 0.01));
    });
  });

  group('moodFromScore', () {
    test('score 0 → happy', () =>
        expect(moodFromScore(0), equals(PetMood.happy)));

    test('score 10 → happy', () =>
        expect(moodFromScore(10), equals(PetMood.happy)));

    test('score 25 → neutral', () =>
        expect(moodFromScore(25), equals(PetMood.neutral)));

    test('score 50 → sad', () =>
        expect(moodFromScore(50), equals(PetMood.sad)));

    test('score 70 → sick', () =>
        expect(moodFromScore(70), equals(PetMood.sick)));

    test('score 90 → dead', () =>
        expect(moodFromScore(90), equals(PetMood.dead)));
  });

  group('PetMoodExtension', () {
    test('happy health score is 90', () =>
        expect(PetMood.happy.healthScore, equals(90)));

    test('dead health score is 0', () =>
        expect(PetMood.dead.healthScore, equals(0)));

    test('all moods have non-empty labels', () {
      for (final m in PetMood.values) {
        expect(m.label, isNotEmpty);
      }
    });

    test('all moods have animation asset paths', () {
      for (final m in PetMood.values) {
        expect(m.animationAsset, contains('.json'));
      }
    });
  });
}
*/