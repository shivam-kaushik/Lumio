import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumio/core/services/gamification_service.dart';
import 'package:lumio/data/models/goal_task.dart';

void main() {
  group('GamificationService Tests', () {
    late GamificationService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = GamificationService();
    });

    group('Level calculation via addXP', () {
      test('XP 0 → level 1 (initial state)', () async {
        final stats = await service.loadStats();
        expect(stats.xp, 0);
        expect(stats.level, 1);
      });

      test('XP 99 → level 1 (no level up)', () async {
        final result = await service.addXP(99);
        expect(result.stats.xp, 99);
        expect(result.stats.level, 1);
        expect(result.didLevelUp, false);
      });

      test('XP 100 → level 2 (level up)', () async {
        final result = await service.addXP(100);
        expect(result.stats.xp, 100);
        expect(result.stats.level, 2);
        expect(result.didLevelUp, true);
      });

      test('XP 250 → level 3', () async {
        final result = await service.addXP(250);
        expect(result.stats.xp, 250);
        expect(result.stats.level, 3);
        expect(result.didLevelUp, true);
      });

      test('addXP returns correct level-up status on second add', () async {
        await service.addXP(50); // level 1
        final result = await service.addXP(60); // total 110 → level 2
        expect(result.stats.xp, 110);
        expect(result.stats.level, 2);
        expect(result.didLevelUp, true);
      });
    });

    group('calculateStreak', () {
      GoalTask _makeTask(DateTime completedAt) {
        return GoalTask(
          id: completedAt.millisecondsSinceEpoch,
          goalId: 1,
          title: 'Task',
          description: '',
          isCompleted: true,
          completedAt: completedAt,
          createdAt: completedAt,
        );
      }

      test('empty task list → streak 0', () async {
        final streak = await service.calculateStreak([]);
        expect(streak, 0);
      });

      test('completion today → streak 1', () async {
        final today = DateTime.now();
        final streak = await service.calculateStreak([_makeTask(today)]);
        expect(streak, 1);
      });

      test('completion yesterday → streak 1', () async {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final streak = await service.calculateStreak([_makeTask(yesterday)]);
        expect(streak, 1);
      });

      test('consecutive days → correct count', () async {
        final now = DateTime.now();
        final tasks = [
          _makeTask(now),
          _makeTask(now.subtract(const Duration(days: 1))),
          _makeTask(now.subtract(const Duration(days: 2))),
        ];
        final streak = await service.calculateStreak(tasks);
        expect(streak, 3);
      });

      test('gap of 2+ days → streak 0', () async {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        final streak = await service.calculateStreak([_makeTask(threeDaysAgo)]);
        expect(streak, 0);
      });

      test('multiple completions same day counted once', () async {
        final now = DateTime.now();
        final tasks = [
          _makeTask(now),
          _makeTask(now.add(const Duration(hours: 1))),
          _makeTask(now.add(const Duration(hours: 2))),
          _makeTask(now.subtract(const Duration(days: 1))),
        ];
        final streak = await service.calculateStreak(tasks);
        expect(streak, 2); // today + yesterday = 2 unique days
      });
    });

    group('loadStats / saveStats persistence', () {
      test('loadStats returns defaults initially', () async {
        final stats = await service.loadStats();
        expect(stats.xp, 0);
        expect(stats.level, 1);
        expect(stats.streak, 0);
      });

      test('addXP persists and loadStats retrieves', () async {
        await service.addXP(150);
        final stats = await service.loadStats();
        expect(stats.xp, 150);
        expect(stats.level, 2);
      });
    });
  });
}
