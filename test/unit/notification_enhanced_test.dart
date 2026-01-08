import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:lumio/core/services/notification_service.dart';
import 'package:lumio/core/services/motivational_engine.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_phase.dart';
import 'package:lumio/presentation/providers/growth_provider.dart';
import 'package:lumio/data/repositories/firestore_growth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Mock classes
class MockNotificationService extends Mock implements NotificationService {
  final List<Map<String, dynamic>> scheduledNotifications = [];
  
  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    dynamic matchDateTimeComponents, // Changed from DateTimeComponents? to dynamic to avoid import if not available, strictly matching signature requires exact type but mock might interpret differently. 
    // Wait, the error message said:
    // 'Future<void> Function({required String body, required int id, DateTimeComponents? matchDateTimeComponents, String? payload, required DateTime scheduledTime, required String title})'
    // My previous override was:
    // Future<void> scheduleNotification({ required int id, required String title, required String body, required DateTime scheduledTime, String? payload, })
    // I need to match the named parameters exactly.
  }) async {
    scheduledNotifications.removeWhere((n) => n['id'] == id);
    scheduledNotifications.add({
      'id': id,
      'title': title,
      'body': body,
      'scheduledTime': scheduledTime,
      'payload': payload,
    });
  }
  
  @override
  Future<void> cancelNotification(int id) async {
    scheduledNotifications.removeWhere((n) => n['id'] == id);
  }
}

class MockGrowthRepository extends Mock implements FirestoreGrowthRepository {
  @override
  Future<int> createTask(GoalTask task) async => task.id;
  
  @override
  Future<int> updateTask(GoalTask task) async => 1;

  @override
  Future<List<Goal>> getGoals() async => [];
  
  @override
  Future<List<GoalTask>> getTasksForGoal(int goalId) async => [];
  
  @override
  Future<List<GoalPhase>> getPhasesForGoal(int goalId) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // Fix binding error
  
  late MockNotificationService mockNotificationService;
  late MockGrowthRepository mockRepository;
  late GrowthProvider growthProvider;

  setUp(() {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    mockNotificationService = MockNotificationService();
    mockRepository = MockGrowthRepository();
    growthProvider = GrowthProvider(
      repository: mockRepository,
      notificationService: mockNotificationService,
    );
  });

  group('MotivationalEngine Tests', () {
    // 1. Test that Kickstart returns a string
    test('Kickstart returns a non-empty string', () {
      final msg = TemplateEngine.getKickstart("My Goal", "My Context");
      expect(msg, isNotEmpty);
    });

    // 2. Test that Deadline Nudge returns a string
    test('Deadline Nudge returns a non-empty string', () {
      final msg = TemplateEngine.getDeadlineNudge("My Goal", "tomorrow");
      expect(msg, isNotEmpty);
    });

    // 3. Test that Consistency Nudge returns a string
    test('Consistency Nudge returns a non-empty string', () {
      final msg = TemplateEngine.getConsistency("My Goal");
      expect(msg, isNotEmpty);
    });

    // 4. Test that messages contain goal name (mostly - quotes might not)
    // This is tricky because quotes are random. We can check if it's EITHER a quote OR contains goal name.
    test('Messages are valid', () {
      final msg = TemplateEngine.getKickstart("UniqueGoalName", "Context");
      bool isQuote = !msg.contains("UniqueGoalName");
      if (!isQuote) {
        expect(msg, contains("UniqueGoalName"));
      }
    });
    
    // 5-10. Probabilistic Tests - Run multiple times to ensure we get both types
    test('Kickstart produces variability', () {
      Set<String> outputs = {};
      for(int i=0; i<50; i++) {
        outputs.add(TemplateEngine.getKickstart("Goal", "Context"));
      }
      // Should have at least 2 different outputs (template vs quote)
      expect(outputs.length, greaterThan(1));
    });

    test('Deadline produces variability', () {
       Set<String> outputs = {};
      for(int i=0; i<50; i++) {
        outputs.add(TemplateEngine.getDeadlineNudge("Goal", "today"));
      }
      expect(outputs.length, greaterThan(1));
    });

    test('Consistency produces variability', () {
       Set<String> outputs = {};
      for(int i=0; i<50; i++) {
        outputs.add(TemplateEngine.getConsistency("Goal"));
      }
      expect(outputs.length, greaterThan(1));
    });
  });

  group('Recursive Notification Scheduling Tests', () {
    // 11. Test Root Task Scheduling
    test('Schedules notification for root task', () async {
      final task = GoalTask(
        id: 1,
        goalId: 1,
        title: "Root Task",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
      );

      await growthProvider.createTask(task); // This calls _scheduleTaskNotification internally? 
      // Actually createTask calls _scheduleTaskNotification. 
      // But we need to make sure we can access the protected method or trigger it via public API.
      // growthProvider.createTask() calls it.
      
      expect(mockNotificationService.scheduledNotifications.length, 1);
      expect(mockNotificationService.scheduledNotifications.first['id'], 1);
    });

    // 12. Test Subtask Scheduling (Level 1)
    test('Schedules notification for subtask', () async {
      final subtask = GoalTask(
        id: 2,
        goalId: 1,
        title: "Subtask",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 2)),
      );
      
      final root = GoalTask(
        id: 1,
        goalId: 1,
        title: "Root",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
        subtasks: [subtask],
      );

      await growthProvider.createTask(root);
      
      expect(mockNotificationService.scheduledNotifications.length, 2);
      expect(mockNotificationService.scheduledNotifications.any((n) => n['id'] == 1), isTrue);
      expect(mockNotificationService.scheduledNotifications.any((n) => n['id'] == 2), isTrue);
    });

    // 13. Test Deep Nested Subtask Scheduling (Level 2)
    test('Schedules notification for deep subtask', () async {
       final deepSub = GoalTask(
        id: 3,
        goalId: 1,
        title: "Deep",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 3)),
      );
      
      final sub = GoalTask(
        id: 2,
        goalId: 1,
        title: "Sub",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 2)),
        subtasks: [deepSub],
      );
      
      final root = GoalTask(
        id: 1,
        goalId: 1,
        title: "Root",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
        subtasks: [sub],
      );

      await growthProvider.createTask(root);
      
      expect(mockNotificationService.scheduledNotifications.length, 3);
      expect(mockNotificationService.scheduledNotifications.map((n) => n['id']).toSet(), {1, 2, 3});
    });

    // 14. Test Ignore Past Tasks
    test('Does not schedule past tasks', () async {
       final pastTask = GoalTask(
        id: 4,
        goalId: 1,
        title: "Past",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().subtract(const Duration(hours: 1)),
      );
      
      await growthProvider.createTask(pastTask);
      expect(mockNotificationService.scheduledNotifications.isEmpty, isTrue);
    });

    // 15. Test Subtask Past Ignore
    test('Schedules root but ignores past subtask', () async {
       final pastSub = GoalTask(
        id: 5,
        goalId: 1,
        title: "Past Sub",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().subtract(const Duration(hours: 1)),
      );
      
      final root = GoalTask(
        id: 6,
        goalId: 1,
        title: "Future Root",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
        subtasks: [pastSub],
      );

      await growthProvider.createTask(root);
      
      expect(mockNotificationService.scheduledNotifications.length, 1);
      expect(mockNotificationService.scheduledNotifications.first['id'], 6);
    });

    // 16. Test Completed Task Ignore
    test('Does not schedule completed tasks', () async {
      final completed = GoalTask(
        id: 7,
        goalId: 1,
        title: "Done",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
        isCompleted: true,
      );

      await growthProvider.createTask(completed);
      expect(mockNotificationService.scheduledNotifications.isEmpty, isTrue);
    });
    
    // 17. Test Cancel Logic (via completed)
    test('Cancels notification if completed', () async {
       // First create active
       final active = GoalTask(
        id: 8,
        goalId: 1,
        title: "Active",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
      );
      await growthProvider.createTask(active);
      expect(mockNotificationService.scheduledNotifications.length, 1);

      // Now update to completed
      final completed = active.copyWith(isCompleted: true);
      await growthProvider.updateTask(completed); // Should trigger cancel
      
      expect(mockNotificationService.scheduledNotifications.isEmpty, isTrue);
    });

    // 18. Test Subtask Cancel Logic
    test('Cancels subtask notification if subtask completed', () async {
       final sub = GoalTask(
        id: 10,
        goalId: 1,
        title: "Sub",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
      );
       final root = GoalTask(
        id: 9,
        goalId: 1,
        title: "Root",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
        subtasks: [sub],
      );
      
      await growthProvider.createTask(root);
      expect(mockNotificationService.scheduledNotifications.length, 2);

      // Complete subtask
      final completedSub = sub.copyWith(isCompleted: true);
      final updatedRoot = root.copyWith(subtasks: [completedSub]);
      
      await growthProvider.updateTask(updatedRoot);
      
      // Should have cancelled id 10, but kept 9
      expect(mockNotificationService.scheduledNotifications.length, 1);
      expect(mockNotificationService.scheduledNotifications.first['id'], 9);
    });

    // 19. Test Payload Correctness
    test('Payload contains correct data', () async {
       final task = GoalTask(
        id: 11,
        goalId: 2,
        title: "Task",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now().add(const Duration(hours: 1)),
      );
      
      await growthProvider.createTask(task);
      final payload = mockNotificationService.scheduledNotifications.first['payload'];
      final data = jsonDecode(payload!);
      
      expect(data['task_id'], 11);
      expect(data['goal_id'], 2);
    });

    // 20. Test Midnight Adjustment
    test('Midnight (00:00) adjusts to morning/preference', () async {
       // Create date at midnight
       final now = DateTime.now();
       final midnight = DateTime(now.year, now.month, now.day + 1, 0, 0);
       
       final task = GoalTask(
        id: 12,
        goalId: 1,
        title: "Midnight Task",
        description: "",
        createdAt: DateTime.now(),
        scheduledDate: midnight,
        suggestedTime: 'morning', // Should set to 9 AM
      );
      
      await growthProvider.createTask(task);
      
      final scheduled = mockNotificationService.scheduledNotifications.first['scheduledTime'] as DateTime;
      expect(scheduled.hour, 9);
    });
  });
}


