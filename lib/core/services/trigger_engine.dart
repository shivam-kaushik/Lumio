import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/reminder.dart';
import 'weather_service.dart';
import '../../data/models/context_event.dart';
import '../../data/repositories/firestore_reminder_repository.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_time_utils.dart';
import 'notification_service.dart';
import 'home_detection_service.dart';
import 'activity_recognition_service.dart';
import 'privacy_gpt_service.dart';

/// Context trigger engine that monitors sensors and triggers reminders
/// Integrated with HomeDetectionService for WiFi + GPS home detection
class TriggerEngine {
  final FirestoreReminderRepository _reminderRepository;
  final NotificationService _notificationService;
  final HomeDetectionService _homeService = HomeDetectionService();
  final WeatherService _weatherService = WeatherService();
  final ActivityRecognitionService _activityService = ActivityRecognitionService();
  final FirestoreGrowthRepository _growthRepository = FirestoreGrowthRepository();
  final PrivacyGptService _privacyGpt = PrivacyGptService();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Position? _currentPosition;
  bool _wasAtHome = false;
  String? _previousActivity;

  TriggerEngine({
    required FirestoreReminderRepository reminderRepository,
    required NotificationService notificationService,
  })  : _reminderRepository = reminderRepository,
        _notificationService = notificationService;

  /// Start monitoring context (location + activity)
  Future<void> startMonitoring() async {
    await _startLocationMonitoring();
    // Initialize home status
    _wasAtHome = await _homeService.isAtHome();
    await _startActivityMonitoring();
  }

  /// Stop monitoring context
  Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();
    await _connectivitySubscription?.cancel();
    await _activityService.stopMonitoring();
  }

  Future<void> _startLocationMonitoring() async {
    if (kDebugMode) {
      print('📍 TriggerEngine: Starting location monitoring...');
    }
    
    final hasPermission = await _checkLocationPermission();
    if (!hasPermission) {
      if (kDebugMode) {
        print('⚠️ TriggerEngine: Location permission not granted. Location monitoring disabled.');
      }
      return;
    }

    if (kDebugMode) {
      print('✅ TriggerEngine: Location permission granted');
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 50, // Update every 50 meters
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      if (kDebugMode) {
        print('📍 Position update: lat=${position.latitude.toStringAsFixed(6)}, lng=${position.longitude.toStringAsFixed(6)}, accuracy=${position.accuracy.toStringAsFixed(1)}m');
      }
      _currentPosition = position;
      _checkGeofenceReminders();
    }, onError: (error) {
      if (kDebugMode) {
        print('❌ TriggerEngine: Location stream error: $error');
      }
    });

    if (kDebugMode) {
      print('✅ TriggerEngine: Location monitoring started (distance filter: 50m)');
    }
  }

  Future<void> _startWifiMonitoring() async {
    // Check initial home status
    _wasAtHome = await _homeService.isAtHome();

    if (kDebugMode) {
      print(
          '📡 TriggerEngine: WiFi monitoring started (initial home status: $_wasAtHome)',);
    }

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult r) async {
      if (kDebugMode) {
        print('📡 Connectivity changed: $r');
      }

      // Check if we're at home when connectivity changes
      final isAtHome = await _homeService.isAtHome();

      if (kDebugMode) {
        print('🏠 Home status check: was=$_wasAtHome, now=$isAtHome');
      }

      // Detect transitions
      if (isAtHome && !_wasAtHome) {
        // Just arrived home
        if (kDebugMode) {
          print('✅ ARRIVING HOME detected');
        }
        await checkLocationReminders(arriving: true);
      } else if (!isAtHome && _wasAtHome) {
        // Just left home
        if (kDebugMode) {
          print('🚪 LEAVING HOME detected');
        }
        await checkLocationReminders(leaving: true);
      }

      _wasAtHome = isAtHome;
    });
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

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<void> _checkGeofenceReminders() async {
    if (_currentPosition == null) return;

    final reminders = await _reminderRepository.getActiveReminders();

    for (var reminder in reminders) {
      if (reminder.geofenceLat == null || reminder.geofenceLng == null) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        reminder.geofenceLat!,
        reminder.geofenceLng!,
      );

      final radius =
          reminder.geofenceRadius ?? AppConstants.defaultGeofenceRadius;
      final isInside = distance <= radius;

      if (isInside && reminder.onArriveContext) {
        await _triggerReminder(reminder, AppConstants.contextTypeArriving);
      }

      if (!isInside && reminder.onLeaveContext) {
        // For a robust solution we'd track previous inside/outside state per reminder.
        await _triggerReminder(reminder, AppConstants.contextTypeLeaving);
      }
    }
  }

  /// Check location-based reminders (WiFi + GPS)
  Future<void> checkLocationReminders(
      {bool leaving = false, bool arriving = false,}) async {
    final reminders = await _reminderRepository.getActiveReminders();
    final isAtHome = await _homeService.isAtHome();
    final currentPos = _currentPosition ??
        (await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium));

    if (kDebugMode) {
      print(
          '🔍 Checking location reminders: leaving=$leaving, arriving=$arriving, at home=$isAtHome',);
    }

    for (var reminder in reminders) {
      // Check if this is a home-based reminder
      final isHomeReminder = reminder.geofenceId == 'home';

      if (!isHomeReminder) continue;

      if (kDebugMode) {
        print(
            '  📝 Home reminder: "${reminder.text}" (leave=${reminder.onLeaveContext}, arrive=${reminder.onArriveContext})',);
      }

      // Handle leaving home
      if (leaving && reminder.onLeaveContext && !isAtHome) {
        // Weather gate: if reminder requires rain, check weather now
        if (reminder.weatherCondition == 'rain') {
          if (currentPos != null) {
            final w = await _weatherService.fetchCurrentWeather(
              latitude: currentPos.latitude,
              longitude: currentPos.longitude,
            );
            final raining = (w != null) && _weatherService.isRaining(w);
            if (!raining) {
              if (kDebugMode) {
                print('  🌦️ Skipping (not raining) for weather-based reminder: ${reminder.text}');
              }
              continue;
            }
          }
        }
        if (kDebugMode) {
          print('  🔔 TRIGGERING "leaving home" reminder: ${reminder.text}');
        }
        await _triggerReminder(reminder, AppConstants.contextTypeLeaving);
      }

      // Handle arriving home
      if (arriving && reminder.onArriveContext && isAtHome) {
        if (kDebugMode) {
          print('  🔔 TRIGGERING "arriving home" reminder: ${reminder.text}');
        }
        await _triggerReminder(reminder, AppConstants.contextTypeArriving);
      }
    }
  }

  /// Check Wi-Fi based reminders (legacy - redirects to checkLocationReminders)
  @Deprecated('Use checkLocationReminders instead')
  Future<void> checkWifiReminders({bool leaving = false}) async {
    await checkLocationReminders(leaving: leaving, arriving: !leaving);
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

  /// Run periodic checks (time + location + activity)
  Future<void> runBackgroundChecks() async {
    if (kDebugMode) {
      print('⏰ Running background checks...');
    }

    await checkTimeReminders();
    
    // Check activity-based reminders
    await _checkActivityReminders();

    // Check if home status changed
    final isAtHome = await _homeService.isAtHome();
    if (isAtHome != _wasAtHome) {
      if (kDebugMode) {
        print(
            '🏠 Background check detected home status change: was=$_wasAtHome, now=$isAtHome',);
      }
      if (isAtHome) {
        await checkLocationReminders(arriving: true);
      } else {
        await checkLocationReminders(leaving: true);
      }
      _wasAtHome = isAtHome;
    }
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
