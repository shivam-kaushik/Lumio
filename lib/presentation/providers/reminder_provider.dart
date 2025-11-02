import 'package:flutter/foundation.dart';

import '../../data/models/reminder.dart';
import '../../data/models/context_event.dart';
import '../../data/models/reminder_occurrence.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../core/services/alarm_service.dart';
import '../../core/services/nlu_parser.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/learning_service.dart';
import '../../core/constants/app_constants.dart';

/// Reminder state management provider
class ReminderProvider with ChangeNotifier {
  final ReminderRepository _reminderRepository;
  late final LearningService _learningService;

  List<Reminder> _reminders = [];
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _statistics;

  ReminderProvider({
    required ReminderRepository reminderRepository,
  }) : _reminderRepository = reminderRepository {
    _learningService = LearningService(reminderRepository);
  }

  // Getters
  List<Reminder> get reminders => _reminders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get statistics => _statistics;

  List<Reminder> get activeReminders =>
      _reminders.where((r) => r.enabled).toList();

  int get reminderCount => _reminders.length;
  int get activeReminderCount => activeReminders.length;

  /// Load all reminders
  Future<void> loadReminders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _reminders = await _reminderRepository.getAllReminders();
      await loadStatistics();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create reminder from text (using NLU parser)
  Future<String?> createReminderFromText(String text) async {
    try {
      // Validate intent
      if (!NLUParser.hasValidIntent(text)) {
        _error = 'Please provide a clear task description';
        notifyListeners();
        return null;
      }

      // Parse text using NLU
      final reminder = NLUParser.parseReminderText(text);

      // Save to database
      final id = await _reminderRepository.createReminder(reminder);

      // Schedule notification(s)
      if (reminder.timeAt != null) {
        if (reminder.isRecurring) {
          // Schedule multiple occurrences for recurring reminders
          await _scheduleRecurringNotifications(reminder);
        } else {
          // Schedule single notification using native AlarmManager
          await AlarmService.scheduleExactAlarm(
            id: reminder.id.hashCode,
            title: 'Reminder',
            body: reminder.text,
            scheduledTime: reminder.timeAt!,
            payload: reminder.id,
          );
          debugPrint(
              'Scheduled alarm for reminder ${reminder.id} at ${reminder.timeAt} (id=${reminder.id.hashCode})',);
        }
      }

      // Reload reminders
      await loadReminders();

      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Create reminder (manual)
  Future<String?> createReminder(Reminder reminder) async {
    try {
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('📝 CREATING NEW REMINDER');
      debugPrint('═══════════════════════════════════════════════════');
      
      // Debug: Log reminder details before saving
      debugPrint('📋 Reminder Details:');
      debugPrint('   ID: ${reminder.id}');
      debugPrint('   Text: "${reminder.text}"');
      debugPrint('   TimeAt: ${reminder.timeAt}');
      debugPrint('   Enabled: ${reminder.enabled}');
      debugPrint('   IsRecurring: ${reminder.isRecurring}');
      debugPrint('   RepeatInterval: ${reminder.repeatInterval}');
      debugPrint('   RepeatUnit: ${reminder.repeatUnit}');
      debugPrint('   RepeatOnDays: ${reminder.repeatOnDays}');
      debugPrint('   RepeatEndDate: ${reminder.repeatEndDate}');
      debugPrint('   KeepRemindingUntilCompleted: ${reminder.keepRemindingUntilCompleted}');

      debugPrint('');
      debugPrint('💾 Saving reminder to database...');
      final id = await _reminderRepository.createReminder(reminder);
      debugPrint('✅ Reminder saved with ID: $id');
      debugPrint('');

      // Check exact alarm permission (Android only, iOS always returns true)
      debugPrint('🔐 Checking exact alarm permission...');
      final hasPermission = await PermissionService().hasExactAlarmPermission();
      if (!hasPermission) {
        debugPrint('⚠️⚠️⚠️ WARNING: EXACT ALARM PERMISSION NOT GRANTED! ⚠️⚠️⚠️');
        debugPrint('   Notifications may not work reliably!');
        debugPrint('   User needs to grant permission:');
        debugPrint('   Settings → Apps → Awarely → Alarms & Reminders');
      } else {
        debugPrint('✅ Exact alarm permission granted (or not required on this platform)');
      }
      debugPrint('');

      // Apply smart timing if enabled
      DateTime? finalTimeAt = reminder.timeAt;
      if (reminder.useSmartTiming && reminder.timeAt != null) {
        debugPrint('');
        debugPrint('🧠 Applying Smart Timing...');
        final adjustedTime = await _learningService.getAdjustedTime(reminder.id, reminder.timeAt!);
        if (adjustedTime != null) {
          debugPrint('   Original time: ${reminder.timeAt}');
          debugPrint('   Adjusted time: $adjustedTime');
          finalTimeAt = adjustedTime;
          
          // Update reminder with adjusted time
          final updatedReminder = reminder.copyWith(timeAt: adjustedTime);
          await _reminderRepository.updateReminder(updatedReminder);
        } else {
          debugPrint('   No learning pattern yet - using original time');
        }
        debugPrint('');
      }

      // Schedule notifications
      if (finalTimeAt != null) {
        debugPrint('📅 TimeAt is set, scheduling notifications...');
        debugPrint('   TimeAt value: $finalTimeAt');
        
        // Create reminder with adjusted time if smart timing was applied
        final reminderToSchedule = finalTimeAt != reminder.timeAt
            ? reminder.copyWith(timeAt: finalTimeAt)
            : reminder;
        
        if (reminderToSchedule.isRecurring) {
          debugPrint('   Type: Recurring reminder');
          debugPrint('   Will call _scheduleRecurringNotifications()');
          // Schedule multiple occurrences for recurring reminders
          await _scheduleRecurringNotifications(reminderToSchedule);
        } else {
          debugPrint('   Type: One-time reminder');
          // Schedule single notification for one-time reminders
          final now = DateTime.now();
          final scheduleTime = finalTimeAt;

          // Validate time is in future
          if (scheduleTime.isAfter(now)) {
            debugPrint('📅 Creating reminder: ${reminder.text}');
            debugPrint('🕐 Scheduled for: $scheduleTime');
            debugPrint('⏰ Time from now: ${scheduleTime.difference(now)}');

            // Create occurrence record for one-time reminder
            final notificationId = reminder.id.hashCode;
            final occurrence = ReminderOccurrence(
              reminderId: reminder.id,
              scheduledTime: scheduleTime,
              notificationId: notificationId,
              isCompleted: false,
            );
            await _reminderRepository.createReminderOccurrence(occurrence);
            debugPrint('   ✅ Occurrence record created for one-time reminder');

            await AlarmService.scheduleExactAlarm(
              id: notificationId,
              title: 'Reminder',
              body: reminder.text,
              scheduledTime: scheduleTime,
              payload: reminder.id,
            );

            debugPrint('✅ Alarm scheduled');
      } else {
        debugPrint('⚠️⚠️⚠️ WARNING: SCHEDULED TIME IS IN THE PAST! ⚠️⚠️⚠️');
        debugPrint('   Scheduled: $scheduleTime');
        debugPrint('   Now: $now');
        debugPrint('   Difference: ${scheduleTime.difference(now)}');
            debugPrint('   Notification will NOT be scheduled');
      }
        }
      } else if (reminder.isRecurring) {
        // For recurring reminders without timeAt, calculate first occurrence from today
        debugPrint('⚠️ TimeAt is NULL for recurring reminder, calculating first occurrence from today');
        
        final now = DateTime.now();
        Duration interval;
        
        if (reminder.repeatInterval != null && reminder.repeatUnit != null) {
          switch (reminder.repeatUnit) {
            case 'minutes':
              interval = Duration(minutes: reminder.repeatInterval!);
              break;
            case 'hours':
              interval = Duration(hours: reminder.repeatInterval!);
              break;
            case 'days':
              interval = Duration(days: reminder.repeatInterval!);
              break;
            case 'weeks':
              interval = Duration(days: reminder.repeatInterval! * 7);
              break;
            default:
              interval = Duration(minutes: reminder.repeatInterval!);
          }
          
          final firstOccurrence = now.add(interval);
          debugPrint('   Calculated first occurrence from today: $firstOccurrence');
          
          // Update reminder with calculated timeAt
          final updatedReminder = reminder.copyWith(timeAt: firstOccurrence);
          await _reminderRepository.updateReminder(updatedReminder);
          
          // Schedule recurring notifications
          await _scheduleRecurringNotifications(updatedReminder);
          debugPrint('   ✅ Recurring reminder scheduled starting from today');
        } else {
          debugPrint('⚠️ Recurring reminder missing interval/unit - cannot schedule');
        }
      } else {
        debugPrint('⚠️ TimeAt is NULL - no notification will be scheduled');
        debugPrint('   Reminder will be saved but won\'t trigger');
      }

      // Learn from this reminder after creation (async, don't wait)
      if (reminder.useSmartTiming) {
        _learningService.learnOptimalTiming(reminder.id).then((result) {
          if (result != null && kDebugMode) {
            debugPrint('🧠 Learned optimal timing for "${reminder.text}": ${result['optimalHour']}:00');
          }
        });
      }

      debugPrint('');
      debugPrint('📥 Reloading reminders list...');
      await loadReminders();
      debugPrint('✅ Reminder creation complete!');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('');
      return id;
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error creating reminder: $e');
      notifyListeners();
      return null;
    }
  }

  /// Schedule multiple notifications for recurring reminders
  /// Schedules next 24 hours (or up to 50 occurrences, whichever is less)
  Future<void> _scheduleRecurringNotifications(Reminder reminder) async {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔁 SCHEDULING RECURRING REMINDER');
    debugPrint('═══════════════════════════════════════════════════');
    
    if (!reminder.isRecurring) {
      debugPrint('❌ Reminder is not marked as recurring (isRecurring=false)');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('');
      return;
    }
    
    if (reminder.repeatInterval == null) {
      debugPrint('❌ Repeat interval is null');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('');
      return;
    }
    
    if (reminder.repeatUnit == null) {
      debugPrint('❌ Repeat unit is null');
      debugPrint('═══════════════════════════════════════════════════');
      debugPrint('');
      return;
    }

    debugPrint('📝 Reminder Details:');
    debugPrint('   ID: ${reminder.id}');
    debugPrint('   Text: ${reminder.text}');
    debugPrint('   Enabled: ${reminder.enabled}');
    debugPrint('   IsRecurring: ${reminder.isRecurring}');
    debugPrint('   RepeatInterval: ${reminder.repeatInterval}');
    debugPrint('   RepeatUnit: ${reminder.repeatUnit}');
    debugPrint('   TimeAt: ${reminder.timeAt}');
    debugPrint('   RepeatOnDays: ${reminder.repeatOnDays}');
    debugPrint('   RepeatEndDate: ${reminder.repeatEndDate}');

    // Calculate interval duration
    Duration interval;
    switch (reminder.repeatUnit) {
      case 'minutes':
        interval = Duration(minutes: reminder.repeatInterval!);
        debugPrint('   Calculated interval: ${interval.inMinutes} minutes');
        break;
      case 'hours':
        interval = Duration(hours: reminder.repeatInterval!);
        debugPrint('   Calculated interval: ${interval.inHours} hours');
        break;
      case 'days':
        interval = Duration(days: reminder.repeatInterval!);
        debugPrint('   Calculated interval: ${interval.inDays} days');
        break;
      case 'weeks':
        interval = Duration(days: reminder.repeatInterval! * 7);
        debugPrint('   Calculated interval: ${interval.inDays} days (${reminder.repeatInterval} weeks)');
        break;
      default:
        interval = Duration(minutes: reminder.repeatInterval!);
        debugPrint('   Calculated interval: ${interval.inMinutes} minutes (default)');
    }

    // Schedule up to 50 occurrences or 24 hours, whichever comes first
    final now = DateTime.now();
    final maxTime = now.add(const Duration(hours: 24));
    int count = 0;
    const maxOccurrences = 50;

    // Determine starting time for first occurrence
    DateTime nextOccurrence;
    if (reminder.timeAt != null) {
      // Check if the parsed time is still valid
      final timeUntilFirst = reminder.timeAt!.difference(now);
      debugPrint('   Parsed timeAt: ${reminder.timeAt}');
      debugPrint('   Time until first: ${timeUntilFirst.inSeconds} seconds');
      debugPrint('   Current time: $now');
      
      if (timeUntilFirst.isNegative) {
        // Time is in the past - start immediately (1 second) then continue
        debugPrint('⏰ Parsed time is in past, starting immediately then continuing');
        nextOccurrence = now.add(const Duration(seconds: 1));
      } else if (timeUntilFirst.inSeconds < 1) {
        // Less than 1 second - bump to 1 second minimum (AlarmService requirement)
        debugPrint('⏰ Time too close (< 1s), setting to 1 second');
        nextOccurrence = now.add(const Duration(seconds: 1));
      } else {
        // Use the parsed time as-is (could be 10 seconds for "starting now")
        nextOccurrence = reminder.timeAt!;
        debugPrint('✅ Using parsed time: $nextOccurrence');
      }
    } else {
      // No time specified - start from today with the interval
      // For recurring reminders without a specific time, start from now
      debugPrint('⏰ No timeAt specified, starting from today');
      
      // Calculate next occurrence from now based on interval
      DateTime next;
      switch (reminder.repeatUnit) {
        case 'minutes':
          next = now.add(Duration(minutes: reminder.repeatInterval!));
          break;
        case 'hours':
          next = now.add(Duration(hours: reminder.repeatInterval!));
          break;
        case 'days':
          next = now.add(Duration(days: reminder.repeatInterval!));
          break;
        case 'weeks':
          next = now.add(Duration(days: reminder.repeatInterval! * 7));
          break;
        default:
          next = now.add(Duration(minutes: reminder.repeatInterval!));
      }
      
      // Ensure at least 1 second in the future
      nextOccurrence = next.isBefore(now.add(const Duration(seconds: 1)))
          ? now.add(const Duration(seconds: 1))
          : next;
      
      debugPrint('   Calculated next occurrence from today: $nextOccurrence');
    }

    // Final safety check: ensure first occurrence is at least 1 second in the future
    final finalCheck = nextOccurrence.difference(now);
    if (finalCheck.inSeconds < 1) {
      debugPrint('⏰ Final adjustment: first occurrence was too close, setting to 1 second');
      nextOccurrence = now.add(const Duration(seconds: 1));
    }

    debugPrint('');
    debugPrint('📅 SCHEDULING OCCURRENCES:');
    debugPrint('   First occurrence: $nextOccurrence');
    debugPrint('   Time from now: ${nextOccurrence.difference(now).inSeconds} seconds');
    debugPrint('   Max time window: $maxTime (24 hours from now)');
    debugPrint('   Max occurrences: $maxOccurrences');
    debugPrint('');

    while (nextOccurrence.isBefore(maxTime) && count < maxOccurrences) {
      final timeUntil = nextOccurrence.difference(now);
      
      debugPrint('   [Occurrence ${count + 1}] Processing...');
      debugPrint('      Scheduled time: $nextOccurrence');
      debugPrint('      Time from now: ${timeUntil.inSeconds} seconds');
      
      // Ensure each occurrence is at least 1 second in the future
      if (nextOccurrence.isAfter(now.add(const Duration(seconds: 1)))) {
        // Use unique ID for each occurrence: base hash + occurrence index
        final notificationId = reminder.id.hashCode + count;
        debugPrint('      Notification ID: $notificationId (base: ${reminder.id.hashCode} + $count)');

        debugPrint('      📤 Calling AlarmService.scheduleExactAlarm...');
        final scheduled = await AlarmService.scheduleExactAlarm(
          id: notificationId,
          title: 'Reminder',
          body: reminder.text,
          scheduledTime: nextOccurrence,
          payload: reminder.id,
        );

        if (scheduled) {
          debugPrint('      ✅ Occurrence ${count + 1} scheduled successfully!');
          
          // Create occurrence record in database
          final occurrence = ReminderOccurrence(
            reminderId: reminder.id,
            scheduledTime: nextOccurrence,
            notificationId: notificationId,
            isCompleted: false,
          );
          await _reminderRepository.createReminderOccurrence(occurrence);
          debugPrint('      ✅ Occurrence record created in database');
          
          count++;
        } else {
          debugPrint('      ❌ FAILED to schedule occurrence ${count + 1}');
          debugPrint('         This occurrence will be skipped.');
          // Don't increment count if scheduling failed
        }
      } else {
        debugPrint('      ⏭️ Skipping occurrence ${count + 1} (too soon: ${timeUntil.inSeconds}s)');
      }

      debugPrint('');
      nextOccurrence = nextOccurrence.add(interval);
    }

    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('📊 SCHEDULING SUMMARY:');
    debugPrint('   Total occurrences scheduled: $count');
    debugPrint('   Reminder ID: ${reminder.id}');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('');
    
    if (count == 0) {
      debugPrint('⚠️⚠️⚠️ WARNING: NO OCCURRENCES WERE SCHEDULED! ⚠️⚠️⚠️');
      debugPrint('');
      debugPrint('🔍 DIAGNOSTIC CHECKLIST:');
      debugPrint('   1. Is timeAt set? ${reminder.timeAt != null ? "✅ Yes" : "❌ No"}');
      debugPrint('   2. Is reminder enabled? ${reminder.enabled ? "✅ Yes" : "❌ No"}');
      debugPrint('   3. Is repeatInterval set? ${reminder.repeatInterval != null ? "✅ Yes (${reminder.repeatInterval})" : "❌ No"}');
      debugPrint('   4. Is repeatUnit set? ${reminder.repeatUnit != null ? "✅ Yes (${reminder.repeatUnit})" : "❌ No"}');
      debugPrint('   5. Check exact alarm permission in app settings');
      debugPrint('   6. Check battery optimization is disabled');
      debugPrint('');
    } else {
      debugPrint('✅ Successfully scheduled $count occurrences');
      debugPrint('   First notification should appear in ${nextOccurrence.subtract(interval).difference(now).inSeconds} seconds');
    }
    debugPrint('');
  }
  
  /// Check if exact alarm permission is granted
  Future<bool> checkExactAlarmPermission() async {
    try {
      final permissionService = PermissionService();
      return await permissionService.hasExactAlarmPermission();
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      return false;
    }
  }

  /// Update reminder
  Future<bool> updateReminder(Reminder reminder) async {
    try {
      await _reminderRepository.updateReminder(reminder);
      await loadReminders();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Delete reminder
  Future<bool> deleteReminder(String id) async {
    try {
      // Find the reminder to check if it's recurring
      final reminder = _reminders.firstWhere((r) => r.id == id);

      // Cancel all alarms for this reminder
      if (reminder.isRecurring) {
        // Cancel all 50 occurrences
        for (int i = 0; i < 50; i++) {
          final notificationId = reminder.id.hashCode + i;
          await AlarmService.cancelAlarm(notificationId);
        }
        debugPrint('🗑️ Cancelled 50 recurring alarms for reminder $id');
      } else {
        // Cancel single alarm
        await AlarmService.cancelAlarm(id.hashCode);
        debugPrint('🗑️ Cancelled alarm for reminder $id');
      }

      await _reminderRepository.deleteReminder(id);
      await loadReminders();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Toggle reminder enabled state
  Future<bool> toggleReminder(String id, bool enabled) async {
    try {
      final reminder = _reminders.firstWhere((r) => r.id == id);

      // Debug: Log reminder details
      debugPrint(
          '🔄 Toggling reminder $id to ${enabled ? "enabled" : "disabled"}',);
      debugPrint('   Text: ${reminder.text}');
      debugPrint('   IsRecurring: ${reminder.isRecurring}');
      debugPrint('   RepeatInterval: ${reminder.repeatInterval}');
      debugPrint('   RepeatUnit: ${reminder.repeatUnit}');

      await _reminderRepository.toggleReminder(id, enabled);

      if (!enabled) {
        // Cancel all alarms for this reminder
        if (reminder.isRecurring) {
          // Cancel all 50 occurrences
          debugPrint('   Cancelling 50 recurring alarms...');
          for (int i = 0; i < 50; i++) {
            final notificationId = reminder.id.hashCode + i;
            await AlarmService.cancelAlarm(notificationId);
          }
          debugPrint('✅ Cancelled 50 recurring alarms for reminder $id');
        } else {
          debugPrint('   Cancelling single alarm...');
          await AlarmService.cancelAlarm(id.hashCode);
          debugPrint('✅ Cancelled single alarm for reminder $id');
        }
      } else {
        // Reschedule if time-based
        if (reminder.timeAt != null) {
          if (reminder.isRecurring) {
            debugPrint('   Rescheduling recurring notifications...');
            await _scheduleRecurringNotifications(reminder);
          } else {
            debugPrint('   Rescheduling single notification...');
            await AlarmService.scheduleExactAlarm(
              id: reminder.id.hashCode,
              title: 'Reminder',
              body: reminder.text,
              scheduledTime: reminder.timeAt!,
              payload: reminder.id,
            );
          }
        }
      }

      await loadReminders();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Load statistics
  Future<void> loadStatistics() async {
    try {
      _statistics = await _reminderRepository.getStatistics();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Mark a reminder as completed
  /// For recurring reminders, marks the specific occurrence or all pending occurrences
  Future<bool> completeReminder(String reminderId, {int? notificationId, DateTime? occurrenceTime}) async {
    try {
      final reminder = _reminders.firstWhere((r) => r.id == reminderId);
      
      debugPrint('✅ Completing reminder: ${reminder.text}');
      
      if (reminder.isRecurring) {
        // For recurring reminders, mark specific occurrence
        if (notificationId != null) {
          // Mark occurrence by notification ID
          await _reminderRepository.completeOccurrenceByNotificationId(notificationId);
          debugPrint('   Marked occurrence with notificationId $notificationId as completed');
        } else if (occurrenceTime != null) {
          // Find and mark occurrence by scheduled time
          final occurrences = await _reminderRepository.getReminderOccurrences(reminderId);
          final occurrence = occurrences.firstWhere(
            (o) => o.scheduledTime.year == occurrenceTime.year &&
                   o.scheduledTime.month == occurrenceTime.month &&
                   o.scheduledTime.day == occurrenceTime.day &&
                   o.scheduledTime.hour == occurrenceTime.hour &&
                   o.scheduledTime.minute == occurrenceTime.minute &&
                   !o.isCompleted,
            orElse: () => throw Exception('Occurrence not found'),
          );
          await _reminderRepository.completeOccurrence(occurrence.id);
          debugPrint('   Marked occurrence at $occurrenceTime as completed');
        } else {
          // No specific occurrence - mark next pending occurrence
          final pending = await _reminderRepository.getPendingOccurrences(reminderId);
          if (pending.isNotEmpty) {
            await _reminderRepository.completeOccurrence(pending.first.id);
            debugPrint('   Marked next pending occurrence as completed');
          }
        }
        
        // Create context event for completion
        await _reminderRepository.createContextEvent(
          ContextEvent(
            reminderId: reminderId,
            contextType: 'completion',
            outcome: AppConstants.outcomeCompleted,
          ),
        );
      } else {
        // For one-time reminders, mark as completed and disable
        await _reminderRepository.toggleReminder(reminderId, false);
        
        // Cancel notification
        await AlarmService.cancelAlarm(reminder.id.hashCode);
        
        // Create context event for completion
        await _reminderRepository.createContextEvent(
          ContextEvent(
            reminderId: reminderId,
            contextType: 'completion',
            outcome: AppConstants.outcomeCompleted,
          ),
        );
        
        debugPrint('   Marked one-time reminder as completed and disabled');
      }
      
      await loadReminders();
      await loadStatistics();
      return true;
    } catch (e) {
      debugPrint('❌ Error completing reminder: $e');
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
