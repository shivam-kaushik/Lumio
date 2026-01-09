import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot, Timestamp, FieldValue;
import 'goal_settings.dart';

/// Goal model for business goals
class Goal {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? targetDeadline;
  final double? hoursPerDay;
  final int? totalEstimatedHours;
  final GoalSettings? settings;

  Goal({
    required this.id,
    required this.name,
    required this.createdAt,
    this.targetDeadline,
    this.hoursPerDay,
    this.totalEstimatedHours,
    this.settings,
  });

  /// Create Goal from database map
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      targetDeadline: map['target_deadline'] != null
          ? DateTime.parse(map['target_deadline'] as String)
          : null,
      hoursPerDay: map['hours_per_day'] != null
          ? (map['hours_per_day'] is double
              ? map['hours_per_day'] as double
              : (map['hours_per_day'] as num).toDouble())
          : null,
      totalEstimatedHours: map['total_estimated_hours'] as int?,
      settings: map['settings'] != null 
          ? GoalSettings.fromMap(Map<String, dynamic>.from(map['settings'] as Map))
          : null,
    );
  }

  /// Convert Goal to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'target_deadline': targetDeadline?.toIso8601String(),
      'hours_per_day': hoursPerDay,
      'total_estimated_hours': totalEstimatedHours,
      'settings': settings?.toMap(),
    };
  }

  /// Create map for insertion (without id)
  Map<String, dynamic> toInsertMap() {
    return {
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'target_deadline': targetDeadline?.toIso8601String(),
      'hours_per_day': hoursPerDay,
      'total_estimated_hours': totalEstimatedHours,
      'settings': settings?.toMap(),
    };
  }

  /// Copy with method
  Goal copyWith({
    int? id,
    String? name,
    DateTime? createdAt,
    DateTime? targetDeadline,
    double? hoursPerDay,
    int? totalEstimatedHours,
    GoalSettings? settings,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      targetDeadline: targetDeadline ?? this.targetDeadline,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      totalEstimatedHours: totalEstimatedHours ?? this.totalEstimatedHours,
      settings: settings ?? this.settings,
    );
  }

  /// Create Goal from Firestore document
  factory Goal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Goal(
      id: int.parse(doc.id), // Firestore uses string IDs, convert to int
      name: data['name'] as String,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.parse(data['createdAt'] as String))
          : DateTime.now(),
      targetDeadline: data['targetDeadline'] != null
          ? (data['targetDeadline'] is Timestamp
              ? (data['targetDeadline'] as Timestamp).toDate()
              : DateTime.parse(data['targetDeadline'] as String))
          : null,
      hoursPerDay: (data['hoursPerDay'] as num?)?.toDouble(),
      totalEstimatedHours: data['totalEstimatedHours'] as int?,
      settings: data['settings'] != null 
          ? GoalSettings.fromMap(Map<String, dynamic>.from(data['settings'] as Map))
          : null,
    );
  }

  /// Convert Goal to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetDeadline': targetDeadline != null ? Timestamp.fromDate(targetDeadline!) : null,
      'hoursPerDay': hoursPerDay,
      'totalEstimatedHours': totalEstimatedHours,
      'settings': settings?.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

