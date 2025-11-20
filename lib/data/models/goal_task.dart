import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot, Timestamp, FieldValue;

/// Goal task model for database storage
class GoalTask {
  final int id;
  final int goalId;
  final String title;
  final String description;
  final double? estimatedHours;
  final String priority; // 'high', 'medium', 'low'
  final String frequency; // 'daily', 'weekly', 'monthly', 'one-time'
  final String suggestedTime; // 'morning', 'afternoon', 'evening', 'any'
  final String suggestedLocation; // 'home', 'office', 'coffee_shop', 'any'
  final bool isMilestone;
  final String? motivationAnchor;
  final DateTime? scheduledDate;
  final int? phaseId; // Link to goal phase
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  GoalTask({
    required this.id,
    required this.goalId,
    required this.title,
    required this.description,
    this.estimatedHours,
    this.priority = 'medium',
    this.frequency = 'one-time',
    this.suggestedTime = 'any',
    this.suggestedLocation = 'any',
    this.isMilestone = false,
    this.motivationAnchor,
    this.scheduledDate,
    this.phaseId,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
  });

  /// Create GoalTask from database map
  factory GoalTask.fromMap(Map<String, dynamic> map) {
    return GoalTask(
      id: map['id'] as int,
      goalId: map['goal_id'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      estimatedHours: map['estimated_hours'] != null
          ? (map['estimated_hours'] is double
              ? map['estimated_hours'] as double
              : (map['estimated_hours'] as num).toDouble())
          : null,
      priority: map['priority'] as String? ?? 'medium',
      frequency: map['frequency'] as String? ?? 'one-time',
      suggestedTime: map['suggested_time'] as String? ?? 'any',
      suggestedLocation: map['suggested_location'] as String? ?? 'any',
      isMilestone: (map['is_milestone'] as int? ?? 0) == 1,
      motivationAnchor: map['motivation_anchor'] as String?,
      scheduledDate: map['scheduled_date'] != null
          ? DateTime.parse(map['scheduled_date'] as String)
          : null,
      phaseId: map['phase_id'] as int?,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert GoalTask to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'title': title,
      'description': description,
      'estimated_hours': estimatedHours,
      'priority': priority,
      'frequency': frequency,
      'suggested_time': suggestedTime,
      'suggested_location': suggestedLocation,
      'is_milestone': isMilestone ? 1 : 0,
      'motivation_anchor': motivationAnchor,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'phase_id': phaseId,
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create map for insertion (without id)
  Map<String, dynamic> toInsertMap() {
    return {
      'goal_id': goalId,
      'title': title,
      'description': description,
      'estimated_hours': estimatedHours,
      'priority': priority,
      'frequency': frequency,
      'suggested_time': suggestedTime,
      'suggested_location': suggestedLocation,
      'is_milestone': isMilestone ? 1 : 0,
      'motivation_anchor': motivationAnchor,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'phase_id': phaseId,
      'is_completed': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Copy with method
  GoalTask copyWith({
    int? id,
    int? goalId,
    String? title,
    String? description,
    double? estimatedHours,
    String? priority,
    String? frequency,
    String? suggestedTime,
    String? suggestedLocation,
    bool? isMilestone,
    String? motivationAnchor,
    DateTime? scheduledDate,
    int? phaseId,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return GoalTask(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      priority: priority ?? this.priority,
      frequency: frequency ?? this.frequency,
      suggestedTime: suggestedTime ?? this.suggestedTime,
      suggestedLocation: suggestedLocation ?? this.suggestedLocation,
      isMilestone: isMilestone ?? this.isMilestone,
      motivationAnchor: motivationAnchor ?? this.motivationAnchor,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      phaseId: phaseId ?? this.phaseId,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Create GoalTask from Firestore document
  factory GoalTask.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GoalTask(
      id: int.parse(doc.id),
      goalId: int.parse(data['goalId'] as String),
      title: data['title'] as String,
      description: data['description'] as String,
      estimatedHours: (data['estimatedHours'] as num?)?.toDouble(),
      priority: data['priority'] as String? ?? 'medium',
      frequency: data['frequency'] as String? ?? 'one-time',
      suggestedTime: data['suggestedTime'] as String? ?? 'any',
      suggestedLocation: data['suggestedLocation'] as String? ?? 'any',
      isMilestone: data['isMilestone'] as bool? ?? false,
      motivationAnchor: data['motivationAnchor'] as String?,
      scheduledDate: data['scheduledDate'] != null
          ? (data['scheduledDate'] is Timestamp
              ? (data['scheduledDate'] as Timestamp).toDate()
              : DateTime.parse(data['scheduledDate'] as String))
          : null,
      phaseId: data['phaseId'] != null ? int.parse(data['phaseId'] as String) : null,
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] is Timestamp
              ? (data['completedAt'] as Timestamp).toDate()
              : DateTime.parse(data['completedAt'] as String))
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : DateTime.parse(data['createdAt'] as String))
          : DateTime.now(),
    );
  }

  /// Convert GoalTask to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'goalId': goalId.toString(),
      'title': title,
      'description': description,
      'estimatedHours': estimatedHours,
      'priority': priority,
      'frequency': frequency,
      'suggestedTime': suggestedTime,
      'suggestedLocation': suggestedLocation,
      'isMilestone': isMilestone,
      'motivationAnchor': motivationAnchor,
      'scheduledDate': scheduledDate != null ? Timestamp.fromDate(scheduledDate!) : null,
      'phaseId': phaseId?.toString(),
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

