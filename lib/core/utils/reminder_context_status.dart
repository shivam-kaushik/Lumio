import 'package:geolocator/geolocator.dart';
import '../../data/models/reminder.dart';
import '../services/home_detection_service.dart';
import '../services/activity_recognition_service.dart';

/// Context status information for a reminder
class ReminderContextStatus {
  final Reminder reminder;
  final bool isReady; // Conditions are currently met
  final String statusText; // Human-readable status
  final double? distance; // Distance from location (in meters, null if not location-based)
  final bool isAtLocation;
  final String? currentActivity;

  ReminderContextStatus({
    required this.reminder,
    required this.isReady,
    required this.statusText,
    this.distance,
    this.isAtLocation = false,
    this.currentActivity,
  });

  /// Format distance for display
  String getFormattedDistance() {
    if (distance == null) return '';
    
    if (distance! < 1000) {
      return '${distance!.toStringAsFixed(0)}m away';
    } else {
      return '${(distance! / 1000).toStringAsFixed(1)}km away';
    }
  }

  /// Get status icon
  String getStatusIcon() {
    if (isReady) return '✅';
    if (distance != null && distance! > 0) return '⏳';
    return '🔔';
  }
}

/// Utility class for calculating reminder context status
class ReminderStatusCalculator {
  static final HomeDetectionService _homeService = HomeDetectionService();

  /// Calculate context status for a list of reminders
  static Future<List<ReminderContextStatus>> calculateStatuses(
    List<Reminder> reminders, {
    Position? currentPosition,
    String? currentActivity,
  }) async {
    final statuses = <ReminderContextStatus>[];

    for (var reminder in reminders) {
      final status = await calculateStatus(
        reminder,
        currentPosition: currentPosition,
        currentActivity: currentActivity,
      );
      statuses.add(status);
    }

    return statuses;
  }

  /// Calculate context status for a single reminder
  static Future<ReminderContextStatus> calculateStatus(
    Reminder reminder, {
    Position? currentPosition,
    String? currentActivity,
  }) async {
    bool isReady = false;
    String statusText = 'Waiting for context';
    double? distance;
    bool isAtLocation = false;

    // Check location-based conditions
    if (reminder.geofenceId != null || 
        reminder.geofenceLat != null || 
        reminder.geofenceLng != null) {
      if (reminder.geofenceId == 'home') {
        // Home-based reminder
        isAtLocation = await _homeService.isAtHome();
        
        if (reminder.onArriveContext && isAtLocation) {
          isReady = true;
          statusText = 'At Home - Ready';
        } else if (reminder.onLeaveContext && !isAtLocation) {
          isReady = true;
          statusText = 'Left Home - Ready';
        } else if (isAtLocation) {
          statusText = 'At Home - Waiting for leave';
        } else {
          statusText = 'Not at Home - Waiting for arrival';
        }
      } else if (reminder.geofenceLat != null && 
                 reminder.geofenceLng != null && 
                 currentPosition != null) {
        // Custom location geofence
        distance = Geolocator.distanceBetween(
          currentPosition.latitude,
          currentPosition.longitude,
          reminder.geofenceLat!,
          reminder.geofenceLng!,
        );

        final radius = reminder.geofenceRadius ?? 100.0;
        isAtLocation = distance <= radius;

        if (reminder.onArriveContext && isAtLocation) {
          isReady = true;
          statusText = 'Inside geofence - Ready';
        } else if (reminder.onLeaveContext && !isAtLocation) {
          isReady = true;
          statusText = 'Outside geofence - Ready';
        } else if (isAtLocation) {
          statusText = 'Inside geofence - Waiting for leave';
        } else {
          statusText = 'Outside geofence - Waiting for arrival';
        }
      }
    }


    // Check activity-based conditions
    if (reminder.activityType != null && currentActivity != null) {
      final matchesActivity = currentActivity.toLowerCase() == 
          reminder.activityType!.toLowerCase();
      if (matchesActivity && !isReady) {
        isReady = true;
        statusText = 'Activity detected: $currentActivity - Ready';
      } else if (!matchesActivity && reminder.activityType != null) {
        statusText = 'Waiting for activity: ${reminder.activityType}';
      }
    }

    // If no context conditions, check time-based
    if (reminder.geofenceId == null && 
        reminder.geofenceLat == null && 
        reminder.activityType == null) {
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
      distance: distance,
      isAtLocation: isAtLocation,
      currentActivity: currentActivity,
    );
  }

  /// Group reminders by location with status
  static Future<Map<String, List<ReminderContextStatus>>> groupByLocationWithStatus(
    List<Reminder> reminders, {
    Position? currentPosition,
    String? currentActivity,
  }) async {
    final statuses = await calculateStatuses(
      reminders,
      currentPosition: currentPosition,
      currentActivity: currentActivity,
    );

    final groups = <String, List<ReminderContextStatus>>{};

    for (var status in statuses) {
      final locationKey = status.reminder.geofenceId ?? 
          (status.reminder.geofenceLat != null ? 'Custom Location' : 'Other');
      groups.putIfAbsent(locationKey, () => []).add(status);
    }

    return groups;
  }
}

