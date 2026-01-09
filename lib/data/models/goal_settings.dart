import 'package:flutter/material.dart';

enum NotificationFrequency {
  once,
  daily,
  weekly,
  monthly,
  deadline,
}

enum AlertTiming {
  atStart,
  atEnd,
  fifteenMinBefore,
  custom,
}

enum NotificationTone {
  motivational,
  funny,
  severe, // "Do it now or else" style
  quotes,
}

class GoalSettings {
  final TimeOfDay? notificationTime;
  final NotificationFrequency frequency;
  final AlertTiming alertTiming;
  final int? customAlertMinutes; // Used if alertTiming == custom
  final NotificationTone tone;
  final bool enableNotifications;

  GoalSettings({
    this.notificationTime,
    this.frequency = NotificationFrequency.daily,
    this.alertTiming = AlertTiming.fifteenMinBefore,
    this.customAlertMinutes,
    this.tone = NotificationTone.motivational,
    this.enableNotifications = true,
  });

  // CopyWith
  GoalSettings copyWith({
    TimeOfDay? notificationTime,
    NotificationFrequency? frequency,
    AlertTiming? alertTiming,
    int? customAlertMinutes,
    NotificationTone? tone,
    bool? enableNotifications,
  }) {
    return GoalSettings(
      notificationTime: notificationTime ?? this.notificationTime,
      frequency: frequency ?? this.frequency,
      alertTiming: alertTiming ?? this.alertTiming,
      customAlertMinutes: customAlertMinutes ?? this.customAlertMinutes,
      tone: tone ?? this.tone,
      enableNotifications: enableNotifications ?? this.enableNotifications,
    );
  }

  // To Map
  Map<String, dynamic> toMap() {
    return {
      'notificationTime': notificationTime != null 
          ? '${notificationTime!.hour}:${notificationTime!.minute}' 
          : null,
      'frequency': frequency.index,
      'alertTiming': alertTiming.index,
      'customAlertMinutes': customAlertMinutes,
      'tone': tone.index,
      'enableNotifications': enableNotifications,
    };
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GoalSettings &&
        other.frequency == frequency &&
        other.notificationTime?.hour == notificationTime?.hour &&
        other.notificationTime?.minute == notificationTime?.minute &&
        other.tone == tone &&
        other.alertTiming == alertTiming &&
        other.customAlertMinutes == customAlertMinutes &&
        other.enableNotifications == enableNotifications;
  }

  @override
  int get hashCode => Object.hash(
     frequency, 
     notificationTime?.hour,
     notificationTime?.minute, 
     tone, 
     alertTiming, 
     customAlertMinutes, 
     enableNotifications
  );

  // From Map
  factory GoalSettings.fromMap(Map<String, dynamic> map) {
    TimeOfDay? time;
    try {
      if (map['notificationTime'] != null && map['notificationTime'] is String) {
        final parts = (map['notificationTime'] as String).split(':');
        if (parts.length == 2) {
          time = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9, 
            minute: int.tryParse(parts[1]) ?? 0
          );
        }
      }
    } catch (_) {}

    T getEnum<T>(List<T> values, dynamic index, T defaultValue) {
      if (index is int && index >= 0 && index < values.length) {
        return values[index];
      }
      return defaultValue;
    }

    return GoalSettings(
      notificationTime: time,
      frequency: getEnum(NotificationFrequency.values, map['frequency'], NotificationFrequency.daily),
      alertTiming: getEnum(AlertTiming.values, map['alertTiming'], AlertTiming.fifteenMinBefore),
      customAlertMinutes: map['customAlertMinutes'] as int?,
      tone: getEnum(NotificationTone.values, map['tone'], NotificationTone.motivational),
      enableNotifications: map['enableNotifications'] as bool? ?? true,
    );
  }
}
