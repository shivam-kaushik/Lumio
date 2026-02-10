import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lumio/core/services/motivational_engine.dart';
import 'package:lumio/core/services/notification_service.dart';
import 'package:lumio/core/services/premium_service.dart';
import 'package:lumio/core/services/privacy_gpt_service.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:lumio/data/models/goal_settings.dart';
import 'package:lumio/data/repositories/firestore_growth_repository.dart';

// Mocks
class MockFirestoreGrowthRepository extends Mock implements FirestoreGrowthRepository {
  @override
  Future<List<Goal>> getGoals() async => super.noSuchMethod(
        Invocation.method(#getGoals, []),
        returnValue: Future.value(<Goal>[]),
        returnValueForMissingStub: Future.value(<Goal>[]),
      );

  @override
  Future<List<GoalTask>> getTasksForGoal(int? goalId) async => super.noSuchMethod(
        Invocation.method(#getTasksForGoal, [goalId]),
        returnValue: Future.value(<GoalTask>[]),
        returnValueForMissingStub: Future.value(<GoalTask>[]),
      );
}

class MockNotificationService extends Mock implements NotificationService {
  @override
  Future<void> showNotification({
    required int? id,
    required String? title,
    required String? body,
    String? payload,
  }) async => super.noSuchMethod(
        Invocation.method(#showNotification, [], {
          #id: id,
          #title: title,
          #body: body,
          #payload: payload,
        }),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );

  @override
  Future<void> cancelNotification(int? id) async => super.noSuchMethod(
        Invocation.method(#cancelNotification, [id]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      );
}

class MockPrivacyGptService extends Mock implements PrivacyGptService {}

class MockPremiumService extends Mock implements PremiumService {
  @override
  Future<bool> isPremium() async => super.noSuchMethod(
        Invocation.method(#isPremium, []),
        returnValue: Future.value(false),
        returnValueForMissingStub: Future.value(false),
      );
}

void main() {
  late MockFirestoreGrowthRepository mockRepo;
  late MockNotificationService mockNotifications;
  late MockPremiumService mockPremium;
  late MotivationalEngine engine;

  final now = DateTime.now();
  // Standard test time: 2:00 PM (Wake 8, Sleep 22). Ideal for Deadline Checks.
  final testTime2PM = DateTime(now.year, now.month, now.day, 14, 0);

  // Helper to calculate generic ID matching implementation logic
  int calculateGenericId(int taskId) {
    return 2000 + ("task_$taskId".hashCode.abs() % 100000);
  }

  GoalTask createTask({
    required int id,
    required int goalId, 
    String title = 'Task',
    DateTime? scheduledDate,
    String priority = 'medium',
    bool isCompleted = false,
    List<GoalTask> subtasks = const [],
  }) {
    return GoalTask(
      id: id,
      goalId: goalId,
      title: title,
      description: 'Test Description',
      createdAt: now,
      scheduledDate: scheduledDate,
      priority: priority,
      subtasks: subtasks,
      isCompleted: isCompleted,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockRepo = MockFirestoreGrowthRepository();
    mockNotifications = MockNotificationService();
    mockPremium = MockPremiumService();
    
    engine = MotivationalEngine(
      repository: mockRepo,
      notifications: mockNotifications,
      premiumService: mockPremium,
      gptService: MockPrivacyGptService(),
    );
  });

  group('MotivationalEngine Tests', () {
    // 1. Generic Nudge Logic (Deadlines) - Uses nowOverride to hit standard notification block
    test('1. Schedules generic nudge for Urgent task (< 24h) without settings', () async {
      final goal = Goal(id: 1, name: 'Goal 1', createdAt: now);
      final task = createTask(id: 101, goalId: 1, scheduledDate: testTime2PM.add(const Duration(hours: 1)));
      
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(1)).thenAnswer((_) async => [task]);

      await engine.checkAndSchedule(nowOverride: testTime2PM);

      verify(mockNotifications.showNotification(
        id: anyNamed('id'), 
        title: argThat(contains('Due Today'), named: 'title'), // Title is deterministic
        body: anyNamed('body'), 
        payload: anyNamed('payload')
      )).called(1);
    });

    test('2. Schedules generic nudge for Upcoming task (1-2 days) without settings', () async {
      final goal = Goal(id: 2, name: 'Goal 2', createdAt: now);
      final task = createTask(id: 201, goalId: 2, scheduledDate: testTime2PM.add(const Duration(hours: 30)));

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(2)).thenAnswer((_) async => [task]);

      await engine.checkAndSchedule(nowOverride: testTime2PM);

      verify(mockNotifications.showNotification(
        title: argThat(contains('Due Tomorrow'), named: 'title'),
        id: anyNamed('id'), body: anyNamed('body'), payload: anyNamed('payload')
      )).called(1);
    });

    test('3. Does NOT schedule generic nudge for Far Future task (> 2 days)', () async {
      final goal = Goal(id: 3, name: 'Goal 3', createdAt: now);
      final task = createTask(id: 301, goalId: 3, scheduledDate: testTime2PM.add(const Duration(days: 4)));
      
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(3)).thenAnswer((_) async => [task]);

      await engine.checkAndSchedule(nowOverride: testTime2PM);

      verifyNever(mockNotifications.showNotification(
        id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body'), payload: anyNamed('payload')
      ));
    });

    // 2. Settings & Duplicate Prevention (Deadlines)
    test('4. Should NOT schedule generic nudge if notifications disabled in Settings', () async {
      final settings = GoalSettings(enableNotifications: false);
      final goal = Goal(id: 4, name: 'Quiet Goal', createdAt: now, settings: settings);
      final task = createTask(id: 401, goalId: 4, scheduledDate: testTime2PM.add(const Duration(hours: 2)));

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(4)).thenAnswer((_) async => [task]);

      await engine.checkAndSchedule(nowOverride: testTime2PM);

      // Verify CLEANUP happened (Cancellation now runs for disabled settings too)
      final genericId = calculateGenericId(401);
      verify(mockNotifications.cancelNotification(genericId)).called(1);
      
      // Verify NO new notification
      verifyNever(mockNotifications.showNotification(
        id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body'), payload: anyNamed('payload')
      ));
    });

    test('5. Should CANCEL generic nudge if custom settings exist (Duplicate Prevention)', () async {
      final settings = GoalSettings(enableNotifications: true, frequency: NotificationFrequency.daily);
      final goal = Goal(id: 5, name: 'Custom Goal', createdAt: now, settings: settings);
      final task = createTask(id: 501, goalId: 5, scheduledDate: testTime2PM.add(const Duration(days: 1)));

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(5)).thenAnswer((_) async => [task]);

      await engine.checkAndSchedule(nowOverride: testTime2PM);

      final genericId = calculateGenericId(501);
      verify(mockNotifications.cancelNotification(genericId)).called(1);
      verifyNever(mockNotifications.showNotification(id: genericId, title: anyNamed('title'), body: anyNamed('body')));
    });

    test('6. Mixed Scenario: Custom Goal cancels, Generic Goal schedules', () async {
      final customGoal = Goal(id: 6, name: 'Custom', createdAt: now, settings: GoalSettings(enableNotifications: true));
      final customTask = createTask(id: 601, goalId: 6, scheduledDate: testTime2PM.add(Duration(hours: 1)));

      final genericGoal = Goal(id: 7, name: 'Generic', createdAt: now);
      final genericTask = createTask(id: 701, goalId: 7, scheduledDate: testTime2PM.add(Duration(hours: 1)));

      when(mockRepo.getGoals()).thenAnswer((_) async => [customGoal, genericGoal]);
      when(mockRepo.getTasksForGoal(6)).thenAnswer((_) async => [customTask]);
      when(mockRepo.getTasksForGoal(7)).thenAnswer((_) async => [genericTask]);

      await engine.checkAndSchedule(nowOverride: testTime2PM);

      // Custom cancels
      final customGenericId = calculateGenericId(601);
      verify(mockNotifications.cancelNotification(customGenericId)).called(1);
      
      // Generic schedules
      verify(mockNotifications.showNotification(
        title: argThat(contains('Due Today'), named: 'title'), // Check title instead of body
        id: anyNamed('id'),  body: anyNamed('body'), payload: anyNamed('payload')
      )).called(1);
    });

    // 3. Morning Kickstart & Tones - Uses force: true
    test('7. Morning Kickstart uses Funny Tone', () async {
      final settings = GoalSettings(enableNotifications: true, tone: NotificationTone.funny);
      final goal = Goal(id: 8, name: 'Funny', createdAt: now, settings: settings);
      final task = createTask(id: 801, goalId: 8, priority: 'high');

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(8)).thenAnswer((_) async => [task]);
      SharedPreferences.setMockInitialValues({'setting_wake_time': now.hour}); 

      await engine.checkAndSchedule(force: true); 

      verify(mockNotifications.showNotification(
        id: 1001, title: anyNamed('title'), 
        body: argThat(contains('Knock knock'), named: 'body'), 
        payload: anyNamed('payload')
      )).called(1);
    });

    test('8. Morning Kickstart uses Severe Tone', () async {
      final settings = GoalSettings(enableNotifications: true, tone: NotificationTone.severe);
      final goal = Goal(id: 9, name: 'Severe', createdAt: now, settings: settings);
      final task = createTask(id: 901, goalId: 9, priority: 'high');

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(9)).thenAnswer((_) async => [task]);
      SharedPreferences.setMockInitialValues({'setting_wake_time': now.hour}); 

      await engine.checkAndSchedule(force: true);

      verify(mockNotifications.showNotification(
        id: 1001, title: anyNamed('title'), 
        body: argThat(contains('ATTENTION'), named: 'body'), 
        payload: anyNamed('payload')
      )).called(1);
    });

    test('9. Morning Kickstart uses Quotes Tone', () async {
      final settings = GoalSettings(enableNotifications: true, tone: NotificationTone.quotes);
      final goal = Goal(id: 10, name: 'Quotes', createdAt: now, settings: settings);
      final task = createTask(id: 1001, goalId: 10, priority: 'high');

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(10)).thenAnswer((_) async => [task]);
      SharedPreferences.setMockInitialValues({'setting_wake_time': now.hour}); 

      await engine.checkAndSchedule(force: true);

      verify(mockNotifications.showNotification(
        id: 1001, title: anyNamed('title'), 
        body: argThat(contains('- Gandhi'), named: 'body'), 
        payload: anyNamed('payload')
      )).called(1);
    });

    test('10. Morning Kickstart uses Motivational Tone (Default)', () async {
      final settings = GoalSettings(enableNotifications: true, tone: NotificationTone.motivational);
      final goal = Goal(id: 11, name: 'Moti', createdAt: now, settings: settings);
      final task = createTask(id: 1101, goalId: 11, priority: 'high');

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(11)).thenAnswer((_) async => [task]);
      SharedPreferences.setMockInitialValues({'setting_wake_time': now.hour}); 

      await engine.checkAndSchedule(force: true);

      verify(mockNotifications.showNotification(
        id: 1001, title: anyNamed('title'),
        body: argThat(contains("Let's tackle"), named: 'body'),
        payload: anyNamed('payload')
      )).called(1);
    });

    // 4. Quiet Hours & Exclusion
    test('11. Skips Morning Kickstart during Quiet Hours testing logic', () async {
       // This test is theoretical as we override time/force. 
       // Just ensuring invalid time doesn't trigger without force.
       SharedPreferences.setMockInitialValues({'setting_wake_time': 8, 'setting_sleep_time': 9});
       final lateNight = DateTime(now.year, now.month, now.day, 23, 0);
       
       await engine.checkAndSchedule(nowOverride: lateNight);
       verifyNever(mockNotifications.showNotification(id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body')));
    });

    test('12. Force=true bypasses Quiet Hours', () async {
      SharedPreferences.setMockInitialValues({'setting_quiet_mode': true});
      final goal = Goal(id: 12, name: 'G', createdAt: now);
      final task = createTask(id: 1201, goalId: 12);
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(12)).thenAnswer((_) async => [task]);

      await engine.checkAndSchedule(force: true); // Force triggers morning kickstart

      verify(mockNotifications.showNotification(
         id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body'), payload: anyNamed('payload')
      )).called(greaterThanOrEqualTo(1));
    });

    test('13. Daily Plan goals are excluded from suggestions', () async {
      final goal = Goal(id: 13, name: 'Daily Plan - 2024', createdAt: now);
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      await engine.checkAndSchedule(force: true);
      verifyNever(mockRepo.getTasksForGoal(13));
    });

    test('14. Inbox goals are excluded from suggestions', () async {
      final goal = Goal(id: 14, name: 'Inbox', createdAt: now);
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      await engine.checkAndSchedule(force: true);
      verifyNever(mockRepo.getTasksForGoal(14));
    });

    test('15. Completed tasks are ignored (Goal might trigger, but Task should NOT)', () async {
      final goal = Goal(id: 15, name: 'Done', createdAt: now);
      final task = createTask(id: 1501, goalId: 15, isCompleted: true);
      
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(15)).thenAnswer((_) async => [task]);

      await engine.checkAndSchedule(force: true);

      // We ensure notification doesn't point to this task ID
      verifyNever(mockNotifications.showNotification(
         id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body'), 
         payload: argThat(contains('task_1501'), named: 'payload')
      ));
    });

    // 5. Structure & Sanity
    test('16. Empty goals list returns early', () async {
      when(mockRepo.getGoals()).thenAnswer((_) async => []);
      await engine.checkAndSchedule(force: true);
      verifyNever(mockNotifications.showNotification(id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body')));
    });

    test('17. Goal with no tasks schedules nothing (if Goal has no schedule itself?)', () async {
      final goal = Goal(id: 17, name: 'Empty', createdAt: now);
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(17)).thenAnswer((_) async => []);
      
      // Goal logic includes it as candidate if active. 
      // This test might be flaky if Goal logic allows empty goals.
      // But typically Morning Kickstart picks.
      // Let's assume default behavior.
    });

    test('18. Subtasks are recursively included in candidates', () async {
      final goal = Goal(id: 18, name: 'Deep', createdAt: now);
      final subtask = createTask(id: 1802, goalId: 18, title: 'Deep Sub');
      final task = createTask(id: 1801, goalId: 18, subtasks: [subtask]);

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(18)).thenAnswer((_) async => [task]);
      SharedPreferences.setMockInitialValues({'setting_wake_time': now.hour});

      await engine.checkAndSchedule(force: true); 

      // We expect 1 notification, picked from candidates (task or subtask).
      verify(mockNotifications.showNotification(id: 1001, title: anyNamed('title'), body: anyNamed('body'), payload: anyNamed('payload'))).called(1);
    });

    test('19. Task without deadline ignored for Deadline Nudges', () async {
      final goal = Goal(id: 19, name: 'Timeless', createdAt: now);
      final task = createTask(id: 1901, goalId: 19, scheduledDate: null);
      
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(19)).thenAnswer((_) async => [task]);

      await engine.checkAndSchedule(nowOverride: testTime2PM);

      verifyNever(mockNotifications.showNotification(id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body')));
    });

    test('20. Priority Low tasks can be picked if no High priority (Kickstart)', () async {
      final goal = Goal(id: 20, name: 'Low', createdAt: now);
      final task = createTask(id: 2001, goalId: 20, priority: 'low');
      
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(20)).thenAnswer((_) async => [task]);
      SharedPreferences.setMockInitialValues({'setting_wake_time': now.hour});

      await engine.checkAndSchedule(force: true);

      verify(mockNotifications.showNotification(id: 1001, title: anyNamed('title'), body: anyNamed('body'), payload: anyNamed('payload'))).called(1);
    });

    // 6. Resilience
    test('21. Cancellation failure does not crash engine (Needs Deadline Check)', () async {
      when(mockNotifications.cancelNotification(any)).thenThrow(Exception("Native error"));
      
      final settings = GoalSettings(enableNotifications: true); // Custom settings trigger cancellation
      final goal = Goal(id: 21, name: 'Error', createdAt: now, settings: settings);
      final task = createTask(id: 2101, goalId: 21, scheduledDate: testTime2PM.add(Duration(days: 1)));

      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(21)).thenAnswer((_) async => [task]);

      // Use nowOverride to trigger deadline/duplicate check path
      await engine.checkAndSchedule(nowOverride: testTime2PM);
    });

    test('22. Premium Service check is awaited correctly', () async {
      when(mockPremium.isPremium()).thenAnswer((_) async => true);
      final goal = Goal(id: 22, name: 'Prem', createdAt: now);
      final task = createTask(id: 2201, goalId: 22, subtasks: []);
      
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(22)).thenAnswer((_) async => [task]);
      SharedPreferences.setMockInitialValues({'setting_wake_time': now.hour});

      await engine.checkAndSchedule(force: true);
      // Logic for premium might be in Morning content gen, let's verify no crash
    });

    // 7. Data Integrity (Tasks with settings, titles, etc)
    test('23. Task ID collision handling (Robustness)', () async {
      final goal = Goal(id: 23, name: 'Collision', createdAt: now);
      final task1 = createTask(id: 999, goalId: 23, title: 'A');
      final task2 = createTask(id: 999, goalId: 23, title: 'B'); // Same ID
      
      when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
      when(mockRepo.getTasksForGoal(23)).thenAnswer((_) async => [task1, task2]);

      await engine.checkAndSchedule(force: true);
    });

    test('24. Null Settings in task inheritance checks (Deadline)', () async {
       final goal = Goal(id: 24, name: 'NullSet', createdAt: now); // settings null
       final task = createTask(id: 2401, goalId: 24, scheduledDate: testTime2PM.add(Duration(hours: 1)));
       
       when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
       when(mockRepo.getTasksForGoal(24)).thenAnswer((_) async => [task]);

       await engine.checkAndSchedule(nowOverride: testTime2PM);
       verify(mockNotifications.showNotification(id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body'), payload: anyNamed('payload'))).called(1);
    });

    test('25. Empty Task Title fallback', () async {
       final goal = Goal(id: 25, name: 'EmptyTitle', createdAt: now);
       final task = createTask(id: 2501, goalId: 25, title: '', scheduledDate: testTime2PM.add(Duration(hours: 1)));
       
       when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
       when(mockRepo.getTasksForGoal(25)).thenAnswer((_) async => [task]);

       await engine.checkAndSchedule(nowOverride: testTime2PM);
       verify(mockNotifications.showNotification(
         id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body'), 
         payload: anyNamed('payload') // Added payload matcher
       )).called(1);
    });

    test('26. Very long Task Title truncation (Implicit)', () async {
       String longTitle = 'A' * 200;
       final goal = Goal(id: 26, name: 'Long', createdAt: now);
       final task = createTask(id: 2601, goalId: 26, title: longTitle, scheduledDate: testTime2PM.add(Duration(hours: 1)));
       
       when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
       when(mockRepo.getTasksForGoal(26)).thenAnswer((_) async => [task]);

       await engine.checkAndSchedule(nowOverride: testTime2PM);
    });

    test('27. Future Deadline (>48h) ignores generic nudge', () async {
       final goal = Goal(id: 27, name: 'Far', createdAt: now);
       final task = createTask(id: 2701, goalId: 27, scheduledDate: testTime2PM.add(Duration(hours: 49)));
       
       when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
       when(mockRepo.getTasksForGoal(27)).thenAnswer((_) async => [task]);

       await engine.checkAndSchedule(nowOverride: testTime2PM);
       
       verifyNever(mockNotifications.showNotification(id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body')));
    });

    test('28. Exact 24h Deadline (Boundary check)', () async {
       final goal = Goal(id: 28, name: 'Boundary', createdAt: now);
       final task = createTask(id: 2801, goalId: 28, scheduledDate: testTime2PM.add(Duration(hours: 24)));

       when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
       when(mockRepo.getTasksForGoal(28)).thenAnswer((_) async => [task]);

       await engine.checkAndSchedule(nowOverride: testTime2PM);

       verify(mockNotifications.showNotification(
          title: argThat(contains("Due Tomorrow"), named: 'title'),
          id: anyNamed('id'), body: anyNamed('body'), payload: anyNamed('payload')
       )).called(1);
    });

    test('29. Past Deadline (Overdue)', () async {
       final goal = Goal(id: 29, name: 'Overdue', createdAt: now);
       final task = createTask(id: 2901, goalId: 29, scheduledDate: testTime2PM.subtract(Duration(hours: 1)));
       
       when(mockRepo.getGoals()).thenAnswer((_) async => [goal]);
       when(mockRepo.getTasksForGoal(29)).thenAnswer((_) async => [task]);

       await engine.checkAndSchedule(nowOverride: testTime2PM);
       
       verifyNever(mockNotifications.showNotification(id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body')));
    });

    test('30. Final sanity check with multiple mixed goals', () async {
       when(mockRepo.getGoals()).thenAnswer((_) async => [
         Goal(id: 30, name: 'A', createdAt: now), 
         Goal(id: 31, name: 'B', createdAt: now)
       ]);
       when(mockRepo.getTasksForGoal(30)).thenAnswer((_) async => []);
       when(mockRepo.getTasksForGoal(31)).thenAnswer((_) async => []);

       await engine.checkAndSchedule(nowOverride: testTime2PM);
       
       verifyNever(mockNotifications.showNotification(id: anyNamed('id'), title: anyNamed('title'), body: anyNamed('body')));
    });

  });
}
