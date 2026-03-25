import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/models/goal_task.dart';

void main() {
  group('GoalTask Model Tests', () {
    final now = DateTime(2025, 6, 15, 10, 30);

    Map<String, dynamic> _fullMap() => {
          'id': 1,
          'goal_id': 10,
          'title': 'Study Chapter 1',
          'description': 'Read pages 1-50',
          'estimated_hours': 2.5,
          'estimated_minutes': 150,
          'actual_minutes': 120,
          'actual_seconds': 7200,
          'started_at': now.toIso8601String(),
          'priority': 'high',
          'frequency': 'daily',
          'suggested_time': 'morning',
          'is_milestone': 1,
          'motivation_anchor': 'Stay focused!',
          'scheduled_date': now.add(const Duration(days: 1)).toIso8601String(),
          'phase_id': 5,
          'is_completed': 1,
          'completed_at': now.add(const Duration(hours: 2)).toIso8601String(),
          'created_at': now.toIso8601String(),
          'order_index': 3,
          'indent_level': 1,
          'subtasks': [],
        };

    test('round-trip serialization toMap → fromMap preserves all fields', () {
      final task = GoalTask.fromMap(_fullMap());
      final restoredMap = task.toMap();
      final restored = GoalTask.fromMap(restoredMap);

      expect(restored.id, 1);
      expect(restored.goalId, 10);
      expect(restored.title, 'Study Chapter 1');
      expect(restored.description, 'Read pages 1-50');
      expect(restored.estimatedHours, 2.5);
      expect(restored.estimatedMinutes, 150);
      expect(restored.actualMinutes, 120);
      expect(restored.actualSeconds, 7200);
      expect(restored.priority, 'high');
      expect(restored.frequency, 'daily');
      expect(restored.suggestedTime, 'morning');
      expect(restored.isMilestone, true);
      expect(restored.motivationAnchor, 'Stay focused!');
      expect(restored.isCompleted, true);
      expect(restored.order, 3);
      expect(restored.indentLevel, 1);
    });

    test('recursive subtask serialization/deserialization', () {
      final map = _fullMap();
      map['subtasks'] = [
        {
          'id': 2,
          'goal_id': 10,
          'title': 'Sub-task 1',
          'description': 'Sub description',
          'created_at': now.toIso8601String(),
          'subtasks': [],
        },
      ];

      final task = GoalTask.fromMap(map);
      expect(task.subtasks.length, 1);
      expect(task.subtasks[0].title, 'Sub-task 1');

      final restoredMap = task.toMap();
      final restored = GoalTask.fromMap(restoredMap);
      expect(restored.subtasks.length, 1);
      expect(restored.subtasks[0].title, 'Sub-task 1');
    });

    test('nested subtask depth 2-3 levels', () {
      final map = _fullMap();
      map['subtasks'] = [
        {
          'id': 2,
          'goal_id': 10,
          'title': 'Level 1',
          'description': '',
          'created_at': now.toIso8601String(),
          'subtasks': [
            {
              'id': 3,
              'goal_id': 10,
              'title': 'Level 2',
              'description': '',
              'created_at': now.toIso8601String(),
              'subtasks': [
                {
                  'id': 4,
                  'goal_id': 10,
                  'title': 'Level 3',
                  'description': '',
                  'created_at': now.toIso8601String(),
                  'subtasks': [],
                },
              ],
            },
          ],
        },
      ];

      final task = GoalTask.fromMap(map);
      expect(task.subtasks[0].title, 'Level 1');
      expect(task.subtasks[0].subtasks[0].title, 'Level 2');
      expect(task.subtasks[0].subtasks[0].subtasks[0].title, 'Level 3');
    });

    test('efficiencyScore normal case using actualSeconds', () {
      final task = GoalTask(
        id: 1,
        goalId: 1,
        title: 'Test',
        description: '',
        estimatedMinutes: 60,
        actualSeconds: 3600, // 60 minutes
        createdAt: now,
      );
      // est=60, actual=60min → 60/60*100=100
      expect(task.efficiencyScore, 100);
    });

    test('efficiencyScore with estimated hours conversion', () {
      final task = GoalTask(
        id: 1,
        goalId: 1,
        title: 'Test',
        description: '',
        estimatedHours: 1.0, // 60 minutes
        actualMinutes: 30,
        createdAt: now,
      );
      // est=60min, actual=30min → 60/30*100=200
      expect(task.efficiencyScore, 200);
    });

    test('efficiencyScore returns 0 when actualMinutes is 0', () {
      final task = GoalTask(
        id: 1,
        goalId: 1,
        title: 'Test',
        description: '',
        estimatedMinutes: 60,
        actualMinutes: 0,
        createdAt: now,
      );
      expect(task.efficiencyScore, 0);
    });

    test('efficiencyScore returns 0 when estimated is 0', () {
      final task = GoalTask(
        id: 1,
        goalId: 1,
        title: 'Test',
        description: '',
        estimatedMinutes: 0,
        actualMinutes: 30,
        createdAt: now,
      );
      expect(task.efficiencyScore, 0);
    });

    test('type coercion num → int/double from map', () {
      final map = {
        'id': 1,
        'goal_id': 10,
        'title': 'Coerce',
        'description': '',
        'estimated_hours': 2, // int, should become double
        'estimated_minutes': 120.0, // double, should become int
        'actual_minutes': 90.0,
        'actual_seconds': 5400.0,
        'created_at': now.toIso8601String(),
      };

      final task = GoalTask.fromMap(map);
      expect(task.estimatedHours, 2.0);
      expect(task.estimatedHours, isA<double>());
      expect(task.estimatedMinutes, 120);
      expect(task.estimatedMinutes, isA<int>());
    });

    test('copyWith with clearStartedAt flag', () {
      final task = GoalTask(
        id: 1,
        goalId: 1,
        title: 'Test',
        description: '',
        startedAt: now,
        createdAt: now,
      );
      expect(task.startedAt, isNotNull);

      final cleared = task.copyWith(clearStartedAt: true);
      expect(cleared.startedAt, isNull);
      expect(cleared.title, 'Test'); // other fields preserved
    });

    test('copyWith preserves and overrides values', () {
      final task = GoalTask.fromMap(_fullMap());
      final copy = task.copyWith(title: 'New Title', isCompleted: false);

      expect(copy.title, 'New Title');
      expect(copy.isCompleted, false);
      expect(copy.goalId, task.goalId); // preserved
      expect(copy.priority, task.priority); // preserved
    });

    test('fromMap handles missing optional fields with defaults', () {
      final map = {
        'id': 1,
        'goal_id': 10,
        'title': 'Minimal',
        'description': 'Desc',
        'created_at': now.toIso8601String(),
      };

      final task = GoalTask.fromMap(map);
      expect(task.priority, 'medium');
      expect(task.frequency, 'one-time');
      expect(task.suggestedTime, 'any');
      expect(task.isMilestone, false);
      expect(task.isCompleted, false);
      expect(task.order, 0);
      expect(task.indentLevel, 0);
      expect(task.subtasks, isEmpty);
    });

    test('fromMap parses DateTime strings correctly', () {
      final map = _fullMap();
      final task = GoalTask.fromMap(map);

      expect(task.startedAt, now);
      expect(task.completedAt, now.add(const Duration(hours: 2)));
      expect(task.scheduledDate, now.add(const Duration(days: 1)));
      expect(task.createdAt, now);
    });
  });
}
