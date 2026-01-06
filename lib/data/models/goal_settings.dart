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

  // From Map
  factory GoalSettings.fromMap(Map<String, dynamic> map) {
    TimeOfDay? time;
    if (map['notificationTime'] != null) {
      final parts = (map['notificationTime'] as String).split(':');
      if (parts.length == 2) {
        time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }

    return GoalSettings(
      notificationTime: time,
      frequency: NotificationFrequency.values[map['frequency'] as int? ?? 1], // default daily
      alertTiming: AlertTiming.values[map['alertTiming'] as int? ?? 2], // default 15 min
      customAlertMinutes: map['customAlertMinutes'] as int?,
      tone: NotificationTone.values[map['tone'] as int? ?? 0], // default motivational
      enableNotifications: map['enableNotifications'] as bool? ?? true,
    );
  }
}
