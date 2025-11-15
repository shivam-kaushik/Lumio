import 'package:flutter/foundation.dart';
import '../../data/models/goal_subtask.dart';
import '../../data/models/goal.dart';
import '../../data/repositories/growth_repository.dart';

/// Service for adaptive rescheduling of missed tasks
class AdaptiveReschedulingService {
  final GrowthRepository _repository = GrowthRepository();

  /// Reschedule missed subtasks for a goal
  /// Returns list of rescheduled subtask IDs
  Future<List<int>> rescheduleMissedSubtasks(int goalId) async {
    final goal = await _repository.getGoal(goalId);
    if (goal == null) return [];

    final subtasks = await _repository.getSubtasksForGoal(goalId);
    final now = DateTime.now();
    final rescheduledIds = <int>[];

    for (var subtask in subtasks) {
      // Check if subtask is missed (past scheduled date and not completed)
      if (subtask.scheduledDate != null &&
          subtask.scheduledDate!.isBefore(now) &&
          !subtask.isCompleted) {
        // Calculate new scheduled date
        final newDate = _calculateNextAvailableDate(
          subtask,
          goal,
          now,
        );

        if (newDate != null) {
          // Update subtask with new scheduled date
          final updatedSubtask = subtask.copyWith(scheduledDate: newDate);
          await _repository.updateSubtask(updatedSubtask);
          rescheduledIds.add(subtask.id);

          debugPrint(
            '🔄 Rescheduled missed subtask "${subtask.title}" from ${subtask.scheduledDate} to $newDate',
          );
        }
      }
    }

    return rescheduledIds;
  }

  /// Calculate next available date for a missed subtask
  DateTime? _calculateNextAvailableDate(
    GoalSubtask subtask,
    Goal goal,
    DateTime now,
  ) {
    // Start from tomorrow
    var candidateDate = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));

    // If goal has a deadline, don't reschedule beyond it
    final maxDate = goal.targetDeadline ?? now.add(const Duration(days: 90));

    // Try to find a suitable date within the next 7 days
    for (var i = 0; i < 7 && candidateDate.isBefore(maxDate); i++) {
      // Check if this date works based on suggested time
      if (_isDateSuitable(candidateDate, subtask)) {
        // Set the time based on suggested time
        return _applySuggestedTime(candidateDate, subtask);
      }
      candidateDate = candidateDate.add(const Duration(days: 1));
    }

    // If no suitable date found in 7 days, use the first available date
    if (candidateDate.isBefore(maxDate)) {
      return _applySuggestedTime(candidateDate, subtask);
    }

    // If we've exceeded the deadline, schedule for the deadline
    if (goal.targetDeadline != null) {
      return _applySuggestedTime(goal.targetDeadline!, subtask);
    }

    return null;
  }

  /// Check if a date is suitable for the subtask
  bool _isDateSuitable(DateTime date, GoalSubtask subtask) {
    // For now, any weekday is suitable
    // Could be enhanced to check for weekends, holidays, etc.
    return true;
  }

  /// Apply suggested time to a date
  DateTime _applySuggestedTime(DateTime date, GoalSubtask subtask) {
    int hour = 9; // Default to 9 AM

    switch (subtask.suggestedTime) {
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

  /// Check for missed subtasks and optionally reschedule them
  Future<Map<String, dynamic>> checkAndRescheduleMissedTasks(
    int goalId, {
    bool autoReschedule = false,
  }) async {
    final goal = await _repository.getGoal(goalId);
    if (goal == null) {
      return {'missedCount': 0, 'rescheduledCount': 0};
    }

    final subtasks = await _repository.getSubtasksForGoal(goalId);
    final now = DateTime.now();
    final missedSubtasks = subtasks.where((subtask) {
      return subtask.scheduledDate != null &&
          subtask.scheduledDate!.isBefore(now) &&
          !subtask.isCompleted;
    }).toList();

    int rescheduledCount = 0;

    if (autoReschedule && missedSubtasks.isNotEmpty) {
      final rescheduledIds = await rescheduleMissedSubtasks(goalId);
      rescheduledCount = rescheduledIds.length;
    }

    return {
      'missedCount': missedSubtasks.length,
      'rescheduledCount': rescheduledCount,
      'missedSubtasks': missedSubtasks,
    };
  }
}

