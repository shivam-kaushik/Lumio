
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:lumio/core/services/motivational_engine.dart';
import 'package:lumio/core/services/notification_service.dart';
import 'package:lumio/core/services/privacy_gpt_service.dart';
import 'package:lumio/core/services/premium_service.dart';
import 'package:lumio/data/repositories/firestore_growth_repository.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fakes & Mocks
class MockGrowthRepository extends Mock implements FirestoreGrowthRepository {
  List<Goal> _goals = [];
  List<GoalTask> _tasks = [];

  void setGoals(List<Goal> goals) => _goals = goals;
  void setTasks(List<GoalTask> tasks) => _tasks = tasks;

  @override
  Future<List<Goal>> getGoals() async => _goals;

  @override
  Future<List<GoalTask>> getTasksForGoal(int goalId) async => _tasks;
}

class FakeNotificationService extends Fake implements NotificationService {
  final List<Map<String, dynamic>> scheduled = [];

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    scheduled.add({
      'id': id,
      'title': title,
      'body': body,
      'payload': payload,
    });
  }
}

class FakePrivacyGptService extends Fake implements PrivacyGptService {
  String? _mockResponse;
  
  void setMockResponse(String response) => _mockResponse = response;

  @override
  Future<String?> generateContextAwareMessage({
    required String systemInstruction,
    required String userPrompt,
    int maxTokens = 50,
  }) async {
    return _mockResponse;
  }
}

class FakePremiumService extends Fake implements PremiumService {
  bool _isPremium = false;
  void setFakePremium(bool val) => _isPremium = val;

  @override
  Future<bool> isPremium() async => _isPremium;
}

void main() {
  late MotivationalEngine engine;
  late MockGrowthRepository mockRepo;
  late FakeNotificationService fakeNotifs;
  late FakePrivacyGptService fakeGpt;
  late FakePremiumService fakePremium;

  setUp(() async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    
    mockRepo = MockGrowthRepository();
    fakeNotifs = FakeNotificationService();
    fakeGpt = FakePrivacyGptService();
    fakePremium = FakePremiumService();

    engine = MotivationalEngine(
      repository: mockRepo,
      notifications: fakeNotifs,
      gptService: fakeGpt,
      premiumService: fakePremium,
    );
  });

  group('MotivationalEngine Logic', () {
    
    // Setup Helper
    void setupActiveGoal() {
      final goal = Goal(
        id: 1, 
        name: 'Test Goal', 
        createdAt: DateTime.now(),
        targetDeadline: DateTime.now().add(const Duration(days: 5)),
      );
      final task = GoalTask(
        id: 1,
        goalId: 1,
        title: 'Task 1',
        description: '',
        isCompleted: false,
        createdAt: DateTime.now(), estimatedMinutes: 60, priority: 'high'
      );
      
      mockRepo.setGoals([goal]);
      mockRepo.setTasks([task]);
    }

    test('1. Regular User receives Template Message', () async {
      setupActiveGoal();
      fakePremium.setFakePremium(false); // Regular User
      
      // Run with force=true to bypass time checks
      await engine.checkAndSchedule(force: true);
      
      expect(fakeNotifs.scheduled.length, 1);
      final notification = fakeNotifs.scheduled.first;
      
      // Templates contain specific phrases like "Rise and shine" or "New day"
      // Verify it is NOT null and comes from template engine
      expect(notification['body'], contains('Test Goal'));
    });

    test('2. Premium User receives AI Message', () async {
      setupActiveGoal();
      fakePremium.setFakePremium(true); // Premium User
      fakeGpt.setMockResponse("AI: Go crush Test Goal!"); // Expect this
      
      await engine.checkAndSchedule(force: true);
      
      expect(fakeNotifs.scheduled.length, 1);
      final notification = fakeNotifs.scheduled.first;
      
      // Verify body matches AI response exactly
      expect(notification['body'], "AI: Go crush Test Goal!");
    });

    test('3. No Notifications if No Active Goals', () async {
      mockRepo.setGoals([]); // No goals
      
      await engine.checkAndSchedule(force: true);
      
      expect(fakeNotifs.scheduled.isEmpty, true);
    });

    test('4. No Notifications if Goal is Completed', () async {
       final goal = Goal(
           id: 1, 
           name: 'Done Goal', 
           createdAt: DateTime.now()
       );
       final task = GoalTask(
         id: 1, goalId: 1, title: 'Done Task', isCompleted: true, // Completed!
         createdAt: DateTime.now(), estimatedMinutes: 60, priority: 'high', description: ''
       );
       
       mockRepo.setGoals([goal]);
       mockRepo.setTasks([task]);
       
       await engine.checkAndSchedule(force: true);
       
       expect(fakeNotifs.scheduled.isEmpty, true);
    });

  });
}
