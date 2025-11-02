import 'package:uuid/uuid.dart';

/// Represents a single occurrence of a reminder (especially for recurring reminders)
/// Each occurrence has its own completion status
class ReminderOccurrence {
  final String id;
  final String reminderId;
  final DateTime scheduledTime; // When this occurrence is scheduled
  final bool isCompleted;
  final DateTime? completedAt;
  final int notificationId; // The notification ID for this occurrence

  ReminderOccurrence({
    String? id,
    required this.reminderId,
    required this.scheduledTime,
    this.isCompleted = false,
    this.completedAt,
    required this.notificationId,
  }) : id = id ?? const Uuid().v4();

  /// Create ReminderOccurrence from database map
  factory ReminderOccurrence.fromMap(Map<String, dynamic> map) {
    return ReminderOccurrence(
      id: map['id'] as String,
      reminderId: map['reminderId'] as String,
      scheduledTime: DateTime.parse(map['scheduledTime'] as String),
      isCompleted: (map['isCompleted'] as int) == 1,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      notificationId: map['notificationId'] as int,
    );
  }

  /// Convert ReminderOccurrence to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminderId': reminderId,
      'scheduledTime': scheduledTime.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
      'notificationId': notificationId,
    };
  }

  /// Mark this occurrence as completed
  ReminderOccurrence markCompleted() {
    return ReminderOccurrence(
      id: id,
      reminderId: reminderId,
      scheduledTime: scheduledTime,
      isCompleted: true,
      completedAt: DateTime.now(),
      notificationId: notificationId,
    );
  }

  /// Copy with method for updates
  ReminderOccurrence copyWith({
    String? reminderId,
    DateTime? scheduledTime,
    bool? isCompleted,
    DateTime? completedAt,
    int? notificationId,
  }) {
    return ReminderOccurrence(
      id: id,
      reminderId: reminderId ?? this.reminderId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      notificationId: notificationId ?? this.notificationId,
    );
  }
}

