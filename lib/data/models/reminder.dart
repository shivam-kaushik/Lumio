import 'package:uuid/uuid.dart';

/// Priority levels for reminders
enum ReminderPriority {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case ReminderPriority.low:
        return 'Low';
      case ReminderPriority.medium:
        return 'Medium';
      case ReminderPriority.high:
        return 'High';
      case ReminderPriority.critical:
        return 'Critical';
    }
  }

  String get emoji {
    switch (this) {
      case ReminderPriority.low:
        return '🟢';
      case ReminderPriority.medium:
        return '🟡';
      case ReminderPriority.high:
        return '🟠';
      case ReminderPriority.critical:
        return '🔴';
    }
  }
}

/// Reminder categories
enum ReminderCategory {
  health,
  work,
  study,
  personal,
  shopping,
  family,
  other;

  String get displayName {
    switch (this) {
      case ReminderCategory.health:
        return 'Health';
      case ReminderCategory.work:
        return 'Work';
      case ReminderCategory.study:
        return 'Study';
      case ReminderCategory.personal:
        return 'Personal';
      case ReminderCategory.shopping:
        return 'Shopping';
      case ReminderCategory.family:
        return 'Family';
      case ReminderCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case ReminderCategory.health:
        return '💊';
      case ReminderCategory.work:
        return '💼';
      case ReminderCategory.study:
        return '📚';
      case ReminderCategory.personal:
        return '👤';
      case ReminderCategory.shopping:
        return '🛒';
      case ReminderCategory.family:
        return '👨‍👩‍👧‍👦';
      case ReminderCategory.other:
        return '📌';
    }
  }
}

/// Time of day preferences
enum TimeOfDay {
  morning, // 6 AM - 12 PM
  afternoon, // 12 PM - 5 PM
  evening, // 5 PM - 9 PM
  night, // 9 PM - 12 AM
  lateNight; // 12 AM - 6 AM

  String get displayName {
    switch (this) {
      case TimeOfDay.morning:
        return 'Morning (6 AM - 12 PM)';
      case TimeOfDay.afternoon:
        return 'Afternoon (12 PM - 5 PM)';
      case TimeOfDay.evening:
        return 'Evening (5 PM - 9 PM)';
      case TimeOfDay.night:
        return 'Night (9 PM - 12 AM)';
      case TimeOfDay.lateNight:
        return 'Late Night (12 AM - 6 AM)';
    }
  }

  /// Get start hour for this time of day
  int get startHour {
    switch (this) {
      case TimeOfDay.morning:
        return 6;
      case TimeOfDay.afternoon:
        return 12;
      case TimeOfDay.evening:
        return 17;
      case TimeOfDay.night:
        return 21;
      case TimeOfDay.lateNight:
        return 0;
    }
  }

  /// Get end hour for this time of day
  int get endHour {
    switch (this) {
      case TimeOfDay.morning:
        return 12;
      case TimeOfDay.afternoon:
        return 17;
      case TimeOfDay.evening:
        return 21;
      case TimeOfDay.night:
        return 24;
      case TimeOfDay.lateNight:
        return 6;
    }
  }
}

/// Reminder model representing a context-aware reminder
class Reminder {
  final String id;
  final String text;
  final DateTime? timeAt;
  final String? geofenceId;
  final double? geofenceLat;
  final double? geofenceLng;
  final double? geofenceRadius;
  final String? wifiSsid;
  final bool onLeaveContext;
  final bool onArriveContext;
  final String? weatherCondition; // e.g., 'rain'
  final bool enabled;
  final DateTime createdAt;
  final DateTime? lastTriggeredAt;
  final int triggerCount;

  // Recurrence fields
  final int?
      repeatInterval; // How many units to repeat (e.g., 2 for "every 2 hours")
  final String? repeatUnit; // 'minutes', 'hours', 'days', 'weeks'
  final DateTime? repeatEndDate; // When to stop repeating
  final List<int>? repeatOnDays; // Days of week (1=Monday, 7=Sunday)

  // Time range fields
  final DateTime? timeRangeStart; // Start of time range (e.g., 9 AM)
  final DateTime? timeRangeEnd; // End of time range (e.g., 6 PM)
  final TimeOfDay? preferredTimeOfDay; // Morning, Afternoon, etc.

  // Organization fields
  final ReminderPriority priority;
  final ReminderCategory category;

  // Smart features
  final bool isPaused; // Temporarily pause recurring reminders
  final int skipCount; // How many times user has skipped
  final bool keepRemindingUntilCompleted; // Re-notify every 5 minutes until completed
  
  // Activity-based triggers (from activity_recognition_service.dart)
  final String? activityType; // 'still', 'walking', 'running', 'onBicycle', 'inVehicle', 'onFoot'
  final bool useSmartTiming; // Use adaptive timing based on learned patterns

  // MVP: Skill linking
  final int? linkedSkillId; // Link reminder to skill for automatic rep logging
  
  // Core Features: Goal linking
  final int? linkedGoalId; // Link reminder directly to goal for categorization

  Reminder({
    String? id,
    required this.text,
    this.timeAt,
    this.geofenceId,
    this.geofenceLat,
    this.geofenceLng,
    this.geofenceRadius,
    this.wifiSsid,
    this.onLeaveContext = false,
    this.onArriveContext = false,
    this.weatherCondition,
    this.enabled = true,
    DateTime? createdAt,
    this.lastTriggeredAt,
    this.triggerCount = 0,
    this.repeatInterval,
    this.repeatUnit,
    this.repeatEndDate,
    this.repeatOnDays,
    this.timeRangeStart,
    this.timeRangeEnd,
    this.preferredTimeOfDay,
    this.priority = ReminderPriority.medium,
    this.category = ReminderCategory.other,
    this.isPaused = false,
    this.skipCount = 0,
    this.keepRemindingUntilCompleted = false,
    this.activityType,
    this.useSmartTiming = false,
    this.linkedSkillId,
    this.linkedGoalId,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Create Reminder from database map
  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as String,
      text: map['text'] as String,
      timeAt: map['timeAt'] != null
          ? DateTime.parse(map['timeAt'] as String)
          : null,
      geofenceId: map['geofenceId'] as String?,
      geofenceLat: map['geofenceLat'] as double?,
      geofenceLng: map['geofenceLng'] as double?,
      geofenceRadius: map['geofenceRadius'] as double?,
      wifiSsid: map['wifiSsid'] as String?,
      onLeaveContext: (map['onLeaveContext'] as int) == 1,
      onArriveContext: (map['onArriveContext'] as int) == 1,
      weatherCondition: map['weatherCondition'] as String?,
      enabled: (map['enabled'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastTriggeredAt: map['lastTriggeredAt'] != null
          ? DateTime.parse(map['lastTriggeredAt'] as String)
          : null,
      triggerCount: map['triggerCount'] as int? ?? 0,
      repeatInterval: map['repeatInterval'] as int?,
      repeatUnit: map['repeatUnit'] as String?,
      repeatEndDate: map['repeatEndDate'] != null
          ? DateTime.parse(map['repeatEndDate'] as String)
          : null,
      repeatOnDays: map['repeatOnDays'] != null
          ? (map['repeatOnDays'] as String)
              .split(',')
              .map((e) => int.parse(e))
              .toList()
          : null,
      timeRangeStart: map['timeRangeStart'] != null
          ? DateTime.parse(map['timeRangeStart'] as String)
          : null,
      timeRangeEnd: map['timeRangeEnd'] != null
          ? DateTime.parse(map['timeRangeEnd'] as String)
          : null,
      preferredTimeOfDay: map['preferredTimeOfDay'] != null
          ? TimeOfDay.values
              .firstWhere((e) => e.name == map['preferredTimeOfDay'] as String)
          : null,
      priority: map['priority'] != null
          ? ReminderPriority.values
              .firstWhere((e) => e.name == map['priority'] as String)
          : ReminderPriority.medium,
      category: map['category'] != null
          ? ReminderCategory.values
              .firstWhere((e) => e.name == map['category'] as String)
          : ReminderCategory.other,
      isPaused: (map['isPaused'] as int?) == 1,
      skipCount: map['skipCount'] as int? ?? 0,
      keepRemindingUntilCompleted: (map['keepRemindingUntilCompleted'] as int?) == 1,
      activityType: map['activityType'] as String?,
      useSmartTiming: (map['useSmartTiming'] as int?) == 1,
      linkedSkillId: map['linked_skill_id'] as int?,
      linkedGoalId: map['linked_goal_id'] as int?,
    );
  }

  /// Convert Reminder to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'timeAt': timeAt?.toIso8601String(),
      'geofenceId': geofenceId,
      'geofenceLat': geofenceLat,
      'geofenceLng': geofenceLng,
      'geofenceRadius': geofenceRadius,
      'wifiSsid': wifiSsid,
      'onLeaveContext': onLeaveContext ? 1 : 0,
      'onArriveContext': onArriveContext ? 1 : 0,
      'weatherCondition': weatherCondition,
      'enabled': enabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'lastTriggeredAt': lastTriggeredAt?.toIso8601String(),
      'triggerCount': triggerCount,
      'repeatInterval': repeatInterval,
      'repeatUnit': repeatUnit,
      'repeatEndDate': repeatEndDate?.toIso8601String(),
      'repeatOnDays': repeatOnDays?.join(','),
      'timeRangeStart': timeRangeStart?.toIso8601String(),
      'timeRangeEnd': timeRangeEnd?.toIso8601String(),
      'preferredTimeOfDay': preferredTimeOfDay?.name,
      'priority': priority.name,
      'category': category.name,
      'isPaused': isPaused ? 1 : 0,
      'skipCount': skipCount,
      'keepRemindingUntilCompleted': keepRemindingUntilCompleted ? 1 : 0,
      'activityType': activityType,
      'useSmartTiming': useSmartTiming ? 1 : 0,
      'linked_skill_id': linkedSkillId,
      'linked_goal_id': linkedGoalId,
    };
  }

  /// Get context type icons
  List<String> getContextIcons() {
    final icons = <String>[];
    if (timeAt != null) icons.add('⏰');
    if (geofenceId != null) icons.add('📍');
    if (wifiSsid != null) icons.add('📶');
    if (onLeaveContext) icons.add('🚪');
    if (onArriveContext) icons.add('🏠');
    return icons;
  }

  /// Get context description
  String getContextDescription() {
    final parts = <String>[];

    // Priority
    parts.add('${priority.emoji} ${priority.displayName}');

    // Recurrence with end date
    if (repeatInterval != null && repeatUnit != null) {
      String recurText = 'Every $repeatInterval $repeatUnit';

      if (timeRangeStart != null && timeRangeEnd != null) {
        recurText +=
            ' (${_formatTime(timeRangeStart!)} - ${_formatTime(timeRangeEnd!)})';
      } else if (preferredTimeOfDay != null) {
        recurText += ' (${preferredTimeOfDay!.displayName})';
      }

      if (repeatEndDate != null) {
        recurText += ' until ${_formatDate(repeatEndDate!)}';
      }

      if (repeatOnDays != null && repeatOnDays!.isNotEmpty) {
        recurText += ' on ${_formatDays(repeatOnDays!)}';
      }

      parts.add(recurText);
    } else if (timeAt != null) {
      parts.add('at ${_formatTime(timeAt!)} on ${_formatDate(timeAt!)}');
    }

    if (onLeaveContext && geofenceId != null) {
      parts.add('when leaving');
    }
    if (onArriveContext && geofenceId != null) {
      parts.add('when arriving');
    }
    if (wifiSsid != null) {
      parts.add('via Wi-Fi: $wifiSsid');
    }
    if (weatherCondition != null) {
      parts.add('if ${weatherCondition}');
    }

    if (isPaused) {
      parts.add('⏸️ Paused');
    }

    return parts.isEmpty ? 'No context set' : parts.join(' • ');
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDays(List<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => dayNames[d - 1]).join(', ');
  }

  /// Check if this is a recurring reminder
  bool get isRecurring => repeatInterval != null && repeatUnit != null;

  /// Copy with method for updates
  Reminder copyWith({
    String? text,
    DateTime? timeAt,
    String? geofenceId,
    double? geofenceLat,
    double? geofenceLng,
    double? geofenceRadius,
    String? wifiSsid,
    bool? onLeaveContext,
    bool? onArriveContext,
    String? weatherCondition,
    bool? enabled,
    DateTime? lastTriggeredAt,
    int? triggerCount,
    int? repeatInterval,
    String? repeatUnit,
    DateTime? repeatEndDate,
    List<int>? repeatOnDays,
    DateTime? timeRangeStart,
    DateTime? timeRangeEnd,
    TimeOfDay? preferredTimeOfDay,
    ReminderPriority? priority,
    ReminderCategory? category,
    bool? isPaused,
    int? skipCount,
    bool? keepRemindingUntilCompleted,
    int? linkedSkillId,
    int? linkedGoalId,
  }) {
    return Reminder(
      id: id,
      text: text ?? this.text,
      timeAt: timeAt ?? this.timeAt,
      geofenceId: geofenceId ?? this.geofenceId,
      geofenceLat: geofenceLat ?? this.geofenceLat,
      geofenceLng: geofenceLng ?? this.geofenceLng,
      geofenceRadius: geofenceRadius ?? this.geofenceRadius,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      onLeaveContext: onLeaveContext ?? this.onLeaveContext,
      onArriveContext: onArriveContext ?? this.onArriveContext,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      triggerCount: triggerCount ?? this.triggerCount,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatUnit: repeatUnit ?? this.repeatUnit,
      repeatEndDate: repeatEndDate ?? this.repeatEndDate,
      repeatOnDays: repeatOnDays ?? this.repeatOnDays,
      timeRangeStart: timeRangeStart ?? this.timeRangeStart,
      timeRangeEnd: timeRangeEnd ?? this.timeRangeEnd,
      preferredTimeOfDay: preferredTimeOfDay ?? this.preferredTimeOfDay,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isPaused: isPaused ?? this.isPaused,
      skipCount: skipCount ?? this.skipCount,
      keepRemindingUntilCompleted: keepRemindingUntilCompleted ?? this.keepRemindingUntilCompleted,
      activityType: activityType ?? this.activityType,
      useSmartTiming: useSmartTiming ?? this.useSmartTiming,
      linkedSkillId: linkedSkillId ?? this.linkedSkillId,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
    );
  }
}
