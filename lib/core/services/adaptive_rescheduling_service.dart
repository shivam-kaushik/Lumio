import 'package:flutter/foundation.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/growth_repository.dart';

/// Service for adaptive rescheduling of missed tasks
class AdaptiveReschedulingService {
  final GrowthRepository _repository = GrowthRepository();

  /// Reschedule missed tasks for a goal
  /// Returns list of rescheduled task IDs
  Future<List<int>> rescheduleMissedTasks(int goalId) async {
    final goal = await _repository.getGoal(goalId);
    if (goal == null) return [];

    final tasks = await _repository.getTasksForGoal(goalId);
    final now = DateTime.now();
    final rescheduledIds = <int>[];

    for (var task in tasks) {
      if (task.scheduledDate != null &&
          task.scheduledDate!.isBefore(now) &&
          !task.isCompleted) {
        final newDate = _calculateNextAvailableDate(
          task,
          goal,
          now,
        );

        if (newDate != null) {
          final updatedTask = task.copyWith(scheduledDate: newDate);
          await _repository.updateTask(updatedTask);
          rescheduledIds.add(task.id);

          debugPrint(
            '🔄 Rescheduled missed task "${task.title}" from ${task.scheduledDate} to $newDate',
          );
        }
      }
    }

    return rescheduledIds;
  }

  DateTime? _calculateNextAvailableDate(
    GoalTask task,
    Goal goal,
    DateTime now,
  ) {
    var candidateDate = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));

    final maxDate = goal.targetDeadline ?? now.add(const Duration(days: 90));

    for (var i = 0; i < 7 && candidateDate.isBefore(maxDate); i++) {
      if (_isDateSuitable(candidateDate, task)) {
        return _applySuggestedTime(candidateDate, task);
      }
      candidateDate = candidateDate.add(const Duration(days: 1));
    }

    if (candidateDate.isBefore(maxDate)) {
      return _applySuggestedTime(candidateDate, task);
    }

    if (goal.targetDeadline != null) {
      return _applySuggestedTime(goal.targetDeadline!, task);
    }

    return null;
  }

  bool _isDateSuitable(DateTime date, GoalTask task) {
    // Placeholder for future logic (weekends, workload, etc.)
    return true;
  }

  DateTime _applySuggestedTime(DateTime date, GoalTask task) {
    int hour = 9; // Default to 9 AM

    switch (task.suggestedTime) {
      case 'morning':
        hour = 9;
        break;
      case 'afternoon':
        hour = 14;
        break;
      case 'evening':
        hour = 18;
        break;
      case 'any':
      default:
        hour = 9;
        break;
    }

    return DateTime(date.year, date.month, date.day, hour);
  }

  Future<Map<String, dynamic>> checkAndRescheduleMissedTasks(
    int goalId, {
    bool autoReschedule = false,
  }) async {
    final goal = await _repository.getGoal(goalId);
    if (goal == null) {
      return {'missedCount': 0, 'rescheduledCount': 0};
    }

    final tasks = await _repository.getTasksForGoal(goalId);
    final now = DateTime.now();
    final missedTasks = tasks.where((task) {
      return task.scheduledDate != null &&
          task.scheduledDate!.isBefore(now) &&
          !task.isCompleted;
    }).toList();

    int rescheduledCount = 0;

    if (autoReschedule && missedTasks.isNotEmpty) {
      final rescheduledIds = await rescheduleMissedTasks(goalId);
      rescheduledCount = rescheduledIds.length;
    }

    return {
      'missedCount': missedTasks.length,
      'rescheduledCount': rescheduledCount,
      'missedTasks': missedTasks,
    };
  }
}

