/// Goal model for business goals
class Goal {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime? targetDeadline;
  final double? hoursPerDay;
  final int? totalEstimatedHours;

  Goal({
    required this.id,
    required this.name,
    required this.createdAt,
    this.targetDeadline,
    this.hoursPerDay,
    this.totalEstimatedHours,
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
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      targetDeadline: targetDeadline ?? this.targetDeadline,
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      totalEstimatedHours: totalEstimatedHours ?? this.totalEstimatedHours,
    );
  }
}

