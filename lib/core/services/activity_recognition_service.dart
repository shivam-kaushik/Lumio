import 'dart:async';
import 'package:flutter/foundation.dart';

/// Service for detecting device activity (walking, driving, stationary, etc.)
/// Note: Activity detection without GPS is stubbed - always returns stationary.
class ActivityRecognitionService {
  ActivityType? _currentActivity;
  void Function(ActivityType activity)? _onActivityChanged;

  ActivityType? get currentActivity => _currentActivity;

  /// Start monitoring device activity
  Future<void> startMonitoring({
    void Function(ActivityType activity)? onActivityChanged,
  }) async {
    _onActivityChanged = onActivityChanged;
    _currentActivity = ActivityType.still;

    if (kDebugMode) {
      print('✅ Activity Recognition: Started (activity detection stubbed - no GPS)');
    }
  }

  /// Stop monitoring activity
  Future<void> stopMonitoring() async {
    _currentActivity = null;
    _onActivityChanged = null;

    if (kDebugMode) {
      print('🛑 Activity Recognition: Stopped');
    }
  }

  /// Get human-readable activity name
  String getActivityName(ActivityType? activity) {
    if (activity == null) return 'Unknown';
    switch (activity) {
      case ActivityType.still:
        return 'Stationary';
      case ActivityType.walking:
        return 'Walking';
      case ActivityType.running:
        return 'Running';
      case ActivityType.onBicycle:
        return 'Cycling';
      case ActivityType.inVehicle:
        return 'Driving';
      case ActivityType.onFoot:
        return 'On Foot';
      case ActivityType.unknown:
        return 'Unknown';
    }
  }

  bool get isDriving => _currentActivity == ActivityType.inVehicle;
  bool get isWalking => _currentActivity == ActivityType.walking;
  bool get isStationary => _currentActivity == ActivityType.still;
}

/// Activity types that can be detected
enum ActivityType {
  still,
  walking,
  running,
  onBicycle,
  inVehicle,
  onFoot,
  unknown,
}
