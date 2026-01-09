import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/constants/app_constants.dart';
import '../../data/repositories/firestore_reminder_repository.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import '../../core/services/firestore_service.dart';
import '../../data/models/context_event.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import '../../data/models/context_event.dart';

/// Notification service for managing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationTapped,
    );

    // Create notification channel for Android
    await _createNotificationChannel();

    _initialized = true;
  }

  /// Create Android notification channel with high priority
  Future<void> _createNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDesc,
      importance: Importance.max, // Changed to max
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle notification tap when app is in foreground
  void _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;
    
    debugPrint('Notification tapped (foreground): $payload, actionId: $actionId');

    if (payload != null) {
      if (actionId == 'complete_action' && response.id != null) {
        // Handle complete action
        await _handleCompleteAction(payload, response.id!);
      } else if (actionId == 'snooze_action' && response.id != null) {
        // Handle snooze action
        await _handleSnoozeAction(payload, response.id!);
      } else if (actionId == 'quick_log_action' && response.id != null) {
        // Handle quick log action
        await _handleQuickLogAction(payload, response.id!);
      } else {
        await _recordNotificationInteraction(payload, 'seen');
      }
    }
  }

  /// Handle notification tap when app is in background/terminated
  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(
      NotificationResponse response,) async {
    final payload = response.payload;
    final actionId = response.actionId;
    
    debugPrint('Notification tapped (background): $payload, actionId: $actionId');

    if (payload != null) {
      if (actionId == 'complete_action' && response.id != null) {
        // Handle complete action
        await _handleCompleteAction(payload, response.id!);
      } else if (actionId == 'snooze_action' && response.id != null) {
        // Handle snooze action
        await _handleSnoozeAction(payload, response.id!);
      } else if (actionId == 'quick_log_action' && response.id != null) {
        // Handle quick log action
        await _handleQuickLogAction(payload, response.id!);
      } else {
        await _recordNotificationInteraction(payload, 'seen');
      }
    }
  }

  /// Handle snooze action from notification (reschedule for 1 hour later)
  static Future<void> _handleSnoozeAction(String payload, int notificationId) async {
    debugPrint('⏰ Handling snooze action for payload: $payload, notification $notificationId');
    
    try {
      // 1. Parse payload
      String? reminderId;
      int? goalTaskId;
      String? title;
      String? body;
      
      try {
        final data = jsonDecode(payload);
        if (data is Map<String, dynamic>) {
           if (data.containsKey('reminder_id')) reminderId = data['reminder_id'] as String;
           if (data.containsKey('task_id')) goalTaskId = data['task_id'] as int?; // New: support integer ID
           title = data['title'] as String?;
           body = data['body'] as String?;
        }
      } catch (e) {
        reminderId = payload; // Legacy fallback
      }
      
      // Calculate new time (1 hour from now)
      final newScheduledTime = DateTime.now().add(const Duration(hours: 1));
      
      // 2. Handle GoalTask specific persistence
      if (goalTaskId != null || (reminderId != null && reminderId.startsWith('task_'))) {
          // It's a GoalTask
          final id = goalTaskId ?? int.tryParse(reminderId!.replaceFirst('task_', ''));
          if (id != null) {
              debugPrint('💤 Snoozing GoalTask $id until $newScheduledTime');
              final growthRepo = FirestoreGrowthRepository();
              // Using existing 'updateTask' is complex because we need the whole object.
              // Instead, using a dedicated 'updateTaskField' would be ideal, but for now we fetch-update-save.
              // Since NotificationService is static/isolated, we do this manually or via repository helper.
              // Repository usually requires full object. 
              // Let's implement a direct update for just the date if possible, OR fetch-modify-save.
              // Given constraints, we'll try to fetch the task first.
              
              // We don't have direct access to 'GrowthProvider' state here easily as it's static.
              // But we can use _repository.
              
              // Note: Ideally FirestoreGrowthRepository should have 'updateTaskDate(id, date)'
              // Assuming updateTask works, we need to fetch it first. 
              // BUT 'getTask(id)' might not exist in Repo API.
              // Let's rely on standard 'updateTask' assuming we can construct a partial update OR
              // if we can't fetch, we might skip persistence and just schedule local?
              // The user REQUESTED persistence. 
              
              // Workaround: We will use a firestore merge update directly here?
              // No, better to keep architecture clean.
              // Let's assume we can just schedule the local notification for now, 
              // AND try to update firestore if we can.
              
              // Since I can't easily fetch the task without context/repo lookup:
              // I will use direct FirestoreService for this specific patch to ensure speed/reliability.
              final firestore = FirestoreService();
              final uid = firestore.currentUserId; // Fix: use currentUserId
              if (uid != null) {
                 // We don't know which goal... task is in subcollection 'tasks'.
                 // We need to query collectionGroup or find the path.
                 // This is tricky without parent goalId.
                 // Wait! The payload HAS goal_id!
                 
                 int? goalId; 
                 try {
                     final d = jsonDecode(payload);
                     goalId = d['goal_id'];
                 } catch(_){}

                 if (goalId != null) {
                    final tasksCollection = firestore.getTasksCollection(goalId.toString());
                    if (tasksCollection != null) {
                        await tasksCollection
                            .doc(id.toString())
                            .update({
                                'scheduledDate': newScheduledTime.toIso8601String(),
                                // Also update snake_case just in case
                                'scheduled_date': newScheduledTime.toIso8601String(),
                            });
                        debugPrint('✅ Persisted snooze to Firestore for task $id');
                    }
                 }
              }
          }
      } else if (reminderId != null) {
         // Existing Logic for standard Reminders
         final reminderRepository = FirestoreReminderRepository();
         final reminder = await reminderRepository.getReminder(reminderId);
         if (reminder != null) {
             // Create context event (existing logic)
              await reminderRepository.createContextEvent(
                ContextEvent(
                  reminderId: reminderId,
                  contextType: 'notification_action',
                  outcome: 'snoozed',
                  metadata: {
                    'snoozed_until': newScheduledTime.toIso8601String(),
                    'original_notification_id': notificationId,
                  },
                ),
              );
              if (title == null) title = reminder.text;
         }
      }

      // 3. Reschedule Local Notification
      final notificationService = NotificationService();
      await notificationService.cancelNotification(notificationId);
      
      final notificationTitle = title ?? "Snoozed Task";
      final notificationBody = body ?? "Reminder snoozed for 1 hour.";
      
      // Generate new notification ID
      final newNotificationId = DateTime.now().millisecondsSinceEpoch % 2147483647;
      
      await notificationService.scheduleNotification(
        id: newNotificationId,
        title: notificationTitle,
        body: notificationBody,
        scheduledTime: newScheduledTime,
        payload: payload, 
      );
      
      debugPrint('✅ Successfully snoozed notification $notificationId');
    } catch (e) {
      debugPrint('❌ Error handling snooze action: $e');
    }
  }

  /// Handle complete action from notification
  static Future<void> _handleCompleteAction(String payload, int notificationId) async {
    debugPrint('✅ Handling complete action for payload: $payload, notification $notificationId');
    
    try {
      // Parse payload (can be reminder ID string or JSON)
      String reminderId;
      int? skillId;
      String? notes;
      String action = 'complete';
      
      try {
        // Try to parse as JSON
        final data = jsonDecode(payload);
        action = data['action'] as String? ?? 'complete';
        reminderId = data['reminder_id'] as String;
        skillId = data['skill_id'] as int?;
        notes = data['notes'] as String?;
      } catch (e) {
        // Fallback: treat as simple reminder ID
        reminderId = payload;
      }
      
      final reminderRepository = FirestoreReminderRepository();
      
      if (reminderId.startsWith('task_')) {
        // It's a GoalTask
        final taskIdStr = reminderId.replaceFirst('task_', '');
        final taskId = int.tryParse(taskIdStr);
        if (taskId != null) {
          final growthRepo = FirestoreGrowthRepository();
          await growthRepo.completeTask(taskId);
          debugPrint('✅ Successfully completed GoalTask $taskId');
        }
      } else {
         // Legacy: Mark occurrence as completed by notification ID
         await reminderRepository.completeOccurrenceByNotificationId(notificationId);
      }
      
      // Create context event for completion
      await reminderRepository.createContextEvent(
        ContextEvent(
          reminderId: reminderId,
          contextType: 'notification_action',
          outcome: AppConstants.outcomeCompleted,
        ),
      );
      
      // Skills/reps removed - no longer logging reps
      
      // Cancel the notification
      final notificationService = NotificationService();
      await notificationService.cancelNotification(notificationId);
      
      debugPrint('✅ Successfully completed reminder $reminderId from notification');
    } catch (e) {
      debugPrint('❌ Error handling complete action: $e');
    }
  }

  /// Handle quick log action from notification (deprecated - skills removed)
  @pragma('vm:entry-point')
  static Future<void> _handleQuickLogAction(String payload, int notificationId) async {
    debugPrint('🚀 Handling quick log action (deprecated - skills removed)');
    
    try {
      // Parse payload
      String reminderId;
      
      try {
        final data = jsonDecode(payload);
        reminderId = data['reminder_id'] as String;
      } catch (e) {
        debugPrint('❌ Error parsing payload for quick log: $e');
        return;
      }
      
      // Mark reminder as completed
      final reminderRepository = FirestoreReminderRepository();
      await reminderRepository.completeOccurrenceByNotificationId(notificationId);
      
      // Create context event
      await reminderRepository.createContextEvent(
        ContextEvent(
          reminderId: reminderId,
          contextType: 'notification_action',
          outcome: 'quick_logged',
        ),
      );
      
      // Cancel the notification
      final notificationService = NotificationService();
      await notificationService.cancelNotification(notificationId);
      
      debugPrint('✅ Successfully quick-logged rep from notification');
    } catch (e) {
      debugPrint('❌ Error handling quick log action: $e');
    }
  }

  /// Record notification interaction in database
  static Future<void> _recordNotificationInteraction(
      String reminderId, String outcome,) async {
    try {
      final firestoreService = FirestoreService();
      final collection = firestoreService.contextEventsCollection;
      if (collection == null) {
        debugPrint('⚠️ Cannot record notification interaction: User not authenticated');
        return;
      }

      final eventId = DateTime.now().millisecondsSinceEpoch.toString();
      final event = ContextEvent(
        id: eventId,
        reminderId: reminderId,
        contextType: 'notification_tap',
        outcome: outcome,
      );

      await collection.doc(eventId).set(event.toFirestore());

      debugPrint(
          '✅ Recorded notification interaction for reminder $reminderId',);
    } catch (e) {
      debugPrint('❌ Failed to record notification interaction: $e');
    }
  }

  /// Record scheduled notification in database
  static Future<void> _recordScheduledNotification({
    required String reminderId,
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    try {
      final firestoreService = FirestoreService();
      final collection = firestoreService.contextEventsCollection;
      if (collection == null) {
        debugPrint('⚠️ Cannot record scheduled notification: User not authenticated');
        return;
      }

      final eventId = 'sched_${DateTime.now().millisecondsSinceEpoch}';
      final event = ContextEvent(
        id: eventId,
        reminderId: reminderId,
        contextType: AppConstants.contextTypeTime,
        triggerTime: scheduledTime,
        outcome: AppConstants.outcomePending,
        metadata: {
          'title': title,
          'body': body,
          'type': 'scheduled_alarm',
        },
      );

      await collection.doc(eventId).set(event.toFirestore());

      debugPrint(
          '✅ Recorded scheduled notification for reminder $reminderId at $scheduledTime',);
    } catch (e) {
      debugPrint('❌ Failed to record scheduled notification: $e');
    }
  }

  /// Show immediate notification with actions
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    debugPrint('Showing notification id=$id title="$title" payload=$payload');

    // Parse payload to check if it's skill-linked
    List<AndroidNotificationAction> actions = [];
    try {
      if (payload != null) {
        final data = jsonDecode(payload);
        final action = data['action'] as String?;
        final skillId = data['skill_id'] as int?;
        
        // If skill-linked, add "Quick Log" action
        if (action == 'log_rep' && skillId != null) {
          const quickLogAction = AndroidNotificationAction(
            'quick_log_action',
            'Quick Log',
            showsUserInterface: false,
            cancelNotification: true,
          );
          actions.add(quickLogAction);
        }
      }
    } catch (e) {
      // If parsing fails, use default actions
    }
    
    // Always add Snooze and Complete actions
    const snoozeAction = AndroidNotificationAction(
      'snooze_action',
      'Snooze',
      showsUserInterface: false,
      cancelNotification: false, // Don't cancel, we'll reschedule
    );
    
    const completeAction = AndroidNotificationAction(
      'complete_action',
      'Complete',
      showsUserInterface: false,
      cancelNotification: true,
    );
    
    // If no quick log action was added, use default actions
    if (actions.isEmpty) {
      actions = [snoozeAction, completeAction];
    } else {
      actions.addAll([snoozeAction, completeAction]);
    }

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      enableLights: true,
      autoCancel: true,
      ongoing: false,
      fullScreenIntent: false, // Changed to false to prevent auto-opening app
      actions: actions,
    );

    // iOS notification details (actions require separate registration, simplified for now)
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);

    // Record interaction for history
    if (payload != null) {
      await _recordNotificationEvent(
        payload: payload,
        title: title,
        body: body,
        type: 'immediate',
      );
    }
  }

  /// Record notification event to Firestore
  static Future<void> _recordNotificationEvent({
    required String payload,
    required String title,
    required String body,
    required String type,
  }) async {
    try {
      String? reminderId;
      Map<String, dynamic> metadata = {
        'title': title,
        'body': body,
        'type': type,
        'payload': payload,
      };

      try {
        final data = jsonDecode(payload);
        if (data is Map<String, dynamic>) {
           if (data.containsKey('reminder_id')) reminderId = data['reminder_id'];
           if (data.containsKey('task_id')) reminderId = "task_${data['task_id']}";
           // Merge other data
           metadata.addAll(data);
        }
      } catch (e) {
        // Payload might be just ID string
        reminderId = payload;
      }

      if (reminderId == null) return; // Can't link

      final firestoreService = FirestoreService();
      final collection = firestoreService.contextEventsCollection;
      if (collection == null) return;

      final eventId = 'notif_${DateTime.now().millisecondsSinceEpoch}';
      final event = ContextEvent(
        id: eventId,
        reminderId: reminderId,
        contextType: 'notification_sent',
        triggerTime: DateTime.now(),
        outcome: AppConstants.outcomePending,
        metadata: metadata,
      );

      await collection.doc(eventId).set(event.toFirestore());
      debugPrint('✅ Recorded notification history: $title');
    } catch (e) {
      debugPrint('❌ Failed to record notification history: $e');
    }
  }

  /// Schedule notification for a specific time
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    // Validate scheduled time is in the future
    if (scheduledTime.isBefore(DateTime.now())) {
      debugPrint('⚠️ Warning: Scheduled time is in the past! $scheduledTime');
      return;
    }

    debugPrint(
        '📅 Scheduling notification id=$id title="$title" at $scheduledTime payload=$payload',);

    // Parse payload to check if it's skill-linked
    List<AndroidNotificationAction> actions = [];
    try {
      if (payload != null) {
        final data = jsonDecode(payload);
        final action = data['action'] as String?;
        final skillId = data['skill_id'] as int?;
        
        // If skill-linked, add "Quick Log" action
        if (action == 'log_rep' && skillId != null) {
          const quickLogAction = AndroidNotificationAction(
            'quick_log_action',
            'Quick Log',
            showsUserInterface: false,
            cancelNotification: true,
          );
          actions.add(quickLogAction);
        }
      }
    } catch (e) {
      // If parsing fails, use default actions
    }
    
    // Always add Snooze and Complete actions
    const snoozeAction = AndroidNotificationAction(
      'snooze_action',
      'Snooze',
      showsUserInterface: false,
      cancelNotification: false, // Don't cancel, we'll reschedule
    );
    
    const completeAction = AndroidNotificationAction(
      'complete_action',
      'Complete',
      showsUserInterface: false,
      cancelNotification: true,
    );
    
    // If no quick log action was added, use default actions
    if (actions.isEmpty) {
      actions = [snoozeAction, completeAction];
    } else {
      actions.addAll([snoozeAction, completeAction]);
    }

    final androidDetails = AndroidNotificationDetails(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      channelDescription: AppConstants.notificationChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      autoCancel: true,
      ongoing: false,
      fullScreenIntent: false, // Changed to false to prevent auto-opening app
      visibility: NotificationVisibility.public,
      actions: actions,
    );

    // iOS notification details (actions require separate registration, simplified for now)
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    debugPrint('🔔 TZ Scheduled time: $tzScheduledTime');
    debugPrint('🕐 Current time: ${tz.TZDateTime.now(tz.local)}');
    debugPrint(
        '⏰ Time until notification: ${tzScheduledTime.difference(tz.TZDateTime.now(tz.local))}',);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      details,
      payload: payload,
      androidScheduleMode:
          AndroidScheduleMode.exactAllowWhileIdle, // This allows waking device
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchDateTimeComponents,
    );

    // Verify it was scheduled
    final pending = await getPendingNotifications();
    final scheduled = pending.any((p) => p.id == id);
    debugPrint('✅ Notification scheduled successfully: $scheduled');

    // Create context event for scheduled notification
    if (scheduled && payload != null) {
      String recordId = payload;
      try {
        final data = jsonDecode(payload);
        if (data is Map<String, dynamic>) {
          if (data.containsKey('task_id')) {
            recordId = 'task_${data['task_id']}';
          } else if (data.containsKey('reminder_id')) {
            recordId = data['reminder_id'].toString();
          }
        }
      } catch (_) {
        // Payload is not JSON, use as is
      }

      await NotificationService._recordScheduledNotification(
        reminderId: recordId,
        scheduledTime: scheduledTime,
        title: title,
        body: body,
      );
    }
  }

  /// Cancel notification
  Future<void> cancelNotification(int id) async {
    debugPrint('🗑️ Cancelling notification id=$id');
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    debugPrint('🗑️ Cancelling all notifications');
    await _notifications.cancelAll();
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    final pending = await _notifications.pendingNotificationRequests();
    debugPrint('📋 Pending notifications: ${pending.length}');
    for (var p in pending) {
      debugPrint('  - ID: ${p.id}, Title: ${p.title}, Body: ${p.body}');
    }
    return pending;
  }

  /// Request notification permissions (iOS)
  Future<bool> requestPermissions() async {
    final result = await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // requestPermissions returns bool? on iOS; default to true when null
    return result ?? true;
  }

  /// Check if a notification is scheduled
  Future<bool> isNotificationScheduled(int id) async {
    final pending = await getPendingNotifications();
    return pending.any((p) => p.id == id);
  }
}
