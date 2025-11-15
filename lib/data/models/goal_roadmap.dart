import 'subtask.dart';

/// Goal roadmap containing goal name and subtasks
class GoalRoadmap {
  final String goalName;
  final List<Subtask> subtasks;
  final DateTime? targetDeadline;
  final double? hoursPerDay;
  final int? totalEstimatedHours;
  final List<String> weeklyGoals;
  final List<String> riskAlerts;
  final Map<String, dynamic>? metadata;

  GoalRoadmap({
    required this.goalName,
    required this.subtasks,
    this.targetDeadline,
    this.hoursPerDay,
    this.totalEstimatedHours,
    this.weeklyGoals = const [],
    this.riskAlerts = const [],
    this.metadata,
  });

  /// Create GoalRoadmap from GPT response
  factory GoalRoadmap.fromGptResponse(Map<String, dynamic> json) {
    DateTime? deadline;
    if (json['targetDeadline'] != null) {
      if (json['targetDeadline'] is String) {
        deadline = DateTime.tryParse(json['targetDeadline'] as String);
      }
    }

    return GoalRoadmap(
      goalName: json['goal'] as String? ?? '',
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((s) => Subtask.fromMap(s as Map<String, dynamic>))
              .toList() ?? [],
      targetDeadline: deadline,
      hoursPerDay: json['hoursPerDay'] != null
          ? (json['hoursPerDay'] is double
              ? json['hoursPerDay'] as double
              : (json['hoursPerDay'] as num).toDouble())
          : null,
      totalEstimatedHours: json['totalEstimatedHours'] != null
          ? (json['totalEstimatedHours'] is int
              ? json['totalEstimatedHours'] as int
              : (json['totalEstimatedHours'] as num).toInt())
          : null,
      weeklyGoals: json['weeklyGoals'] != null
          ? List<String>.from(json['weeklyGoals'] as List)
          : [],
      riskAlerts: json['riskAlerts'] != null
          ? List<String>.from(json['riskAlerts'] as List)
          : [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert GoalRoadmap to map
  Map<String, dynamic> toMap() {
    return {
      'goal': goalName,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'targetDeadline': targetDeadline?.toIso8601String(),
      'hoursPerDay': hoursPerDay,
      'totalEstimatedHours': totalEstimatedHours,
      'weeklyGoals': weeklyGoals,
      'riskAlerts': riskAlerts,
      'metadata': metadata,
    };
  }
}

