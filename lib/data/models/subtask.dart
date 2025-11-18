/// Task model for goal breakdown (from GPT)
class Task {
  final String title;
  final String description;
  final String frequency; // 'daily', 'weekly', 'monthly', 'one-time'
  final String suggestedTime; // 'morning', 'afternoon', 'evening', 'any'
  final String suggestedLocation; // 'home', 'office', 'coffee_shop', 'any'
  final String priority; // 'high', 'medium', 'low'
  final double? estimatedHours; // Estimated hours to complete
  final List<String> dependencies; // IDs or titles of dependent tasks
  final bool isMilestone; // Is this a milestone checkpoint
  final String? motivationAnchor; // Why this task matters

  Task({
    required this.title,
    required this.description,
    this.frequency = 'weekly',
    this.suggestedTime = 'any',
    this.suggestedLocation = 'any',
    this.priority = 'medium',
    this.estimatedHours,
    this.dependencies = const [],
    this.isMilestone = false,
    this.motivationAnchor,
  });

  /// Create Task from map (from GPT response)
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      frequency: map['estimatedFrequency'] as String? ?? 
                 map['frequency'] as String? ?? 'weekly',
      suggestedTime: map['suggestedTime'] as String? ?? 'any',
      suggestedLocation: map['suggestedLocation'] as String? ?? 'any',
      priority: map['priority'] as String? ?? 'medium',
      estimatedHours: map['estimatedHours'] != null 
          ? (map['estimatedHours'] is double 
              ? map['estimatedHours'] as double 
              : (map['estimatedHours'] as num).toDouble())
          : null,
      dependencies: map['dependencies'] != null
          ? List<String>.from(map['dependencies'] as List)
          : [],
      isMilestone: map['isMilestone'] as bool? ?? false,
      motivationAnchor: map['motivationAnchor'] as String?,
    );
  }

  /// Convert Task to map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'frequency': frequency,
      'suggestedTime': suggestedTime,
      'suggestedLocation': suggestedLocation,
      'priority': priority,
      'estimatedHours': estimatedHours,
      'dependencies': dependencies,
      'isMilestone': isMilestone,
      'motivationAnchor': motivationAnchor,
    };
  }

  /// Copy with method
  Task copyWith({
    String? title,
    String? description,
    String? frequency,
    String? suggestedTime,
    String? suggestedLocation,
    String? priority,
    double? estimatedHours,
    List<String>? dependencies,
    bool? isMilestone,
    String? motivationAnchor,
  }) {
    return Task(
      title: title ?? this.title,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      suggestedTime: suggestedTime ?? this.suggestedTime,
      suggestedLocation: suggestedLocation ?? this.suggestedLocation,
      priority: priority ?? this.priority,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      dependencies: dependencies ?? this.dependencies,
      isMilestone: isMilestone ?? this.isMilestone,
      motivationAnchor: motivationAnchor ?? this.motivationAnchor,
    );
  }
}

