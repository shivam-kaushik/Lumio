// Basic Unit Tests for Lumio Core Functionalities
// Run this file using: flutter test tests/lumio_tests.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:lumio/presentation/providers/growth_provider.dart';
import 'package:lumio/presentation/providers/reminder_provider.dart';
import 'package:lumio/data/repositories/firestore_growth_repository.dart';
import 'package:lumio/data/repositories/firestore_reminder_repository.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:lumio/data/models/reminder.dart';
import 'package:lumio/data/models/goal_phase.dart';
import 'package:lumio/data/models/goal_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ==================== Mocks & Fakes ====================

// Fake Growth Repository (In-Memory)
class FakeGrowthRepository extends Fake implements FirestoreGrowthRepository {
  final List<Goal> _goals = [];
  final Map<int, List<GoalTask>> _tasks = {};
  
  // Goals
  @override
  Future<int> createGoal(String name, {DateTime? targetDeadline, double? hoursPerDay, int? totalEstimatedHours, GoalSettings? settings}) async {
    final id = _goals.length + 1;
    _goals.add(Goal(
      id: id,
      name: name,
      createdAt: DateTime.now(),
      targetDeadline: targetDeadline,
      settings: settings,
    ));
    return id;
  }

  @override
  Future<List<Goal>> getGoals() async => List.from(_goals);

  // Tasks
  @override
  Future<List<GoalTask>> getTasksForGoal(int goalId) async {
    return _tasks[goalId] ?? [];
  }
  
  @override
  Future<List<GoalPhase>> getPhasesForGoal(int goalId) async {
    return []; // Return empty list to avoid null errors
  }

  @override
  Future<int> createTask(GoalTask task) async {
    // Simulate ID generation
    final id = (_tasks[task.goalId]?.length ?? 0) + 1000 + task.goalId; // Simple ID logic
    final key = task.goalId;
    if (!_tasks.containsKey(key)) _tasks[key] = [];
    
    // Create copy with new ID
    final newTask = GoalTask(
      id: id,
      goalId: task.goalId,
      title: task.title,
      description: task.description,
      estimatedHours: task.estimatedHours,
      priority: task.priority,
      frequency: task.frequency,
      isCompleted: task.isCompleted,
      createdAt: DateTime.now(), isMilestone: false,
    );
    
    _tasks[key]!.add(newTask);
    return id;
  }
  
  @override
  Future<int> completeTask(int taskId) async {
    // Find task and mark complete
    for (var list in _tasks.values) {
      for (var i = 0; i < list.length; i++) {
        if (list[i].id == taskId) {
           // Replace with completed version
           /* NOTE: In real app this updates Firestore. 
              Here we just update the in-memory object logic would go here.
              For unit testing Provider state, Provider often calls reload...
           */
           return taskId;
        }
      }
    }
    return taskId;
  }
}

// Fake Reminder Repository (In-Memory)
class FakeReminderRepository extends Fake implements FirestoreReminderRepository {
  final List<Reminder> _reminders = [];

  @override
  Future<String> createReminder(Reminder reminder) async {
    _reminders.add(reminder);
    return reminder.id;
  }

  @override
  Future<List<Reminder>> getAllReminders() async => List.from(_reminders);

  @override
  Future<List<Reminder>> getActiveReminders() async => _reminders.where((r) => r.enabled).toList();
  
  @override
  Future<int> updateReminder(Reminder reminder) async {
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index != -1) {
      _reminders[index] = reminder;
    }
    return 1;
  }
  
  @override
  Future<int> toggleReminder(String id, bool enabled) async {
     final index = _reminders.indexWhere((r) => r.id == id);
     if (index != -1) {
       // In a real fake we would update the object, but calling loadReminders relies on the repo returning fresh data
       // So we need to update our internal list
       final old = _reminders[index];
       _reminders[index] = Reminder(
          id: old.id,
          text: old.text,
          timeAt: old.timeAt,
          enabled: enabled,
          repeatOnDays: old.repeatOnDays,
          priority: old.priority,
          category: old.category
       );
     }
     return 1;
  }
  
  @override
  Future<Map<String, dynamic>> getStatistics() async {
      return {
          'totalReminders': _reminders.length,
          'activeReminders': _reminders.where((r) => r.enabled).length,
      };
  }
}

// ==================== Tests ====================

void main() {
  // Setup SharedPreferences mock (needed for some providers)
  SharedPreferences.setMockInitialValues({});

  group('GrowthProvider Tests', () {
    late GrowthProvider provider;
    late FakeGrowthRepository repository;

    setUp(() async {
      repository = FakeGrowthRepository();
      provider = GrowthProvider(repository: repository);
      // Don't call loadGrowthData here as it's async and we want to test steps
    });

    test('Initial state should be empty', () {
      expect(provider.goals, isEmpty);
      expect(provider.tasksByGoal, isEmpty);
    });

    test('Create Goal should add to list', () async {
      await provider.createGoal('Learn Flutter');
      expect(provider.goals.length, 1);
      expect(provider.goals.first.name, 'Learn Flutter');
    });

    test('Create Task should add to tasksByGoal', () async {
      // 1. Create Goal
      final goalId = await provider.createGoal('Test Goal');
      
      // 2. Create Task
      final task = GoalTask(
        id: 0, // Temp
        goalId: goalId,
        title: 'Unit Test Task',
        isMilestone: false, description: '',
        createdAt: DateTime.now(),
      );
      
      await provider.createTask(task);
      
      // 3. Verify
      final tasks = provider.getTasksForGoal(goalId);
      expect(tasks.length, 1);
      expect(tasks.first.title, 'Unit Test Task');
    });
  });

  group('ReminderProvider Tests', () {
    late ReminderProvider provider;
    late FakeReminderRepository repository;

    setUp(() {
      repository = FakeReminderRepository();
      provider = ReminderProvider(reminderRepository: repository);
    });

    test('Create Reminder adds to list', () async {
      final reminder = Reminder(
        id: '1',
        text: 'Buy Milk',
        timeAt: DateTime.now(),
        enabled: true,
      );
      
      await provider.createReminder(reminder);
      expect(provider.reminders.length, 1);
      expect(provider.reminders.first.text, 'Buy Milk');
    });

    test('Toggle Reminder updates enabled state', () async {
      // 1. Add
       final reminder = Reminder(
        id: '2',
        text: 'Toggle Me',
        enabled: true,
      );
      await provider.createReminder(reminder);
      
      // 2. Toggle Off
      await provider.toggleReminder(reminder.id, false); // Toggles to false
      
      // 3. Verify
      final toggled = provider.reminders.first;
      expect(toggled.enabled, false);
    });
  });
}
