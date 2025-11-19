/// Goal phase model for roadmap phases
class GoalPhase {
  final int id;
  final int goalId;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final int orderIndex; // For ordering phases
  final DateTime createdAt;

  GoalPhase({
    required this.id,
    required this.goalId,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    this.orderIndex = 0,
    required this.createdAt,
  });

  /// Create GoalPhase from database map
  factory GoalPhase.fromMap(Map<String, dynamic> map) {
    return GoalPhase(
      id: map['id'] as int,
      goalId: map['goal_id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      orderIndex: map['order_index'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Convert GoalPhase to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goal_id': goalId,
      'name': name,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'order_index': orderIndex,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create map for insertion (without id)
  Map<String, dynamic> toInsertMap() {
    return {
      'goal_id': goalId,
      'name': name,
      'description': description,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'order_index': orderIndex,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Copy with method
  GoalPhase copyWith({
    int? id,
    int? goalId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? orderIndex,
    DateTime? createdAt,
  }) {
    return GoalPhase(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

