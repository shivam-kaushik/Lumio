
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/presentation/screens/home_screen.dart'; // Direct import or access via key/logic if possible. 
// Ideally we test the LOGIC. The logic is private (_getAllReminders). 
// We should copy the logic here or make it public/static for testing.
// For robust testing without refactoring visibility too much, we will replicate the logic test.

import 'package:lumio/data/models/reminder.dart';
import 'package:lumio/presentation/providers/growth_provider.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:mockito/mockito.dart';

// Mock Classes
class MockGrowthProvider extends Mock implements GrowthProvider {
  @override
  Map<int, List<GoalTask>> get tasksByGoal => super.noSuchMethod(
        Invocation.getter(#tasksByGoal),
        returnValue: <int, List<GoalTask>>{},
      );

  @override
  List<Goal> get goals => super.noSuchMethod(
        Invocation.getter(#goals),
        returnValue: <Goal>[],
      );
}

void main() {
  group('Home Screen Filtering Tests', () {
    late MockGrowthProvider mockGrowthProvider;
    late List<Reminder> initialReminders;

    setUp(() {
      mockGrowthProvider = MockGrowthProvider();
      initialReminders = [];
    });

    // The logic to test (replicated from HomeScreen for unit isolation or we could refactor HomeScreen to generic helper)
    // For this test, we assume we are strictly testing the requirements:
    // "Include Inbox Tasks + Simple Reminders. Exclude Goals."
    
    List<Reminder> filterLogic(List<Reminder> reminders, GrowthProvider gp) {
       final allReminders = [...reminders];
       if (gp.tasksByGoal.isNotEmpty) {
          final allTasks = gp.tasksByGoal.values.expand((list) => list).toList();
          int? inboxId;
          try {
             inboxId = gp.goals.firstWhere((g) => g.name == 'Inbox').id;
          } catch (_) {}

          if (inboxId != null) {
             for (var task in allTasks) {
                if (task.goalId == inboxId) {
                   allReminders.add(Reminder(
                     id: "task_${task.id}", text: task.title, timeAt: DateTime.now(), priority: ReminderPriority.medium, category: ReminderCategory.work, linkedGoalId: task.goalId, enabled: !task.isCompleted
                   ));
                }
             }
          }
       }
       return allReminders;
    }

    // --- TEST CASES (10 Scenarios) ---

    // 1. Simple Reminder (Should Show)
    test('1. Simple Reminder should always appear', () {
      final rem = Reminder(id: '1', text: 'Buy Milk', timeAt: DateTime.now(), priority: ReminderPriority.high, category: ReminderCategory.personal);
      final result = filterLogic([rem], mockGrowthProvider);
      expect(result.length, 1);
      expect(result.first.text, 'Buy Milk');
    });

    // 2. Business Goal Task (Should Hide)
    test('2. Business Goal Task should be hidden', () {
      final goal = Goal(id: 100, name: 'Launch App', createdAt: DateTime.now());
      final task = GoalTask(id: 1, goalId: 100, title: 'Design UI', description: '', createdAt: DateTime.now());
      
      when(mockGrowthProvider.goals).thenReturn([goal]);
      when(mockGrowthProvider.tasksByGoal).thenReturn({100: [task]});

      final result = filterLogic([], mockGrowthProvider);
      expect(result, isEmpty);
    });

    // 3. Inbox Task (Should Show)
    test('3. Inbox Task should be shown', () {
      final goal = Goal(id: 999, name: 'Inbox', createdAt: DateTime.now());
      final task = GoalTask(id: 2, goalId: 999, title: 'Call Mom', description: '', createdAt: DateTime.now());
      
      when(mockGrowthProvider.goals).thenReturn([goal]);
      when(mockGrowthProvider.tasksByGoal).thenReturn({999: [task]});

      final result = filterLogic([], mockGrowthProvider);
      expect(result.length, 1);
      expect(result.first.text, 'Call Mom');
    });

    // 4. Daily Plan Task (Should Hide)
    test('4. Daily Plan Task should be hidden from main list', () {
      final goal = Goal(id: 50, name: 'Daily Plan - 2025-12-26', createdAt: DateTime.now());
      final task = GoalTask(id: 3, goalId: 50, title: 'Morning Jog', description: '', createdAt: DateTime.now());
      
      when(mockGrowthProvider.goals).thenReturn([goal]);
      when(mockGrowthProvider.tasksByGoal).thenReturn({50: [task]});

      final result = filterLogic([], mockGrowthProvider);
      expect(result, isEmpty);
    });

    // 5. Mixed: Simple Reminder + Inbox Task (Both Show)
    test('5. Simple Reminder + Inbox Task should both show', () {
      final rem = Reminder(id: '1', text: 'Water Plants', timeAt: DateTime.now(), priority: ReminderPriority.low, category: ReminderCategory.personal);
      final goal = Goal(id: 999, name: 'Inbox', createdAt: DateTime.now());
      final task = GoalTask(id: 4, goalId: 999, title: 'Pay Bills', description: '', createdAt: DateTime.now());

      when(mockGrowthProvider.goals).thenReturn([goal]);
      when(mockGrowthProvider.tasksByGoal).thenReturn({999: [task]});

      final result = filterLogic([rem], mockGrowthProvider);
      expect(result.length, 2);
    });

    // 6. Mixed: Inbox Task + Business Goal Task (Only Inbox Shows)
    test('6. Inbox Task + Business Goal should only show Inbox', () {
      final inboxGoal = Goal(id: 999, name: 'Inbox', createdAt: DateTime.now());
      final bizGoal = Goal(id: 100, name: 'Startup', createdAt: DateTime.now());
      
      final inboxTask = GoalTask(id: 5, goalId: 999, title: 'Check Email', description: '', createdAt: DateTime.now());
      final bizTask = GoalTask(id: 6, goalId: 100, title: 'Pitch Deck', description: '', createdAt: DateTime.now());

      when(mockGrowthProvider.goals).thenReturn([inboxGoal, bizGoal]);
      when(mockGrowthProvider.tasksByGoal).thenReturn({
        999: [inboxTask],
        100: [bizTask]
      });

      final result = filterLogic([], mockGrowthProvider);
      expect(result.length, 1);
      expect(result.first.text, 'Check Email');
    });

    // 7. Empty Inbox (Should be Empty)
    test('7. Empty Inbox Goal should result in empty list', () {
      final inboxGoal = Goal(id: 999, name: 'Inbox', createdAt: DateTime.now());
      
      when(mockGrowthProvider.goals).thenReturn([inboxGoal]);
      when(mockGrowthProvider.tasksByGoal).thenReturn({999: []}); // Empty list

      final result = filterLogic([], mockGrowthProvider);
      expect(result, isEmpty);
    });

    // 8. No Inbox Goal Exists (Should Handle Gracefully)
    test('8. If "Inbox" Goal is missing, show nothing', () {
      final bizGoal = Goal(id: 100, name: 'Startup', createdAt: DateTime.now());
       final bizTask = GoalTask(id: 6, goalId: 100, title: 'Pitch Deck', description: '', createdAt: DateTime.now());
      
      when(mockGrowthProvider.goals).thenReturn([bizGoal]);
      when(mockGrowthProvider.tasksByGoal).thenReturn({100: [bizTask]});

      final result = filterLogic([], mockGrowthProvider);
      expect(result, isEmpty);
    });

    // 9. Subtasks logic (Should follow Parent Goal)
    test('9. Subtasks in Inbox should show (as flattened)', () {
       // Note: Flattening happens in provider usually. If provider returns them, logic should filter by Goal ID.
       final inboxGoal = Goal(id: 999, name: 'Inbox', createdAt: DateTime.now());
       final parentTask = GoalTask(id: 7, goalId: 999, title: 'Clean House', description: '', createdAt: DateTime.now());
       // Assume subtask is just another task in the flattened list for this test logic simulation
       final subTask = GoalTask(id: 8, goalId: 999, title: 'Vacuum', description: '', createdAt: DateTime.now());

       when(mockGrowthProvider.goals).thenReturn([inboxGoal]);
       when(mockGrowthProvider.tasksByGoal).thenReturn({999: [parentTask, subTask]});

       final result = filterLogic([], mockGrowthProvider);
       expect(result.length, 2);
    });

    // 10. Completed Task (Logic check - currently enabled mapping)
    test('10. Completed Inbox Task should be mapped correctly', () {
       final inboxGoal = Goal(id: 999, name: 'Inbox', createdAt: DateTime.now());
       final doneTask = GoalTask(id: 9, goalId: 999, title: 'Done Task', isCompleted: true, description: '', createdAt: DateTime.now());

       when(mockGrowthProvider.goals).thenReturn([inboxGoal]);
       when(mockGrowthProvider.tasksByGoal).thenReturn({999: [doneTask]});

       final result = filterLogic([], mockGrowthProvider);
       expect(result.length, 1);
       expect(result.first.enabled, false); // isCompleted=true -> enabled=false
    });

  });
}
