import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/reminder.dart';
import '../../data/models/context_event.dart';
import '../../data/repositories/firestore_reminder_repository.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_time_utils.dart';
import 'notification_service.dart';
import 'activity_recognition_service.dart';
import 'privacy_gpt_service.dart';

/// Context trigger engine that monitors sensors and triggers reminders
/// Supports time-based and activity-based triggers
class TriggerEngine {
  final FirestoreReminderRepository _reminderRepository;
  final NotificationService _notificationService;
  final ActivityRecognitionService _activityService = ActivityRecognitionService();
  final FirestoreGrowthRepository _growthRepository = FirestoreGrowthRepository();
  final PrivacyGptService _privacyGpt = PrivacyGptService();

  String? _previousActivity;

  TriggerEngine({
    required FirestoreReminderRepository reminderRepository,
    required NotificationService notificationService,
  })  : _reminderRepository = reminderRepository,
        _notificationService = notificationService;

  /// Start monitoring context (activity)
  Future<void> startMonitoring() async {
    await _startActivityMonitoring();
  }

  /// Stop monitoring context
  Future<void> stopMonitoring() async {
    await _activityService.stopMonitoring();
  }

  /// Start monitoring device activity
  Future<void> _startActivityMonitoring() async {
    if (kDebugMode) {
      print('🏃 TriggerEngine: Starting activity monitoring...');
    }

    await _activityService.startMonitoring(
      onActivityChanged: (activity) {
        if (kDebugMode) {
          print('🏃 TriggerEngine: Activity changed callback received');
        }
        _checkActivityReminders();
      },
    );

    // Initial check
    _previousActivity = _activityService.getActivityName(_activityService.currentActivity);
    if (kDebugMode) {
      print('🏃 TriggerEngine: Initial activity: $_previousActivity');
    }
    _checkActivityReminders();

    if (kDebugMode) {
      print('✅ TriggerEngine: Activity monitoring started');
    }
  }

  /// Check activity-based reminders
  Future<void> _checkActivityReminders() async {
    final currentActivityName = _activityService.getActivityName(_activityService.currentActivity);

    if (kDebugMode) {
      print('🏃 TriggerEngine: Checking activity reminders (current: $currentActivityName, previous: $_previousActivity)');
    }

    if (currentActivityName == _previousActivity) {
      if (kDebugMode) {
        print('🏃 TriggerEngine: Activity unchanged, skipping check');
      }
      return; // No change
    }

    if (kDebugMode) {
      print('🔄 TriggerEngine: Activity changed: $_previousActivity -> $currentActivityName');
    }

    final reminders = await _reminderRepository.getActiveReminders();
    if (kDebugMode) {
      print('🏃 TriggerEngine: Checking ${reminders.length} active reminders for activity triggers');
    }

    int checkedCount = 0;
    int matchedCount = 0;

    for (var reminder in reminders) {
      if (reminder.activityType == null) continue;
      checkedCount++;

      // Normalize activity names for comparison
      final reminderActivity = reminder.activityType!.toLowerCase();
      final currentActivityLower = currentActivityName.toLowerCase();

      // Map activity names (handle variations)
      final activityMap = {
        'still': 'stationary',
        'stationary': 'still',
        'walking': 'walking',
        'running': 'running',
        'onbicycle': 'cycling',
        'cycling': 'onbicycle',
        'invehicle': 'driving',
        'driving': 'invehicle',
        'onfoot': 'walking',
      };

      final normalizedReminder = activityMap[reminderActivity] ?? reminderActivity;
      final normalizedCurrent = activityMap[currentActivityLower] ?? currentActivityLower;

      // Check if current activity matches reminder's trigger activity
      if (normalizedReminder == normalizedCurrent ||
          reminderActivity == currentActivityLower ||
          currentActivityLower.contains(reminderActivity) ||
          reminderActivity.contains(currentActivityLower)) {
        matchedCount++;
        if (kDebugMode) {
          print('✅ TriggerEngine: Activity match found!');
          print('   Reminder: "${reminder.text}"');
          print('   Reminder activity: ${reminder.activityType}');
          print('   Current activity: $currentActivityName');
          print('   Normalized match: $normalizedReminder == $normalizedCurrent');
        }
        await _triggerReminder(reminder, 'activity');
      }
    }

    if (kDebugMode) {
      print('🏃 TriggerEngine: Activity check complete');
      print('   Checked reminders: $checkedCount');
      print('   Matched reminders: $matchedCount');
      print('   Previous activity: $_previousActivity');
      print('   New activity: $currentActivityName');
    }

    _previousActivity = currentActivityName;
  }

  /// Check time-based reminders (called periodically)
  Future<void> checkTimeReminders() async {
    final reminders = await _reminderRepository.getActiveReminders();
    final now = DateTime.now();

    for (var reminder in reminders) {
      if (reminder.timeAt == null) continue;

      final timeDiff = reminder.timeAt!.difference(now).inMinutes.abs();
      if (timeDiff <= 1) {
        await _triggerReminder(reminder, AppConstants.contextTypeTime);
      }
    }
  }

  /// Run periodic checks (time + activity)
  Future<void> runBackgroundChecks() async {
    if (kDebugMode) {
      print('⏰ Running background checks...');
    }

    await checkTimeReminders();

    // Check activity-based reminders
    await _checkActivityReminders();
  }

  Future<void> _triggerReminder(Reminder reminder, String contextType) async {
    if (kDebugMode) {
      print('');
      print('🔔═══════════════════════════════════════════════════');
      print('🔔 TRIGGER ENGINE: Triggering Reminder');
      print('🔔═══════════════════════════════════════════════════');
      print('   Reminder ID: ${reminder.id}');
      print('   Text: "${reminder.text}"');
      print('   Context Type: $contextType');
      print('   Time: ${DateTime.now()}');
    }

    await _reminderRepository.updateTriggerStats(reminder.id);
    if (kDebugMode) {
      print('✅ Trigger stats updated');
    }

    // Store activity context in metadata if available
    final currentActivity = _activityService.currentActivity;
    final activityName = currentActivity != null
        ? _activityService.getActivityName(currentActivity).toLowerCase()
        : null;

    if (kDebugMode && activityName != null) {
      print('🏃 Activity context: $activityName');
    }

    final event = ContextEvent(
      reminderId: reminder.id,
      contextType: contextType,
      outcome: AppConstants.outcomeMissed,
      metadata: activityName != null
          ? {'activity_type': activityName}
          : null,
    );
    await _reminderRepository.createContextEvent(event);
    if (kDebugMode) {
      print('✅ Context event created');
    }

    // Show notification
    if (kDebugMode) {
      print('📱 Showing notification...');
    }

    // Create payload for notification
    String payload;
    String title;
    String body;

    // Get goal name if reminder is linked to a goal
    String? goalName;
    if (reminder.linkedGoalId != null) {
      final goal = await _growthRepository.getGoal(reminder.linkedGoalId!);
      goalName = goal?.name;
    }

    // Generate motivational message if linked to goal
    if (goalName != null) {
      try {
        // Ensure initialized or try-catch the entire block
        final motivationalMessage = await _privacyGpt.generateMotivationalMessage(
          goalName: goalName,
          taskDescription: reminder.text,
          motivationAnchor: null,
        );

        title = '🚀 Task Time!';
        body = motivationalMessage ?? reminder.text;
      } catch (e) {
        debugPrint('⚠️ Error generating motivational message (using fallback): $e');
        title = 'Task';
        body = reminder.text;
      }
    } else {
      title = 'Task';
      body = reminder.text;
    }

    payload = '{"action":"complete","reminder_id":"${reminder.id}","title":"${title.replaceAll('"', '\\"')}","body":"${body.replaceAll('"', '\\"')}"}';

    await _notificationService.showNotification(
      id: reminder.id.hashCode,
      title: title,
      body: body,
      payload: payload,
    );
    if (kDebugMode) {
      print('✅ Notification shown');
      print('🔔═══════════════════════════════════════════════════');
      print('');
    }

    // If recurring reminder, calculate and schedule next occurrence
    if (reminder.isRecurring && reminder.repeatInterval != null && reminder.repeatUnit != null) {
      final now = DateTime.now();
      final nextTime = DateTimeUtils.calculateNextOccurrence(
        now,
        reminder.repeatInterval!,
        reminder.repeatUnit!,
        repeatOnDays: reminder.repeatOnDays,
        timeAt: reminder.timeAt,
      );

      if (nextTime != null && (reminder.repeatEndDate == null || nextTime.isBefore(reminder.repeatEndDate!))) {
        // Update reminder with next occurrence time
        final updatedReminder = reminder.copyWith(timeAt: nextTime);
        await _reminderRepository.updateReminder(updatedReminder);

        // Schedule notification for next occurrence
        // Create payload for next occurrence
        String payload;
        String title = 'Task';
        String body = reminder.text;

        payload = '{"action":"complete","reminder_id":"${reminder.id}","title":"${title.replaceAll('"', '\\"')}","body":"${body.replaceAll('"', '\\"')}"}';

        await _notificationService.scheduleNotification(
          id: reminder.id.hashCode,
          title: title,
          body: body,
          scheduledTime: nextTime,
          payload: payload,
        );

        if (kDebugMode) {
          print('✅ Rescheduled recurring reminder "${reminder.text}" for ${nextTime}');
        }
      } else if (reminder.repeatEndDate != null && nextTime != null && nextTime.isAfter(reminder.repeatEndDate!)) {
        // Recurrence ended, disable reminder
        await _reminderRepository.toggleReminder(reminder.id, false);
        if (kDebugMode) {
          print('⏸️ Recurring reminder "${reminder.text}" ended (past end date)');
        }
      }
    }

    // If constant reminder, schedule next notification in 5 minutes
    if (reminder.keepRemindingUntilCompleted) {
      final constantNow = DateTime.now();
      final nextTime = constantNow.add(const Duration(minutes: 5));
      await _notificationService.scheduleNotification(
        id: reminder.id.hashCode,
        title: 'Task',
        body: reminder.text,
        scheduledTime: nextTime,
        payload: reminder.id,
      );
      if (kDebugMode) {
        print('🔄 Scheduled constant reminder "${reminder.text}" for 5 minutes later');
      }
    }
  }

  /// Manual trigger for testing
  Future<void> testTrigger(Reminder reminder) async {
    await _triggerReminder(reminder, 'manual');
  }
}
