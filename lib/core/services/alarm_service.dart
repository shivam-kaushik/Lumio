import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Service for scheduling reliable alarms
/// Android: Uses native AlarmManager for exact timing
/// iOS: Uses flutter_local_notifications (iOS doesn't have exact alarms)
class AlarmService {
  static const _channel = MethodChannel('com.example.lumio/alarms');
  static final FlutterLocalNotificationsPlugin _iosNotifications = 
      FlutterLocalNotificationsPlugin();

  /// Schedule an exact alarm that will fire even if the app is killed
  static Future<bool> scheduleExactAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    debugPrint('');
    debugPrint('┌─────────────────────────────────────────────────┐');
    debugPrint('│ 📱 ALARM SERVICE: scheduleExactAlarm            │');
    debugPrint('└─────────────────────────────────────────────────┘');
    
    try {
      // Validate scheduled time is in future (at least 1 second)
      final now = DateTime.now();
      final timeUntil = scheduledTime.difference(now);
      
      debugPrint('📋 Parameters:');
      debugPrint('   ID: $id');
      debugPrint('   Title: "$title"');
      debugPrint('   Body: "$body"');
      debugPrint('   Scheduled DateTime: $scheduledTime');
      debugPrint('   Current DateTime: $now');
      debugPrint('   Scheduled Time (millis): ${scheduledTime.millisecondsSinceEpoch}');
      debugPrint('   Current Time (millis): ${now.millisecondsSinceEpoch}');
      debugPrint('   Time until alarm: ${timeUntil.inSeconds} seconds (${timeUntil.inMinutes} minutes)');
      debugPrint('   Payload: $payload');
      
      if (timeUntil.inSeconds < 1) {
        debugPrint('');
        debugPrint('❌ VALIDATION FAILED: Time too close or in past!');
        debugPrint('   Scheduled: $scheduledTime');
        debugPrint('   Now: $now');
        debugPrint('   Difference: ${timeUntil.inSeconds} seconds');
        debugPrint('   Required: At least 1 second in the future');
        debugPrint('└─────────────────────────────────────────────────┘');
        debugPrint('');
        return false;
      }

      final scheduledTimeMillis = scheduledTime.millisecondsSinceEpoch;
      debugPrint('');
      debugPrint('✅ Validation passed - calling platform-specific method...');

      if (Platform.isIOS) {
        // iOS: Use flutter_local_notifications
        debugPrint('📱 Platform: iOS - Using flutter_local_notifications');
        
        try {
          final tz.TZDateTime scheduledDate = tz.TZDateTime.from(
            scheduledTime,
            tz.local,
          );
          
          debugPrint('📅 Scheduling iOS notification:');
          debugPrint('   ID: $id');
          debugPrint('   Title: "$title"');
          debugPrint('   Body: "$body"');
          debugPrint('   Scheduled Date: $scheduledDate');
          
          await _iosNotifications.zonedSchedule(
            id,
            title,
            body,
            scheduledDate,
            const NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
              android: AndroidNotificationDetails(
                'lumio_reminders',
                'Reminders',
                channelDescription: 'Context-aware reminder notifications',
                importance: Importance.max,
                priority: Priority.high,
              ),
            ),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.time,
            payload: payload,
          );
          
          debugPrint('✅✅✅ iOS NOTIFICATION SCHEDULED SUCCESSFULLY ✅✅✅');
          debugPrint('   Notification ID: $id');
          debugPrint('   Will fire in: ${timeUntil.inSeconds} seconds');
          debugPrint('   Will fire at: $scheduledTime');
          debugPrint('└─────────────────────────────────────────────────┘');
          debugPrint('');
          
          return true;
        } catch (e) {
          debugPrint('❌❌❌ iOS NOTIFICATION SCHEDULING FAILED ❌❌❌');
          debugPrint('   Notification ID: $id');
          debugPrint('   Error: $e');
          debugPrint('└─────────────────────────────────────────────────┘');
          debugPrint('');
          return false;
        }
      } else {
        // Android: Use native AlarmManager
        debugPrint('🤖 Platform: Android - Using native AlarmManager');
        
        debugPrint('📞 Invoking native method channel:');
        debugPrint('   Channel: com.example.lumio/alarms');
        debugPrint('   Method: scheduleExactAlarm');
        debugPrint('   Arguments:');
        debugPrint('     - id: $id');
        debugPrint('     - title: "$title"');
        debugPrint('     - body: "$body"');
        debugPrint('     - scheduledTimeMillis: $scheduledTimeMillis');
        debugPrint('     - payload: $payload');
        
        final result = await _channel.invokeMethod<bool>('scheduleExactAlarm', {
          'id': id,
          'title': title,
          'body': body,
          'scheduledTimeMillis': scheduledTimeMillis,
          'payload': payload,
        });

        debugPrint('');
        if (result == true) {
          debugPrint('✅✅✅ NATIVE ALARM SCHEDULED SUCCESSFULLY ✅✅✅');
          debugPrint('   Alarm ID: $id');
          debugPrint('   Will fire in: ${timeUntil.inSeconds} seconds');
          debugPrint('   Will fire at: $scheduledTime');
        } else {
          debugPrint('❌❌❌ NATIVE ALARM SCHEDULING FAILED ❌❌❌');
          debugPrint('   Alarm ID: $id');
          debugPrint('   Result from native: ${result ?? "null"}');
          debugPrint('');
          debugPrint('🔍 Possible causes:');
          debugPrint('   1. Exact alarm permission not granted (Android 12+)');
          debugPrint('   2. Battery optimization enabled for Lumio');
          debugPrint('   3. Device power saving mode active');
          debugPrint('   4. App not whitelisted from battery optimization');
          debugPrint('   5. Android system restrictions');
        }
        debugPrint('└─────────────────────────────────────────────────┘');
        debugPrint('');

        return result ?? false;
      }
    } catch (e, stackTrace) {
      debugPrint('');
      debugPrint('❌❌❌ EXCEPTION in scheduleExactAlarm ❌❌❌');
      debugPrint('   Error: $e');
      debugPrint('   Stack trace:');
      debugPrint('$stackTrace');
      debugPrint('└─────────────────────────────────────────────────┘');
      debugPrint('');
      return false;
    }
  }

  /// Cancel a scheduled alarm
  static Future<void> cancelAlarm(int id) async {
    try {
      if (Platform.isIOS) {
        await _iosNotifications.cancel(id);
        debugPrint('🗑️ Cancelled iOS notification id=$id');
      } else {
        await _channel.invokeMethod('cancelAlarm', {'id': id});
        debugPrint('🗑️ Cancelled alarm id=$id');
      }
    } catch (e) {
      debugPrint('❌ Error cancelling alarm: $e');
    }
  }

  /// Cancel all scheduled alarms
  static Future<void> cancelAllAlarms() async {
    try {
      if (Platform.isIOS) {
        await _iosNotifications.cancelAll();
        debugPrint('🗑️ Cancelled all iOS notifications');
      } else {
        await _channel.invokeMethod('cancelAllAlarms');
        debugPrint('🗑️ Cancelled all alarms');
      }
    } catch (e) {
      debugPrint('❌ Error cancelling all alarms: $e');
    }
  }
}
