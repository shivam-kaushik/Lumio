
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_task.dart';
import 'package:lumio/presentation/utils/analytics_helper.dart';

void main() {
  group('History & Inbox Logic Tests', () {
    
    // Setup Mock Data
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    
    final dailyGoal = Goal(id: 1, name: 'Daily Plan - ${now.year}-${now.month}-${now.day}', createdAt: now);
    final inboxGoal = Goal(id: 999, name: 'Inbox', createdAt: now);
    final bizGoal = Goal(id: 100, name: 'Business Project', createdAt: now);

    final taskDaily = GoalTask(id: 1, goalId: 1, title: 'Plan Item', description: '', createdAt: now, scheduledDate: now);
    final taskInboxDated = GoalTask(id: 2, goalId: 999, title: 'Inbox Dated', description: '', createdAt: now, scheduledDate: now);
    final taskInboxCreated = GoalTask(id: 3, goalId: 999, title: 'Inbox Undated', description: '', createdAt: now, scheduledDate: null); // Implicitly Today
    final taskInboxYesterday = GoalTask(id: 4, goalId: 999, title: 'Inbox Old', description: '', createdAt: yesterday, scheduledDate: null); // Implicitly Yesterday
    final taskBiz = GoalTask(id: 5, goalId: 100, title: 'Biz Task', description: '', createdAt: now, scheduledDate: now);
    final taskOldButScheduled = GoalTask(id: 6, goalId: 999, title: 'Old but for Today', description: '', createdAt: yesterday, scheduledDate: now);
    final taskForYesterday = GoalTask(id: 7, goalId: 999, title: 'For Yesterday', description: '', createdAt: now, scheduledDate: yesterday);

    final allTasks = [taskDaily, taskInboxDated, taskInboxCreated, taskInboxYesterday, taskBiz];
    final goals = [dailyGoal, inboxGoal, bizGoal];

    // TEST 1: History Filtering Logic (Simulated)
    test('1. History should include Daily Plan AND Inbox', () {
      final relevantTasks = allTasks.where((t) {
             try {
               final goal = goals.firstWhere((g) => g.id == t.goalId);
               final name = goal.name;
               return name.startsWith("Daily Plan") || name == "Inbox";
             } catch (e) {
               return false;
             }
      }).toList();

      expect(relevantTasks.contains(taskDaily), true);
      expect(relevantTasks.contains(taskInboxDated), true);
      expect(relevantTasks.contains(taskBiz), false); // Exclude Business
    });

    // TEST 2: Analytics Helper Grouping
    test('2. Grouping should respect effective date (Scheduled > Created)', () {
      // taskInboxCreated has no scheduledDate, so it should map to createdAt (Today)
      // taskInboxYesterday has no scheduledDate, so it should map to createdAt (Yesterday)
      
      final groups = AnalyticsHelper.groupTasksByDate([taskInboxCreated, taskInboxYesterday]);
      
      // Keys are normalized dates
      final todayKey = DateTime(now.year, now.month, now.day);
      final yesterdayKey = DateTime(yesterday.year, yesterday.month, yesterday.day);

      expect(groups.containsKey(todayKey), true);
      expect(groups.containsKey(yesterdayKey), true);
      expect(groups[todayKey]!.first.title, 'Inbox Undated');
      expect(groups[yesterdayKey]!.first.title, 'Inbox Old');
    });

    // TEST 3: DayPlannerScreen Filtering Logic (Simulated)
    test('3. DayPlanner should capture Inbox Undated if Created Today', () {
      final selectedDate = now;
      
      final inboxForDay = [taskInboxCreated, taskInboxYesterday].where((t) {
           final dateToCheck = t.scheduledDate ?? t.createdAt; 
           return AnalyticsHelper.isSameDay(dateToCheck, selectedDate);
       }).toList();
       
       expect(inboxForDay.length, 1);
       expect(inboxForDay.first.title, 'Inbox Undated');
    });

    // TEST 4: DayPlanner should capture Inbox Scheduled Today (even if created yesterday)
    test('4. DayPlanner should capture Inbox Scheduled Today', () {
       final taskOldButScheduled = GoalTask(id: 6, goalId: 999, title: 'Old but for Today', description: '', createdAt: yesterday, scheduledDate: now);
       final selectedDate = now;

       final inboxForDay = [taskOldButScheduled].where((t) {
           final dateToCheck = t.scheduledDate ?? t.createdAt; 
           return AnalyticsHelper.isSameDay(dateToCheck, selectedDate);
       }).toList();

       expect(inboxForDay.length, 1);
    });

    // TEST 5: DayPlanner should exclude Inbox Scheduled Yesterday
    test('5. DayPlanner should exclude Inbox Scheduled Yesterday', () {
       final taskForYesterday = GoalTask(id: 7, goalId: 999, title: 'For Yesterday', description: '', createdAt: now, scheduledDate: yesterday);
       final selectedDate = now;

       final inboxForDay = [taskForYesterday].where((t) {
           final dateToCheck = t.scheduledDate ?? t.createdAt; 
           return AnalyticsHelper.isSameDay(dateToCheck, selectedDate);
       }).toList();

       expect(inboxForDay, isEmpty);
    });

  });
}
