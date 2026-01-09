import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot, Timestamp, FieldValue;

/// Goal task model for database storage
class GoalTask {
  final int id;
  final int goalId;
  final String title;
  final String description;
  final double? estimatedHours;
  final int? estimatedMinutes; // For Day Planner
  final int? actualMinutes;    // For Day Planner Tracking
  final DateTime? startedAt;   // For Live Tracking
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
  final int order; // Display order index
  final int indentLevel; // 0 = root, 1 = subtask, etc.
  final List<GoalTask> subtasks; // Recursive subtasks

  GoalTask({
    required this.id,
    required this.goalId,
    required this.title,
    required this.description,
    this.estimatedHours,
    this.estimatedMinutes,
    this.actualMinutes,
    this.startedAt,
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
    this.order = 0,
    this.indentLevel = 0,
    this.subtasks = const [],
  });

  /// Computed efficiency score
  int get efficiencyScore {
    if (actualMinutes == null || actualMinutes == 0) return 0;
    // Use estimatedMinutes if available, else convert estimatedHours
    final est = estimatedMinutes ?? ((estimatedHours ?? 0) * 60).round();
    if (est == 0) return 0;
    return (est / actualMinutes! * 100).toInt();
  }

  /// Create GoalTask from database map
  factory GoalTask.fromMap(Map<String, dynamic> map) {
    return GoalTask(
      id: map['id'] as int,
      goalId: map['goal_id'] as int,
      title: map['title'] as String,
      description: map['description'] as String,
      estimatedHours: (map['estimated_hours'] as num?)?.toDouble(),
      estimatedMinutes: (map['estimated_minutes'] as num?)?.toInt(),
      actualMinutes: (map['actual_minutes'] as num?)?.toInt(),
      startedAt: map['started_at'] != null ? DateTime.tryParse(map['started_at'] as String) : null,
      priority: map['priority'] as String? ?? 'medium',
      frequency: map['frequency'] as String? ?? 'one-time',
      suggestedTime: map['suggested_time'] as String? ?? 'any',
      suggestedLocation: map['suggested_location'] as String? ?? 'any',
      isMilestone: (map['is_milestone'] as int? ?? 0) == 1,
      motivationAnchor: map['motivation_anchor'] as String?,
      scheduledDate: map['scheduled_date'] != null
          ? DateTime.tryParse(map['scheduled_date'] as String)
          : null,
      phaseId: map['phase_id'] as int?,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      order: map['order_index'] as int? ?? 0,
      indentLevel: map['indent_level'] as int? ?? 0,
      subtasks: (map['subtasks'] as List<dynamic>?)
              ?.map((x) => GoalTask.fromMap(Map<String, dynamic>.from(x as Map)))
              .toList() ??
          [],
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
      'estimated_minutes': estimatedMinutes,
      'actual_minutes': actualMinutes,
      'started_at': startedAt?.toIso8601String(),
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
      'order_index': order,
      'indent_level': indentLevel,
      'subtasks': subtasks.map((x) => x.toMap()).toList(),
    };
  }

  /// Create map for insertion (without id)
  Map<String, dynamic> toInsertMap() {
    return {
      'goal_id': goalId,
      'title': title,
      'description': description,
      'estimated_hours': estimatedHours,
      'estimated_minutes': estimatedMinutes,
      'actual_minutes': actualMinutes,
      'started_at': startedAt?.toIso8601String(),
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
      'order_index': order,
      'indent_level': indentLevel,
      'subtasks': subtasks.map((x) => x.toInsertMap()).toList(),
    };
  }

  /// Copy with method
  GoalTask copyWith({
    int? id,
    int? goalId,
    String? title,
    String? description,
    double? estimatedHours,
    int? estimatedMinutes,
    int? actualMinutes,
    DateTime? startedAt,
    bool clearStartedAt = false,
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
    int? order,
    int? indentLevel,
    List<GoalTask>? subtasks,
  }) {
    return GoalTask(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
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
      order: order ?? this.order,
      indentLevel: indentLevel ?? this.indentLevel,
      subtasks: subtasks ?? this.subtasks,
    );
  }

  /// Create GoalTask from Firestore document
  factory GoalTask.fromFirestore(DocumentSnapshot doc) {
    // If constructed from a Map inside a document
    // We need to handle both DocumentSnapshot and Map<String,dynamic> cases
    // But this factory expects DocumentSnapshot.
    // Let's create a helper for Map parsing for subtasks.
    final data = doc.data() as Map<String, dynamic>;
    return _fromFirestoreMap(data, id: int.tryParse(doc.id));
  }

  static GoalTask _fromFirestoreMap(Map<String, dynamic> data, {int? id}) {
     // Safe parsing for subtasks
     List<GoalTask> parsedSubtasks = [];
     if (data['subtasks'] != null && data['subtasks'] is List) {
       for (var item in data['subtasks']) {
         if (item is Map) {
           try {
             parsedSubtasks.add(_fromFirestoreMap(Map<String, dynamic>.from(item)));
           } catch (e) {
             // Skip malformed subtasks but don't crash the whole load
             print("Error parsing subtask: $e");
           }
         }
       }
     }

     return GoalTask(
      id: id ?? (int.tryParse(data['id'].toString()) ?? DateTime.now().millisecondsSinceEpoch), // Robust ID parsing
      goalId: int.tryParse(data['goalId'].toString()) ?? int.tryParse(data['goal_id'].toString()) ?? 0,
      title: data['title'] as String? ?? 'Untitled',
      description: data['description'] as String? ?? '',
      estimatedHours: (data['estimatedHours'] as num?)?.toDouble() ?? (data['estimated_hours'] as num?)?.toDouble(),
      estimatedMinutes: (data['estimatedMinutes'] as num?)?.toInt() ?? (data['estimated_minutes'] as num?)?.toInt(),
      actualMinutes: (data['actualMinutes'] as num?)?.toInt() ?? (data['actual_minutes'] as num?)?.toInt(),
      startedAt: data['startedAt'] != null || data['started_at'] != null
          ? ((data['startedAt'] ?? data['started_at']) is Timestamp
              ? ((data['startedAt'] ?? data['started_at']) as Timestamp).toDate()
              : DateTime.tryParse((data['startedAt'] ?? data['started_at']).toString()))
          : null,
      priority: data['priority'] as String? ?? 'medium',
      frequency: data['frequency'] as String? ?? 'one-time',
      suggestedTime: data['suggestedTime'] as String? ?? (data['suggested_time'] as String?) ?? 'any',
      suggestedLocation: data['suggestedLocation'] as String? ?? (data['suggested_location'] as String?) ?? 'any',
      isMilestone: (data['isMilestone'] ?? data['is_milestone']) == true || (data['isMilestone'] ?? data['is_milestone']) == 1,
      motivationAnchor: data['motivationAnchor'] as String? ?? data['motivation_anchor'] as String?,
      scheduledDate: data['scheduledDate'] != null || data['scheduled_date'] != null
          ? ((data['scheduledDate'] ?? data['scheduled_date']) is Timestamp
              ? ((data['scheduledDate'] ?? data['scheduled_date']) as Timestamp).toDate()
              : DateTime.tryParse((data['scheduledDate'] ?? data['scheduled_date']).toString()))
          : null,
      phaseId: data['phaseId'] != null || data['phase_id'] != null 
          ? int.tryParse((data['phaseId'] ?? data['phase_id']).toString()) 
          : null,
      isCompleted: (data['isCompleted'] ?? data['is_completed']) == true || (data['isCompleted'] ?? data['is_completed']) == 1,
      completedAt: data['completedAt'] != null || data['completed_at'] != null
          ? ((data['completedAt'] ?? data['completed_at']) is Timestamp
              ? ((data['completedAt'] ?? data['completed_at']) as Timestamp).toDate()
              : DateTime.tryParse((data['completedAt'] ?? data['completed_at']).toString()))
          : null,
      createdAt: data['createdAt'] != null || data['created_at'] != null
          ? ((data['createdAt'] ?? data['created_at']) is Timestamp
              ? ((data['createdAt'] ?? data['created_at']) as Timestamp).toDate()
              : DateTime.tryParse((data['createdAt'] ?? data['created_at']).toString())) ?? DateTime.now()
          : DateTime.now(),
      order: (data['order'] as num?)?.toInt() ?? (data['order_index'] as num?)?.toInt() ?? 0,
      indentLevel: (data['indentLevel'] as num?)?.toInt() ?? (data['indent_level'] as num?)?.toInt() ?? 0,
      subtasks: parsedSubtasks,
    );
  }

  /// Convert GoalTask to Firestore document
  Map<String, dynamic> toFirestore({bool allowServerTimestamp = true}) {
    return {
      'id': id, // Save ID in the map too for subtasks
      'goalId': goalId.toString(),
      'title': title,
      'description': description,
      'estimatedHours': estimatedHours,
      'estimatedMinutes': estimatedMinutes,
      'actualMinutes': actualMinutes,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
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
      // Only use serverTimestamp for top-level documents
      'updatedAt': allowServerTimestamp ? FieldValue.serverTimestamp() : Timestamp.now(),
      'order': order,
      'indentLevel': indentLevel,
      // Pass false to subtasks recursively
      'subtasks': subtasks.map((x) => x.toFirestore(allowServerTimestamp: false)).toList(),
    };
  }
}
