import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/models/reminder.dart';
import 'device_state_service.dart';
import 'activity_recognition_service.dart';
import 'home_detection_service.dart';

/// Advanced rule engine for evaluating complex multi-condition trigger rules
/// Supports: time + location + activity + device state combinations
class ContextRuleEngine {
  final DeviceStateService _deviceState;
  final ActivityRecognitionService _activityService;
  final HomeDetectionService _homeService;
  
  ContextRuleEngine({
    required DeviceStateService deviceState,
    required ActivityRecognitionService activityService,
    required HomeDetectionService homeService,
  })  : _deviceState = deviceState,
        _activityService = activityService,
        _homeService = homeService;
  
  /// Evaluate if reminder conditions are met
  /// Returns evaluation result with details
  Future<RuleEvaluationResult> evaluateReminder(Reminder reminder, {
    DateTime? currentTime,
    Position? currentPosition,
    String? currentWifiSsid,
  }) async {
    if (kDebugMode) {
      print('');
      print('⚖️═══════════════════════════════════════════════════');
      print('⚖️ RULE ENGINE: Evaluating Reminder');
      print('⚖️═══════════════════════════════════════════════════');
      print('   Reminder: "${reminder.text}"');
      print('   ID: ${reminder.id}');
    }
    
    final now = currentTime ?? DateTime.now();
    final conditions = <String, bool>{};
    final details = <String, String>{};
    
    // Evaluate time condition
    final timeResult = _evaluateTimeCondition(reminder, now);
    conditions['time'] = timeResult['met'] as bool;
    details['time'] = timeResult['details'] as String;
    
    // Evaluate location condition
    final locationResult = await _evaluateLocationCondition(
      reminder,
      currentPosition: currentPosition,
      currentWifiSsid: currentWifiSsid,
    );
    conditions['location'] = locationResult['met'] as bool;
    details['location'] = locationResult['details'] as String;
    
    // Evaluate activity condition
    final activityResult = _evaluateActivityCondition(reminder);
    conditions['activity'] = activityResult['met'] as bool;
    details['activity'] = activityResult['details'] as String;
    
    // Evaluate device state condition
    final deviceResult = _evaluateDeviceStateCondition(reminder);
    conditions['device_state'] = deviceResult['met'] as bool;
    details['device_state'] = deviceResult['details'] as String;
    
    // Determine if all required conditions are met
    final requiredConditions = <String>[];
    if (reminder.timeAt != null || reminder.preferredTimeOfDay != null) {
      requiredConditions.add('time');
    }
    if (reminder.geofenceId != null || reminder.onArriveContext || reminder.onLeaveContext) {
      requiredConditions.add('location');
    }
    if (reminder.activityType != null) {
      requiredConditions.add('activity');
    }
    // Device state conditions are optional (if specified)
    
    final allRequiredMet = requiredConditions.every((cond) => conditions[cond] == true);
    final anyOptionalMet = conditions['device_state'] == true;
    
    // For now, require all specified conditions to be met
    // Can be made configurable (AND vs OR logic)
    final isTriggered = requiredConditions.isEmpty 
        ? anyOptionalMet 
        : allRequiredMet;
    
    if (kDebugMode) {
      print('   Condition Evaluation:');
      print('     Time: ${conditions['time']} - ${details['time']}');
      print('     Location: ${conditions['location']} - ${details['location']}');
      print('     Activity: ${conditions['activity']} - ${details['activity']}');
      print('     Device State: ${conditions['device_state']} - ${details['device_state']}');
      print('   Required conditions: ${requiredConditions.join(", ")}');
      print('   All required met: $allRequiredMet');
      print('   Should trigger: $isTriggered');
      print('⚖️═══════════════════════════════════════════════════');
      print('');
    }
    
    return RuleEvaluationResult(
      shouldTrigger: isTriggered,
      conditions: conditions,
      details: details,
      timestamp: now,
    );
  }
  
  /// Evaluate time-based condition
  Map<String, dynamic> _evaluateTimeCondition(Reminder reminder, DateTime now) {
    // Check if reminder has time-based trigger
    if (reminder.timeAt == null && reminder.preferredTimeOfDay == null) {
      return {'met': true, 'details': 'No time condition specified'};
    }
    
    // Check exact time match (within 1 minute tolerance)
    if (reminder.timeAt != null) {
      final timeDiff = reminder.timeAt!.difference(now).inMinutes.abs();
      if (timeDiff <= 1) {
        return {
          'met': true,
          'details': 'Time matched: ${reminder.timeAt!.hour}:${reminder.timeAt!.minute.toString().padLeft(2, '0')}',
        };
      }
      
      return {
        'met': false,
        'details': 'Time not matched: ${reminder.timeAt!.hour}:${reminder.timeAt!.minute} (now: ${now.hour}:${now.minute})',
      };
    }
    
    // Check preferred time of day
    if (reminder.preferredTimeOfDay != null) {
      final currentHour = now.hour;
      final preferred = reminder.preferredTimeOfDay!;
      final inRange = currentHour >= preferred.startHour && currentHour < preferred.endHour;
      
      return {
        'met': inRange,
        'details': inRange
            ? 'Within preferred time: ${preferred.displayName}'
            : 'Outside preferred time: ${preferred.displayName}',
      };
    }
    
    return {'met': false, 'details': 'Time condition evaluation failed'};
  }
  
  /// Evaluate location-based condition
  Future<Map<String, dynamic>> _evaluateLocationCondition(
    Reminder reminder, {
    Position? currentPosition,
    String? currentWifiSsid,
  }) async {
    // Check if reminder has location-based trigger
    if (reminder.geofenceId == null && 
        !reminder.onArriveContext && 
        !reminder.onLeaveContext) {
      return {'met': true, 'details': 'No location condition specified'};
    }
    
    // Check home-based location
    if (reminder.geofenceId == 'home') {
      final isAtHome = await _homeService.isAtHome();
      
      if (reminder.onArriveContext) {
        return {
          'met': isAtHome,
          'details': isAtHome ? 'At home (arrival detected)' : 'Not at home',
        };
      }
      
      if (reminder.onLeaveContext) {
        return {
          'met': !isAtHome,
          'details': !isAtHome ? 'Left home' : 'Still at home',
        };
      }
    }
    
    // Check geofence (GPS-based)
    if (reminder.geofenceLat != null && reminder.geofenceLng != null && currentPosition != null) {
      final distance = _calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        reminder.geofenceLat!,
        reminder.geofenceLng!,
      );
      
      final radius = reminder.geofenceRadius ?? 100.0;
      final isInside = distance <= radius;
      
      return {
        'met': isInside,
        'details': isInside
            ? 'Inside geofence (${distance.toStringAsFixed(0)}m from center)'
            : 'Outside geofence (${distance.toStringAsFixed(0)}m from center, radius: ${radius}m)',
      };
    }
    
    return {'met': false, 'details': 'Location condition cannot be evaluated (missing position)'};
  }
  
  /// Evaluate activity-based condition
  Map<String, dynamic> _evaluateActivityCondition(Reminder reminder) {
    if (reminder.activityType == null) {
      return {'met': true, 'details': 'No activity condition specified'};
    }
    
    final currentActivity = _activityService.currentActivity;
    if (currentActivity == null) {
      return {'met': false, 'details': 'Activity detection unavailable'};
    }
    
    final currentActivityName = _activityService.getActivityName(currentActivity).toLowerCase();
    final requiredActivity = reminder.activityType!.toLowerCase();
    
    // Normalize activity names
    final activityMap = {
      'still': 'stationary',
      'stationary': 'still',
      'walking': 'walking',
      'running': 'running',
      'onbicycle': 'cycling',
      'cycling': 'onbicycle',
      'invehicle': 'driving',
      'driving': 'invehicle',
    };
    
    final normalizedCurrent = activityMap[currentActivityName] ?? currentActivityName;
    final normalizedRequired = activityMap[requiredActivity] ?? requiredActivity;
    
    final matches = normalizedCurrent == normalizedRequired ||
        currentActivityName == requiredActivity ||
        currentActivityName.contains(requiredActivity) ||
        requiredActivity.contains(currentActivityName);
    
    return {
      'met': matches,
      'details': matches
          ? 'Activity matched: $currentActivityName'
          : 'Activity not matched: required=$requiredActivity, current=$currentActivityName',
    };
  }
  
  /// Evaluate device state condition
  Map<String, dynamic> _evaluateDeviceStateCondition(Reminder reminder) {
    // For now, device state conditions are stored in reminder metadata
    // In future, add explicit fields: triggerOnChargingStart, triggerOnScreenUnlock, etc.
    
    // Check charging state (if reminder has charging-related trigger)
    // This would be set via reminder metadata or new fields
    // For now, always return true (no device state condition)
    return {'met': true, 'details': 'No device state condition specified'};
  }
  
  /// Calculate distance between two GPS coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Use Geolocator's distance calculation (more accurate)
    try {
      return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    } catch (e) {
      // Fallback to manual calculation
      const double earthRadius = 6371000; // meters
      
      final dLat = _toRadians(lat2 - lat1);
      final dLon = _toRadians(lon2 - lon1);
      
      final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
          math.cos(_toRadians(lat1)) *
              math.cos(_toRadians(lat2)) *
              math.sin(dLon / 2) *
              math.sin(dLon / 2);
      
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      
      return earthRadius * c;
    }
  }
  
  double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}

/// Result of rule evaluation
class RuleEvaluationResult {
  final bool shouldTrigger;
  final Map<String, bool> conditions;
  final Map<String, String> details;
  final DateTime timestamp;
  
  RuleEvaluationResult({
    required this.shouldTrigger,
    required this.conditions,
    required this.details,
    required this.timestamp,
  });
  
  @override
  String toString() {
    return 'RuleEvaluationResult(shouldTrigger: $shouldTrigger, conditions: $conditions)';
  }
}


