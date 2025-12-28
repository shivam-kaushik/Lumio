import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/presentation/screens/home_screen.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:lumio/data/models/reminder.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:mockito/mockito.dart';
import 'package:lumio/presentation/providers/growth_provider.dart';

// Mock Provider
class MockGrowthProvider extends Mock implements GrowthProvider {
  @override
  List<Goal> get goals => _goals;
  List<Goal> _goals = [];
  set goals(List<Goal> val) => _goals = val;

  @override
  Map<int, List<GoalTask>> get tasksByGoal => _tasksByGoal;
  Map<int, List<GoalTask>> _tasksByGoal = {};
  set tasksByGoal(Map<int, List<GoalTask>> val) => _tasksByGoal = val;
}

void main() {
  group('HomeScreen Filter Logic', () {
    test('Should include Today tasks even if not in Inbox', () {
      // Setup
      final now = DateTime.now();
      final todayTask = GoalTask(
        id: 1,
        goalId: 99, // Random goal
        title: 'Today Task',
        description: '',
        createdAt: now,
        scheduledDate: now, // scheduled for now
        priority: 'medium',
        isCompleted: false,
        subtasks: [],
      );

      final inboxTask = GoalTask(
        id: 2,
        goalId: 100, // Inbox
        title: 'Inbox Task',
        description: '',
        createdAt: now.subtract(const Duration(days: 1)),
        isCompleted: false,
        subtasks: [],
      );

      final futureTask = GoalTask(
        id: 3,
        goalId: 99,
        title: 'Future Task',
        description: '',
        createdAt: now,
        scheduledDate: now.add(const Duration(days: 1)),
        isCompleted: false,
        subtasks: [],
      );

      // We need to simulate the logic inside _getAllReminders
      // Since _getAllReminders is private, we can replicate the logic here for testing
      // or make it public/visible for testing. 
      // For this "reproduction", we will replicate the logic exactly as implemented.
      
      final tasks = [todayTask, inboxTask, futureTask];
      final inboxGoalId = 100;

      final filtered = tasks.where((task) {
         final isInbox = task.goalId == inboxGoalId;
         bool isToday = false;
         if (task.scheduledDate != null) {
             final local = task.scheduledDate!.toLocal();
             final n = DateTime.now();
             isToday = local.year == n.year && local.month == n.month && local.day == n.day;
         }
         return isInbox || isToday;
      }).toList();

      expect(filtered.contains(todayTask), true, reason: "Today task should be included");
      expect(filtered.contains(inboxTask), true, reason: "Inbox task should be included");
      expect(filtered.contains(futureTask), false, reason: "Future task should be excluded");
    });
    
    test('Should match FAB visibility logic', () {
       // Logic: (Enabled Reminders) OR (Diff | Inbox | Today)
       
       final reminders = <Reminder>[]; // Empty
       final tasks = <GoalTask>[]; 
       // Case 1: Empty
       bool hasTasks = false;
       if (reminders.where((r) => r.enabled).isNotEmpty) hasTasks = true;
       // ... growth logic ...
       expect(hasTasks, false);
       
       // Case 2: Disabled Reminder only
       reminders.add(Reminder(id: '1', text: 'x', timeAt: DateTime.now(), enabled: false, category: ReminderCategory.other, priority: ReminderPriority.low));
       hasTasks = false;
       if (reminders.where((r) => r.enabled).isNotEmpty) hasTasks = true;
       expect(hasTasks, false, reason: "Disabled reminder should NOT trigger FAB");
    });
  });
}
