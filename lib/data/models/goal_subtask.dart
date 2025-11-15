/// Goal subtask model for database storage
class GoalSubtask {
  final int id;
  final int goalId;
  final int? skillId; // Link to skill for rep tracking
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
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  GoalSubtask({
    required this.id,
    required this.goalId,
    this.skillId,
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
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
  });

  /// Create GoalSubtask from database map
  factory GoalSubtask.fromMap(Map<String, dynamic> map) {
    return GoalSubtask(
      id: map['id'] as int,
      goalId: map['goal_id'] as int,
      skillId: map['skill_id'] as int?,
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
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert GoalSubtask to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'skill_id': skillId,
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
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create map for insertion (without id)
  Map<String, dynamic> toInsertMap() {
    return {
      'goal_id': goalId,
      'skill_id': skillId,
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
      'is_completed': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Copy with method
  GoalSubtask copyWith({
    int? id,
    int? goalId,
    int? skillId,
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
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return GoalSubtask(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      skillId: skillId ?? this.skillId,
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
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

