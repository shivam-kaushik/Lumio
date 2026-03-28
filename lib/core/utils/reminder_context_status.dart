import '../../data/models/reminder.dart';

/// Context status information for a reminder
class ReminderContextStatus {
  final Reminder reminder;
  final bool isReady; // Conditions are currently met
  final String statusText; // Human-readable status
  final String? currentActivity;

  ReminderContextStatus({
    required this.reminder,
    required this.isReady,
    required this.statusText,
    this.currentActivity,
  });

  /// Get status icon
  String getStatusIcon() {
    if (isReady) return '✅';
    return '🔔';
  }

  /// Format distance for display (kept for compatibility, returns empty)
  String getFormattedDistance() {
    return '';
  }
}

/// Utility class for calculating reminder context status
class ReminderStatusCalculator {
  /// Calculate context status for a list of reminders
  static Future<List<ReminderContextStatus>> calculateStatuses(
    List<Reminder> reminders, {
    dynamic currentPosition, // Kept for API compatibility
    String? currentActivity,
  }) async {
    final statuses = <ReminderContextStatus>[];

    for (var reminder in reminders) {
      final status = await calculateStatus(
        reminder,
        currentActivity: currentActivity,
      );
      statuses.add(status);
    }

    return statuses;
  }

  /// Calculate context status for a single reminder
  static Future<ReminderContextStatus> calculateStatus(
    Reminder reminder, {
    dynamic currentPosition, // Kept for API compatibility
    String? currentActivity,
  }) async {
    bool isReady = false;
    String statusText = 'Waiting for context';

    // Check activity-based conditions
    if (reminder.activityType != null && currentActivity != null) {
      final matchesActivity = currentActivity.toLowerCase() ==
          reminder.activityType!.toLowerCase();
      if (matchesActivity) {
        isReady = true;
        statusText = 'Activity detected: $currentActivity - Ready';
      } else {
        statusText = 'Waiting for activity: ${reminder.activityType}';
      }
    }

    // Check time-based conditions
    if (reminder.activityType == null) {
      if (reminder.timeAt != null) {
        final now = DateTime.now();
        final timeDiff = reminder.timeAt!.difference(now);
        if (timeDiff.inMinutes <= 5 && timeDiff.inMinutes >= 0) {
          isReady = true;
          statusText = 'Upcoming in ${timeDiff.inMinutes} min';
        } else if (timeDiff.inMinutes < 0) {
          statusText = 'Overdue';
        } else {
          statusText = 'Scheduled for later';
        }
      } else {
        statusText = 'No trigger conditions';
      }
    }

    return ReminderContextStatus(
      reminder: reminder,
      isReady: isReady,
      statusText: statusText,
      currentActivity: currentActivity,
    );
  }

  /// Group reminders by context with status
  static Future<Map<String, List<ReminderContextStatus>>> groupByLocationWithStatus(
    List<Reminder> reminders, {
    dynamic currentPosition,
    String? currentActivity,
  }) async {
    final statuses = await calculateStatuses(
      reminders,
      currentActivity: currentActivity,
    );

    final groups = <String, List<ReminderContextStatus>>{};

    for (var status in statuses) {
      groups.putIfAbsent('Other', () => []).add(status);
    }

    return groups;
  }
}
