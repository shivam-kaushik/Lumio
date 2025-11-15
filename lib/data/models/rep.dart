/// Rep model for tracking skill practice sessions
class Rep {
  final int id;
  final int skillId;
  final int? subtaskId; // Link to subtask that triggered this rep
  final String notes;
  final DateTime timestamp;
  final int? durationMinutes;

  Rep({
    required this.id,
    required this.skillId,
    this.subtaskId,
    required this.notes,
    required this.timestamp,
    this.durationMinutes,
  });

  /// Create Rep from database map
  factory Rep.fromMap(Map<String, dynamic> map) {
    return Rep(
      id: map['id'] as int,
      skillId: map['skill_id'] as int,
      subtaskId: map['subtask_id'] as int?,
      notes: map['notes'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      durationMinutes: map['duration_minutes'] as int?,
    );
  }

  /// Convert Rep to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'skill_id': skillId,
      'subtask_id': subtaskId,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
      'duration_minutes': durationMinutes,
    };
  }

  /// Create map for insertion (without id)
  Map<String, dynamic> toInsertMap() {
    return {
      'skill_id': skillId,
      'subtask_id': subtaskId,
      'notes': notes,
      'timestamp': timestamp.toIso8601String(),
      'duration_minutes': durationMinutes,
    };
  }

  /// Copy with method
  Rep copyWith({
    int? id,
    int? skillId,
    int? subtaskId,
    String? notes,
    DateTime? timestamp,
    int? durationMinutes,
  }) {
    return Rep(
      id: id ?? this.id,
      skillId: skillId ?? this.skillId,
      subtaskId: subtaskId ?? this.subtaskId,
      notes: notes ?? this.notes,
      timestamp: timestamp ?? this.timestamp,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

