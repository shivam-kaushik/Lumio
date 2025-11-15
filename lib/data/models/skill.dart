/// Skill model for tracking business skills with progress tracking
class Skill {
  final int id;
  final int? goalId;
  final String name;
  final String? description;
  final int totalReps;
  final int currentStreak;
  final DateTime? lastRepDate;
  final DateTime createdAt;

  Skill({
    required this.id,
    this.goalId,
    required this.name,
    this.description,
    this.totalReps = 0,
    this.currentStreak = 0,
    this.lastRepDate,
    required this.createdAt,
  });

  /// Create Skill from database map
  factory Skill.fromMap(Map<String, dynamic> map) {
    return Skill(
      id: map['id'] as int,
      goalId: map['goal_id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
      totalReps: map['total_reps'] as int? ?? 0,
      currentStreak: map['current_streak'] as int? ?? 0,
      lastRepDate: map['last_rep_date'] != null
          ? DateTime.parse(map['last_rep_date'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert Skill to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'name': name,
      'description': description,
      'total_reps': totalReps,
      'current_streak': currentStreak,
      'last_rep_date': lastRepDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create map for insertion (without id)
  Map<String, dynamic> toInsertMap() {
    return {
      'goal_id': goalId,
      'name': name,
      'description': description,
      'total_reps': totalReps,
      'current_streak': currentStreak,
      'last_rep_date': lastRepDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copy with method
  Skill copyWith({
    int? id,
    int? goalId,
    String? name,
    String? description,
    int? totalReps,
    int? currentStreak,
    DateTime? lastRepDate,
    DateTime? createdAt,
  }) {
    return Skill(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      name: name ?? this.name,
      description: description ?? this.description,
      totalReps: totalReps ?? this.totalReps,
      currentStreak: currentStreak ?? this.currentStreak,
      lastRepDate: lastRepDate ?? this.lastRepDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

