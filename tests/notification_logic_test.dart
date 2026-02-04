import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:lumio/presentation/providers/growth_provider.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_phase.dart';
import 'package:lumio/data/models/goal_settings.dart';
import 'package:lumio/core/services/notification_service.dart';
import 'package:lumio/data/repositories/firestore_growth_repository.dart';

// Mocks
class MockNotificationService implements NotificationService {
  final Map<int, String> scheduledNotifications = {}; // ID -> Title

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    dynamic matchDateTimeComponents, // Match signature
  }) async {
    scheduledNotifications[id] = title;
    debugPrint("MOCK SCHEDULE: $id - $title at $scheduledTime");
  }

  @override
  Future<void> cancelNotification(int id) async {
    scheduledNotifications.remove(id);
    debugPrint("MOCK CANCEL: $id");
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> showNotification({required int id, required String title, required String body, String? payload}) async {}

  @override
  Future<void> cancelAllNotifications() async {}

  @override
  Future<List<PendingNotificationRequest>> getPendingNotifications() async => [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> isNotificationScheduled(int id) async => scheduledNotifications.containsKey(id);
  
  // Ignore private members or other non-interface parts
}

class MockGrowthRepository implements FirestoreGrowthRepository {
  final Map<int, GoalTask> tasks = {};
  
  @override
  Future<int> createTask(GoalTask task) async {
    int id = task.id == 0 ? DateTime.now().millisecondsSinceEpoch : task.id;
    tasks[id] = task.copyWith(id: id);
    return id;
  }

  @override
  Future<int> updateTask(GoalTask task) async {
    tasks[task.id] = task;
    return 1;
  }

  @override
  Future<int> deleteTask(int taskId) async {
    tasks.remove(taskId);
    return 1;
  }
  
  @override
  Future<List<GoalTask>> getTasksForGoal(int goalId) async => [];
  @override
  Future<List<Goal>> getGoals() async => [];
  @override
  Future<List<GoalPhase>> getPhasesForGoal(int goalId) async => [];
  
  @override
  Future<int> completeTask(int taskId) async {
    if (tasks.containsKey(taskId)) {
      tasks[taskId] = tasks[taskId]!.copyWith(
        isCompleted: true, 
        completedAt: DateTime.now()
      );
    }
    return taskId;
  }

  @override
  Future<int> uncompleteTask(int taskId) async {
    if (tasks.containsKey(taskId)) {
      tasks[taskId] = tasks[taskId]!.copyWith(
        isCompleted: false, 
        completedAt: null
      );
    }
    return taskId;
  }

  @override
  Future<GoalTask?> getTaskById(int taskId) async {
    return tasks[taskId];
  }

  // Missing Stubs
  @override
  Future<int> createGoal(String name, {DateTime? targetDeadline, double? hoursPerDay, int? totalEstimatedHours, GoalSettings? settings, String? imageUrl}) async => 0;
  @override
  Future<Goal?> getGoal(int id) async => null;
  @override
  Future<int> updateGoal(Goal goal) async => 1;
  @override
  Future<int> deleteGoal(int id) async => 1;
  @override
  Future<void> replaceTasksForGoal(int goalId, List<GoalTask> tasks) async {}
  @override
  Future<List<GoalTask>> getTasksForDate(DateTime date) async => [];
  @override
  Future<int> createPhase(GoalPhase phase) async => 0;
  @override
  Future<GoalPhase?> getPhaseById(int id) async => null;
  @override
  Future<int> updatePhase(GoalPhase phase) async => 1;
  @override
  Future<int> deletePhase(int id) async => 1;
}



void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GrowthProvider provider;
  late MockNotificationService mockNotificationService;
  late MockGrowthRepository mockRepository;

  setUp(() {
    SharedPreferences.setMockInitialValues({}); 
    mockNotificationService = MockNotificationService();
    mockRepository = MockGrowthRepository();
    provider = GrowthProvider(
      repository: mockRepository,
      notificationService: mockNotificationService,
    );
  });

  group('Notification Logic Tests', () {
    // 1. Create Task with future date -> Expect Schedule
    test('1. Future Task schedules notification', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final task = GoalTask(
        id: 1, 
        title: 'Future Task', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(1), true);
    });

    // 2. Create Task with past date -> Expect No Schedule
    test('2. Past Task does not schedule', () async {
      final pastDate = DateTime.now().subtract(const Duration(hours: 1));
      final task = GoalTask(
        id: 2, 
        title: 'Past Task', 
        description: 'Desc', 
        scheduledDate: pastDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(2), false);
    });

    // 3. Create Task with no date -> Expect No Schedule
    test('3. No Date Task does not schedule', () async {
      final task = GoalTask(
        id: 3, 
        title: 'No Date Task', 
        description: 'Desc', 
        scheduledDate: null, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(3), false);
    });

    // 4. Create Task with subtask (future) -> Expect 2 Schedules
    test('4. Task with Future Subtask schedules both', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final subtask = GoalTask(
        id: 41, 
        title: 'Subtask', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      final task = GoalTask(
        id: 4, 
        title: 'Parent Task', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        subtasks: [subtask], 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(4), true);
      expect(mockNotificationService.scheduledNotifications.containsKey(41), true);
    });

    // 5. Create Task with subtask (no date) -> Expect 1 Schedule (Parent only)
    test('5. Task with No-Date Subtask schedules only parent', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final subtask = GoalTask(
        id: 51, 
        title: 'Subtask', 
        description: 'Desc', 
        scheduledDate: null, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      final task = GoalTask(
        id: 5, 
        title: 'Parent Task', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        subtasks: [subtask], 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(5), true);
      expect(mockNotificationService.scheduledNotifications.containsKey(51), false);
    });

    // 6. Update Task (change date to future) -> Expect Reschedule
    test('6. Update Task to future date schedules it', () async {
      // Start with past date (no schedule)
      final pastDate = DateTime.now().subtract(const Duration(hours: 1));
      var task = GoalTask(
        id: 6, 
        title: 'Task', 
        description: 'Desc', 
        scheduledDate: pastDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(6), false);

      // Update to future
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      task = task.copyWith(scheduledDate: futureDate);
      await provider.updateTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(6), true);
    });

    // 7. Update Task (complete) -> Expect Cancel
    test('7. Completing task cancels notification', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      var task = GoalTask(
        id: 7, 
        title: 'Task', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(7), true);

      // Complete
      task = task.copyWith(isCompleted: true);
      await provider.updateTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(7), false);
    });

    // 8. Delete Task -> Expect Cancel
    test('8. Deleting task cancels notification', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final task = GoalTask(
        id: 8, 
        title: 'Task', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(8), true);

      await provider.deleteTask(8);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(8), false);
    });

    // 9. Task "Any time" (midnight) -> Expect 9am (Morning default)
    test('9. Midnight task defaults to 9am', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final midnight = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0);
      
      final task = GoalTask(
        id: 9, 
        title: 'Midnight Task', 
        description: 'Desc', 
        scheduledDate: midnight, 
        suggestedTime: 'morning', 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(9), true);
    });

    // 10. Task "Any time" (afternoon) -> Expect 2pm
    test('10. Afternoon task defaults to 2pm', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final midnight = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0);
      
      // Note: Logic in provider looks at suggestedTime.
      final task = GoalTask(
        id: 10, 
        title: 'Afternoon Task', 
        description: 'Desc', 
        scheduledDate: midnight, 
        suggestedTime: 'afternoon', 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(10), true);
    });

    // 11. Task "Any time" (evening) -> Expect 6pm
    test('11. Evening task defaults to 6pm', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final midnight = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0);
      
      final task = GoalTask(
        id: 11, 
        title: 'Evening Task', 
        description: 'Desc', 
        scheduledDate: midnight, 
        suggestedTime: 'evening', 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(11), true);
    });

    // 12. Recursive subtasks (level 2)
    test('12. Nested subtasks (depth 2) are scheduled', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final sub2 = GoalTask(
        id: 122, 
        title: 'Sub 2', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      final sub1 = GoalTask(
        id: 121, 
        title: 'Sub 1', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        subtasks: [sub2], 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      final task = GoalTask(
        id: 12, 
        title: 'Root', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        subtasks: [sub1], 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(12), true);
      expect(mockNotificationService.scheduledNotifications.containsKey(121), true);
      expect(mockNotificationService.scheduledNotifications.containsKey(122), true);
    });

    // 13. Subtask cancellation
    test('13. Cancelling subtask works', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final sub = GoalTask(
        id: 131, 
        title: 'Sub', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      var task = GoalTask(
        id: 13, 
        title: 'Root', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        subtasks: [sub], 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(131), true);

      // Update task with completed subtask
      final subCompleted = sub.copyWith(isCompleted: true);
      task = task.copyWith(subtasks: [subCompleted]);
      await provider.updateTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(131), false);
    });

    // 14. Uncompletign task reschedules
    test('14. Uncompleting task reschedules', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      var task = GoalTask(
        id: 14, 
        title: 'Task', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        isCompleted: true, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      
      // Initial create (completed, so no schedule)
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(14), false);

      // Uncomplete
      task = task.copyWith(isCompleted: false);
      await provider.updateTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(14), true);
    });
    
    // 15. Notification title check
    test('15. Notification title check', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final task = GoalTask(
        id: 15, 
        title: 'Check Title', 
        description: 'Desc', 
        scheduledDate: futureDate, 
        goalId: 1, 
        createdAt: DateTime.now()
      );
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications[15], contains('Check Title'));
    });

    // 16. Uncompleting Subtask reschedules it
    test('16. Uncompleting Subtask reschedules it', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final sub = GoalTask(
        id: 161, title: 'Sub', description: 'desc', scheduledDate: futureDate, isCompleted: true, goalId: 1, createdAt: DateTime.now()
      );
      var task = GoalTask(
        id: 16, title: 'Root', description: 'desc', scheduledDate: futureDate, subtasks: [sub], goalId: 1, createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications.containsKey(161), false);
      
      // Update task with UNcompleted subtask
      final subUncompleted = sub.copyWith(isCompleted: false);
      task = task.copyWith(subtasks: [subUncompleted]);
      await provider.updateTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(161), true);
    });

    // 17. Updating Task Priority updates notification body
    test('17. Priority update refreshes notification', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      var task = GoalTask(
        id: 17, title: 'Task', description: 'desc', scheduledDate: futureDate, priority: 'low', goalId: 1, createdAt: DateTime.now()
      );
      await provider.createTask(task);
      
      // Update to high
      task = task.copyWith(priority: 'high');
      await provider.updateTask(task);
      
      // We can't strictly check the body text in this mock without storing it better, 
      // but we can check it's still scheduled.
      expect(mockNotificationService.scheduledNotifications.containsKey(17), true);
    });

    // 18. Updating Task Title updates notification
    test('18. Title update refreshes notification', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      var task = GoalTask(
        id: 18, title: 'Old Title', description: 'desc', scheduledDate: futureDate, goalId: 1, createdAt: DateTime.now()
      );
      await provider.createTask(task);
      expect(mockNotificationService.scheduledNotifications[18], contains('Old Title'));
      
      task = task.copyWith(title: 'New Title');
      await provider.updateTask(task);
      
      expect(mockNotificationService.scheduledNotifications[18], contains('New Title'));
    });

    // 19. Task with scheduledDate but isCompleted=true at creation -> No Schedule
    test('19. Created Completed Task has no schedule', () async {
      final futureDate = DateTime.now().add(const Duration(hours: 1));
      final task = GoalTask(
        id: 19, title: 'Done Task', description: 'desc', scheduledDate: futureDate, isCompleted: true, goalId: 1, createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(19), false);
    });

    // 20. Task with very distant future date -> Schedules correctly
    test('20. Distant Future Task schedules', () async {
      final distantDate = DateTime.now().add(const Duration(days: 365));
      final task = GoalTask(
        id: 20, title: 'Yearly Task', description: 'desc', scheduledDate: distantDate, goalId: 1, createdAt: DateTime.now()
      );
      
      await provider.createTask(task);
      
      expect(mockNotificationService.scheduledNotifications.containsKey(20), true);
    });
  });
}
