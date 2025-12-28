
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:lumio/presentation/providers/growth_provider.dart';
import 'package:lumio/data/repositories/firestore_growth_repository.dart';
import 'package:lumio/core/services/notification_service.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mocks
class MockGrowthRepository extends Fake implements FirestoreGrowthRepository {
  List<Goal> _goals = [];
  List<GoalTask> _tasks = []; // Flat list for simulation

  void setGoals(List<Goal> goals) => _goals = goals;
  void setTasks(List<GoalTask> tasks) => _tasks = tasks;

  @override
  Future<List<Goal>> getGoals() async => _goals;

  @override
  Future<List<GoalTask>> getTasksForGoal(int goalId) async {
    return _tasks.where((t) => t.goalId == goalId).toList();
  }

  @override
  Future<int> createTask(GoalTask task) async {
    // Simulate creation
    final newId = _tasks.isEmpty ? 1 : _tasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
    final newTask = task.copyWith(id: newId);
    _tasks.add(newTask);
    return newId;
  }

  @override
  Future<int> completeTask(int taskId) async {
     final index = _tasks.indexWhere((t) => t.id == taskId);
     if (index != -1) {
       _tasks[index] = _tasks[index].copyWith(isCompleted: true, completedAt: DateTime.now());
     }
     return taskId;
  }
  
  @override
  Future<int> updateTask(GoalTask task) async {
     final index = _tasks.indexWhere((t) => t.id == task.id);
     if (index != -1) {
       _tasks[index] = task;
     }
     return 1;
  }
}

class FakeNotificationService extends Fake implements NotificationService {
  final List<Map<String, dynamic>> scheduled = [];
  final List<int> canceled = [];

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    scheduled.add({
      'id': id,
      'title': title,
      'time': scheduledTime,
    });
  }

  @override
  Future<void> cancelNotification(int id) async {
    canceled.add(id);
  }
}

void main() {
  late GrowthProvider provider;
  late MockGrowthRepository mockRepo;
  late FakeNotificationService fakeNotifs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    
    mockRepo = MockGrowthRepository();
    fakeNotifs = FakeNotificationService();
    
    provider = GrowthProvider(
      repository: mockRepo,
      notificationService: fakeNotifs,
    );
  });

  test('Completing a DAILY task should create a new task for tomorrow', () async {
    // 1. Setup Data
    final goal = Goal(id: 1, name: 'Test Goal', createdAt: DateTime.now());
    final today = DateTime.now();
    final task = GoalTask(
      id: 100,
      goalId: 1,
      title: 'Daily Task',
      description: '',
      createdAt: today,
      scheduledDate: today,
      frequency: 'daily',
      priority: 'medium',
    );

    mockRepo.setGoals([goal]);
    // Load Data
    await provider.loadGrowthData();
    expect(provider.goals.length, 1);

    // Create Task via Provider (populates cache)
    final id = await provider.createTask(task);
    expect(provider.tasksByGoal[1]!.length, 1);

    // 2. Complete Task
    await provider.completeTask(id);

    // 3. Verify
    // Original task completes
    final completedTask = (await mockRepo.getTasksForGoal(1)).firstWhere((t) => t.id == id);
    expect(completedTask.isCompleted, true);

    // NEW TASK should exist
    final allTasks = await mockRepo.getTasksForGoal(1);
    expect(allTasks.length, 2, reason: "Should have created a new recurring task");
    
    final newTask = allTasks.firstWhere((t) => t.id != id);
    expect(newTask.isCompleted, false);
    expect(newTask.title, 'Daily Task');
    expect(newTask.frequency, 'daily');
    
    // Check Date: Should be roughly tomorrow
    final tomorrow = today.add(const Duration(days: 1));
    final diff = newTask.scheduledDate!.difference(tomorrow).inMinutes.abs();
    expect(diff, closeTo(0, 5), reason: "Scheduled date should be tomorrow"); // Allow 5 min buffer logic
  });

  test('Completing a WEEKLY task should create a new task for next week', () async {
    final goal = Goal(id: 1, name: 'Goal', createdAt: DateTime.now());
    final today = DateTime.now();
    final task = GoalTask(
      id: 200,
      goalId: 1,
      title: 'Weekly Task',
      description: '',
      createdAt: today,
      scheduledDate: today,
      frequency: 'weekly',
    );

    mockRepo.setGoals([goal]);
    // Load Data
    await provider.loadGrowthData();
    // Create Task
    final id = await provider.createTask(task);

    await provider.completeTask(id);

    final allTasks = await mockRepo.getTasksForGoal(1);
    expect(allTasks.length, 2);
    
    final newTask = allTasks.firstWhere((t) => t.id != id);
    final nextWeek = today.add(const Duration(days: 7));
    final diff = newTask.scheduledDate!.difference(nextWeek).inMinutes.abs();
    expect(diff, closeTo(0, 5));
  });

  test('Completing a ONE-TIME task should NOT create a new task', () async {
    final goal = Goal(id: 1, name: 'Goal', createdAt: DateTime.now());
    final task = GoalTask(
      id: 300,
      goalId: 1,
      title: 'Once Task',
      description: '',
      createdAt: DateTime.now(),
      scheduledDate: DateTime.now(),
      frequency: 'one-time',
    );

    mockRepo.setGoals([goal]);
    await provider.loadGrowthData();
    final id = await provider.createTask(task);

    await provider.completeTask(id);

    final allTasks = await mockRepo.getTasksForGoal(1);
    expect(allTasks.length, 1); // Only the completed one
    expect(allTasks.first.isCompleted, true);
  });
}
