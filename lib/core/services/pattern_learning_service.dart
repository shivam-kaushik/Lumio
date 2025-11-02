import 'package:flutter/foundation.dart';
import '../../data/models/context_event.dart';
import '../../data/repositories/reminder_repository.dart';

/// Service for learning user behavioral patterns for intelligent context triggers
/// This analyzes user behavior to suggest optimal reminder triggers
class PatternLearningService {
  final ReminderRepository _repository;
  
  PatternLearningService(this._repository);
  
  /// Learn patterns from context events to suggest optimal trigger conditions
  /// Returns a map of learned patterns per reminder or user behavior
  Future<Map<String, dynamic>> learnUserPatterns(String reminderId) async {
    if (kDebugMode) {
      print('');
      print('🧠═══════════════════════════════════════════════════');
      print('🧠 PATTERN LEARNING: Analyzing User Patterns');
      print('🧠═══════════════════════════════════════════════════');
      print('   Reminder ID: $reminderId');
    }
    
    try {
      final events = await _repository.getContextEvents(reminderId);
      
      if (events.length < 5) {
        if (kDebugMode) {
          print('⚠️ Insufficient data: Need at least 5 events, have ${events.length}');
          print('   Returning default patterns');
        }
        return _getDefaultPatterns();
      }
      
      // Analyze completion patterns
      final completionAnalysis = _analyzeCompletionPatterns(events);
      
      // Analyze context trigger effectiveness
      final contextAnalysis = _analyzeContextEffectiveness(events);
      
      // Analyze temporal patterns
      final temporalAnalysis = _analyzeTemporalPatterns(events);
      
      // Analyze activity patterns
      final activityAnalysis = _analyzeActivityPatterns(events);
      
      final patterns = {
        'completion': completionAnalysis,
        'context': contextAnalysis,
        'temporal': temporalAnalysis,
        'activity': activityAnalysis,
        'confidence': _calculateConfidence(events.length),
        'sampleSize': events.length,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      if (kDebugMode) {
        print('✅ Pattern learning complete');
        print('   Patterns discovered:');
        print('   - Completion rate: ${completionAnalysis['completionRate']?.toStringAsFixed(2)}');
        print('   - Best context: ${contextAnalysis['bestContext']}');
        print('   - Optimal hour: ${temporalAnalysis['optimalHour']}');
        print('   - Confidence: ${patterns['confidence']}');
      }
      
      return patterns;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error learning patterns: $e');
      }
      return _getDefaultPatterns();
    }
  }
  
  /// Analyze completion patterns to find optimal timing/context
  Map<String, dynamic> _analyzeCompletionPatterns(List<ContextEvent> events) {
    final completed = events.where((e) => e.outcome == 'completed').length;
    final completionRate = completed / events.length;
    
    // Group by hour and find best completion rate
    final completionsByHour = <int, int>{};
    final triggersByHour = <int, int>{};
    
    for (var event in events) {
      final hour = event.triggerTime.hour;
      triggersByHour[hour] = (triggersByHour[hour] ?? 0) + 1;
      if (event.outcome == 'completed') {
        completionsByHour[hour] = (completionsByHour[hour] ?? 0) + 1;
      }
    }
    
    int? bestHour;
    double bestRate = 0.0;
    
    for (var entry in triggersByHour.entries) {
      final hour = entry.key;
      final triggers = entry.value;
      final completions = completionsByHour[hour] ?? 0;
      final rate = completions / triggers;
      
      if (rate > bestRate && triggers >= 2) {
        bestRate = rate;
        bestHour = hour;
      }
    }
    
    return {
      'completionRate': completionRate,
      'optimalHour': bestHour,
      'optimalHourRate': bestRate,
      'totalCompleted': completed,
      'totalTriggers': events.length,
    };
  }
  
  /// Analyze which context types lead to better completion
  Map<String, dynamic> _analyzeContextEffectiveness(List<ContextEvent> events) {
    final contextStats = <String, Map<String, int>>{};
    
    for (var event in events) {
      final context = event.contextType;
      if (!contextStats.containsKey(context)) {
        contextStats[context] = {'total': 0, 'completed': 0};
      }
      
      final stats = contextStats[context]!;
      stats['total'] = stats['total']! + 1;
      if (event.outcome == 'completed') {
        stats['completed'] = stats['completed']! + 1;
      }
    }
    
    String? bestContext;
    double bestRate = 0.0;
    
    contextStats.forEach((context, stats) {
      final rate = stats['completed']! / stats['total']!;
      if (rate > bestRate && stats['total']! >= 2) {
        bestRate = rate;
        bestContext = context;
      }
    });
    
    return {
      'bestContext': bestContext,
      'bestContextRate': bestRate,
      'contextStats': contextStats,
    };
  }
  
  /// Analyze temporal patterns (day of week, time of day)
  Map<String, dynamic> _analyzeTemporalPatterns(List<ContextEvent> events) {
    final dayCompletions = <int, int>{}; // 1-7 (Monday-Sunday)
    final dayTriggers = <int, int>{};
    
    for (var event in events) {
      final weekday = event.triggerTime.weekday;
      dayTriggers[weekday] = (dayTriggers[weekday] ?? 0) + 1;
      if (event.outcome == 'completed') {
        dayCompletions[weekday] = (dayCompletions[weekday] ?? 0) + 1;
      }
    }
    
    int? bestDay;
    double bestRate = 0.0;
    
    for (var entry in dayTriggers.entries) {
      final day = entry.key;
      final triggers = entry.value;
      final completions = dayCompletions[day] ?? 0;
      final rate = completions / triggers;
      
      if (rate > bestRate && triggers >= 2) {
        bestRate = rate;
        bestDay = day;
      }
    }
    
    // Find optimal hour (reuse from completion analysis)
    final completionAnalysis = _analyzeCompletionPatterns(events);
    
    return {
      'optimalDay': bestDay,
      'optimalDayRate': bestRate,
      'optimalHour': completionAnalysis['optimalHour'],
      'optimalHourRate': completionAnalysis['optimalHourRate'],
    };
  }
  
  /// Analyze activity-based patterns
  Map<String, dynamic> _analyzeActivityPatterns(List<ContextEvent> events) {
    final activityStats = <String, Map<String, int>>{};
    
    for (var event in events) {
      final activity = event.metadata?['activity_type'] as String?;
      if (activity == null) continue;
      
      if (!activityStats.containsKey(activity)) {
        activityStats[activity] = {'total': 0, 'completed': 0};
      }
      
      final stats = activityStats[activity]!;
      stats['total'] = stats['total']! + 1;
      if (event.outcome == 'completed') {
        stats['completed'] = stats['completed']! + 1;
      }
    }
    
    String? bestActivity;
    double bestRate = 0.0;
    
    activityStats.forEach((activity, stats) {
      final rate = stats['completed']! / stats['total']!;
      if (rate > bestRate && stats['total']! >= 2) {
        bestRate = rate;
        bestActivity = activity;
      }
    });
    
    return {
      'bestActivity': bestActivity,
      'bestActivityRate': bestRate,
      'activityStats': activityStats,
    };
  }
  
  /// Calculate confidence score based on sample size
  double _calculateConfidence(int sampleSize) {
    // Confidence increases with more samples, capped at 1.0
    // Formula: min(1.0, sampleSize / 20.0)
    return (sampleSize / 20.0).clamp(0.0, 1.0);
  }
  
  /// Get default patterns when insufficient data
  Map<String, dynamic> _getDefaultPatterns() {
    return {
      'completion': {
        'completionRate': 0.5,
        'optimalHour': null,
        'optimalHourRate': 0.0,
        'totalCompleted': 0,
        'totalTriggers': 0,
      },
      'context': {
        'bestContext': null,
        'bestContextRate': 0.0,
        'contextStats': {},
      },
      'temporal': {
        'optimalDay': null,
        'optimalDayRate': 0.0,
        'optimalHour': null,
        'optimalHourRate': 0.0,
      },
      'activity': {
        'bestActivity': null,
        'bestActivityRate': 0.0,
        'activityStats': {},
      },
      'confidence': 0.0,
      'sampleSize': 0,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
  
  /// Suggest trigger conditions based on learned patterns
  Future<Map<String, dynamic>?> suggestOptimalTrigger(String reminderId) async {
    final patterns = await learnUserPatterns(reminderId);
    
    if (patterns['confidence'] as double < 0.3) {
      if (kDebugMode) {
        print('⚠️ Confidence too low (${patterns['confidence']}), not suggesting');
      }
      return null;
    }
    
    final suggestions = <String, dynamic>{};
    
    // Suggest optimal time
    final optimalHour = patterns['temporal']?['optimalHour'] as int?;
    if (optimalHour != null) {
      suggestions['suggestedTime'] = optimalHour;
    }
    
    // Suggest optimal context
    final bestContext = patterns['context']?['bestContext'] as String?;
    if (bestContext != null) {
      suggestions['suggestedContext'] = bestContext;
    }
    
    // Suggest optimal activity
    final bestActivity = patterns['activity']?['bestActivity'] as String?;
    if (bestActivity != null) {
      suggestions['suggestedActivity'] = bestActivity;
    }
    
    if (suggestions.isEmpty) {
      return null;
    }
    
    return {
      'suggestions': suggestions,
      'confidence': patterns['confidence'],
      'reasoning': _generateReasoning(patterns),
    };
  }
  
  /// Generate human-readable reasoning for suggestions
  String _generateReasoning(Map<String, dynamic> patterns) {
    final reasons = <String>[];
    
    final optimalHour = patterns['temporal']?['optimalHour'] as int?;
    if (optimalHour != null) {
      reasons.add('You complete reminders most often at ${optimalHour}:00');
    }
    
    final bestContext = patterns['context']?['bestContext'] as String?;
    if (bestContext != null) {
      reasons.add('You respond best to $bestContext-based reminders');
    }
    
    if (reasons.isEmpty) {
      return 'Based on your completion patterns';
    }
    
    return reasons.join('. ') + '.';
  }
}

