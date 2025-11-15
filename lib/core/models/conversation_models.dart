import '../../data/models/reminder.dart';

/// Intent types for reminder creation
enum IntentType {
  timeBased,
  locationBased,
  activityBased,
  recurring,
  weatherBased,
  ambiguous,
}

/// Conversation state
enum ConversationState {
  idle,
  collecting,
  confirming,
  completed,
  cancelled,
  goalSetting, // MVP: Setting a business goal
  goalAskingDeadline, // Asking for target deadline
  goalAskingCapacity, // Asking for hours/day commitment
  goalConfirming, // MVP: Confirming goal roadmap
}

/// Message role in conversation
enum MessageRole {
  user,
  assistant,
  system,
}

/// Message type
enum MessageType {
  text,
  audio,
  suggestion,
}

/// Conversation message
class ConversationMessage {
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final MessageType type;

  ConversationMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
  });
}

/// Reminder draft (partially filled reminder)
class ReminderDraft {
  String? text;
  DateTime? timeAt;
  ReminderPriority? priority;
  ReminderCategory? category;
  int? repeatInterval;
  String? repeatUnit;
  DateTime? repeatEndDate;
  List<int>? repeatOnDays;
  String? geofenceId;
  double? geofenceLat;
  double? geofenceLng;
  double? geofenceRadius;
  bool? onLeaveContext;
  bool? onArriveContext;
  String? weatherCondition;
  String? activityType;
  IntentType? intent;

  ReminderDraft();

  /// Check if a required field is present
  bool hasField(String fieldName) {
    switch (fieldName) {
      case 'text':
        return text != null && text!.isNotEmpty;
      case 'time':
        // Check if timeAt is set and is a valid future/present time
        if (timeAt == null) return false;
        // Additional check: make sure it's a valid DateTime
        try {
          final t = timeAt!;
          return t.year > 2000 && t.year < 2100; // Sanity check
        } catch (e) {
          return false;
        }
      case 'location':
        return geofenceId != null ||
            (geofenceLat != null && geofenceLng != null);
      case 'locationTrigger':
        return onLeaveContext == true || onArriveContext == true;
      case 'recurrence':
        return repeatInterval != null && repeatUnit != null;
      case 'repeatInterval':
        return repeatInterval != null;
      case 'repeatUnit':
        return repeatUnit != null;
      case 'activity':
        return activityType != null;
      case 'weather':
        return weatherCondition != null;
      default:
        return false;
    }
  }

  /// Convert to map for serialization
  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'timeAt': timeAt?.toIso8601String(),
      'priority': priority?.name,
      'category': category?.name,
      'repeatInterval': repeatInterval,
      'repeatUnit': repeatUnit,
      'repeatEndDate': repeatEndDate?.toIso8601String(),
      'repeatOnDays': repeatOnDays,
      'geofenceId': geofenceId,
      'geofenceLat': geofenceLat,
      'geofenceLng': geofenceLng,
      'geofenceRadius': geofenceRadius,
      'onLeaveContext': onLeaveContext,
      'onArriveContext': onArriveContext,
      'weatherCondition': weatherCondition,
      'activityType': activityType,
      'intent': intent?.name,
    };
  }

  /// Create from map
  factory ReminderDraft.fromMap(Map<String, dynamic> map) {
    final draft = ReminderDraft()
      ..text = map['text'] as String?
      ..timeAt = map['timeAt'] != null
          ? DateTime.parse(map['timeAt'] as String)
          : null
      ..priority = map['priority'] != null
          ? ReminderPriority.values.firstWhere(
              (e) => e.name == map['priority'],
              orElse: () => ReminderPriority.medium,
            )
          : null
      ..category = map['category'] != null
          ? ReminderCategory.values.firstWhere(
              (e) => e.name == map['category'],
              orElse: () => ReminderCategory.other,
            )
          : null
      ..repeatInterval = map['repeatInterval'] as int?
      ..repeatUnit = map['repeatUnit'] as String?
      ..repeatEndDate = map['repeatEndDate'] != null
          ? DateTime.parse(map['repeatEndDate'] as String)
          : null
      ..repeatOnDays = map['repeatOnDays'] != null
          ? (map['repeatOnDays'] as List).cast<int>()
          : null
      ..geofenceId = map['geofenceId'] as String?
      ..geofenceLat = map['geofenceLat'] as double?
      ..geofenceLng = map['geofenceLng'] as double?
      ..geofenceRadius = map['geofenceRadius'] as double?
      ..onLeaveContext = map['onLeaveContext'] as bool?
      ..onArriveContext = map['onArriveContext'] as bool?
      ..weatherCondition = map['weatherCondition'] as String?
      ..activityType = map['activityType'] as String?
      ..intent = map['intent'] != null
          ? IntentType.values.firstWhere(
              (e) => e.name == map['intent'],
            )
          : null;
    return draft;
  }

  /// Copy with updates
  ReminderDraft copyWith(Map<String, dynamic> updates) {
    final draft = ReminderDraft()
      ..text = updates['text'] as String? ?? text
      ..timeAt = updates['timeAt'] != null
          ? (updates['timeAt'] is DateTime
              ? updates['timeAt'] as DateTime
              : DateTime.parse(updates['timeAt'] as String))
          : timeAt
      ..priority = updates['priority'] != null
          ? (updates['priority'] is ReminderPriority
              ? updates['priority'] as ReminderPriority
              : ReminderPriority.values.firstWhere(
                  (e) => e.name == updates['priority'],
                  orElse: () => priority ?? ReminderPriority.medium,
                ))
          : priority
      ..category = updates['category'] != null
          ? (updates['category'] is ReminderCategory
              ? updates['category'] as ReminderCategory
              : ReminderCategory.values.firstWhere(
                  (e) => e.name == updates['category'],
                  orElse: () => category ?? ReminderCategory.other,
                ))
          : category
      ..repeatInterval = updates['repeatInterval'] as int? ?? repeatInterval
      ..repeatUnit = updates['repeatUnit'] as String? ?? repeatUnit
      ..repeatEndDate = updates['repeatEndDate'] != null
          ? (updates['repeatEndDate'] is DateTime
              ? updates['repeatEndDate'] as DateTime
              : DateTime.parse(updates['repeatEndDate'] as String))
          : repeatEndDate
      ..repeatOnDays = updates['repeatOnDays'] != null
          ? (updates['repeatOnDays'] as List).cast<int>()
          : repeatOnDays
      ..geofenceId = updates['geofenceId'] as String? ?? geofenceId
      ..geofenceLat = updates['geofenceLat'] as double? ?? geofenceLat
      ..geofenceLng = updates['geofenceLng'] as double? ?? geofenceLng
      ..geofenceRadius =
          updates['geofenceRadius'] as double? ?? geofenceRadius
      ..onLeaveContext =
          updates['onLeaveContext'] as bool? ?? onLeaveContext
      ..onArriveContext =
          updates['onArriveContext'] as bool? ?? onArriveContext
      ..weatherCondition =
          updates['weatherCondition'] as String? ?? weatherCondition
      ..activityType = updates['activityType'] as String? ?? activityType
      ..intent = updates['intent'] != null
          ? (updates['intent'] is IntentType
              ? updates['intent'] as IntentType
              : IntentType.values.firstWhere(
                  (e) => e.name == updates['intent'],
                ))
          : intent;
    return draft;
  }

  /// Convert to Reminder object
  Reminder toReminder() {
    return Reminder(
      text: text ?? '',
      timeAt: timeAt,
      priority: priority ?? ReminderPriority.medium,
      category: category ?? ReminderCategory.other,
      repeatInterval: repeatInterval,
      repeatUnit: repeatUnit,
      repeatEndDate: repeatEndDate,
      repeatOnDays: repeatOnDays,
      geofenceId: geofenceId,
      geofenceLat: geofenceLat,
      geofenceLng: geofenceLng,
      geofenceRadius: geofenceRadius,
      onLeaveContext: onLeaveContext ?? false,
      onArriveContext: onArriveContext ?? false,
      weatherCondition: weatherCondition,
      activityType: activityType,
    );
  }
}

/// Local parse result
class LocalParseResult {
  final Map<String, dynamic> extracted;
  final double confidence; // 0.0 to 1.0
  final bool needsGpt;
  final List<String> missingFields;
  final IntentType? intent;

  LocalParseResult({
    required this.extracted,
    required this.confidence,
    required this.needsGpt,
    required this.missingFields,
    this.intent,
  });
}

/// GPT response
class GptResponse {
  final String question;
  final String? field;
  final Map<String, dynamic>? extractedData;

  GptResponse({
    required this.question,
    this.field,
    this.extractedData,
  });
}
