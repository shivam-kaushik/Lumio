import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp, FieldValue, SetOptions;
import '../../data/repositories/firestore_reminder_repository.dart';
import '../../data/models/context_event.dart';
import '../../core/services/firestore_service.dart';

/// Service for learning user patterns and optimizing reminder timing
class LearningService {
  final FirestoreReminderRepository _repository;

  LearningService(this._repository);

  /// Analyze completion patterns for a reminder and learn optimal timing
  Future<Map<String, dynamic>?> learnOptimalTiming(String reminderId) async {
    if (kDebugMode) {
      print('');
      print('🧠═══════════════════════════════════════════════════');
      print('🧠 LEARNING SERVICE: Learning Optimal Timing');
      print('🧠═══════════════════════════════════════════════════');
      print('   Reminder ID: $reminderId');
    }
    
    try {
      final events = await _repository.getContextEvents(reminderId);
      
      if (kDebugMode) {
        print('   Total events: ${events.length}');
      }
      
      if (events.length < 3) {
        if (kDebugMode) {
          print('⚠️ Insufficient data: Need at least 3 events, have ${events.length}');
          print('🧠═══════════════════════════════════════════════════');
          print('');
        }
        return null;
      }

      // Group completed events by hour
      final completedByHour = <int, List<ContextEvent>>{};
      int completedCount = 0;
      
      for (var event in events) {
        if (event.outcome == 'completed') {
          completedCount++;
          final hour = event.triggerTime.hour;
          completedByHour.putIfAbsent(hour, () => []).add(event);
          if (kDebugMode) {
            print('   ✅ Completed event at ${hour}:00');
          }
        }
      }

      if (kDebugMode) {
        print('   Completed events: $completedCount / ${events.length}');
        print('   Hours with completions: ${completedByHour.keys.length}');
      }

      if (completedByHour.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No completed events found');
          print('🧠═══════════════════════════════════════════════════');
          print('');
        }
        return null;
      }

      // Find hour with highest completion rate
      int? optimalHour;
      double maxCompletionRate = 0.0;

      if (kDebugMode) {
        print('');
        print('   Analyzing completion rates by hour:');
      }

      for (var entry in completedByHour.entries) {
        final hour = entry.key;
        final completedEvents = entry.value;
        
        // Calculate completion rate for this hour
        final totalAtHour = events.where((e) => e.triggerTime.hour == hour).length;
        final completionRate = completedEvents.length / totalAtHour;
        
        if (kDebugMode) {
          print('     ${hour}:00 - ${completedEvents.length}/${totalAtHour} = ${(completionRate * 100).toStringAsFixed(1)}%');
        }
        
        if (completionRate > maxCompletionRate) {
          maxCompletionRate = completionRate;
          optimalHour = hour;
        }
      }

      if (optimalHour == null) {
        if (kDebugMode) {
          print('⚠️ Could not determine optimal hour');
          print('🧠═══════════════════════════════════════════════════');
          print('');
        }
        return null;
      }

      if (kDebugMode) {
        print('');
        print('   🎯 Optimal hour identified: ${optimalHour}:00');
        print('   📊 Completion rate: ${(maxCompletionRate * 100).toStringAsFixed(1)}%');
      }

      // Calculate average response time (time from trigger to completion)
      int totalResponseTimeSeconds = 0;
      int responseTimeCount = 0;

      for (var event in events) {
        if (event.outcome == 'completed') {
          // Estimate response time (for now, use trigger time as proxy)
          // In future, we could track actual interaction times
          responseTimeCount++;
        }
      }

      final avgResponseTime = responseTimeCount > 0
          ? totalResponseTimeSeconds / responseTimeCount
          : 0;

      // Save learning pattern
      if (kDebugMode) {
        print('   💾 Saving learning pattern to database...');
      }
      
      await _saveLearningPattern(
        reminderId: reminderId,
        optimalHour: optimalHour,
        completionRate: maxCompletionRate,
        avgResponseTime: avgResponseTime.round(),
        sampleCount: events.length,
      );

      final result = {
        'optimalHour': optimalHour,
        'completionRate': maxCompletionRate,
        'avgResponseTime': avgResponseTime,
        'sampleCount': events.length,
      };

      if (kDebugMode) {
        print('✅ Learning pattern saved');
        print('🧠═══════════════════════════════════════════════════');
        print('');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error learning optimal timing: $e');
        print('🧠═══════════════════════════════════════════════════');
        print('');
      }
      debugPrint('Error learning optimal timing: $e');
      return null;
    }
  }

  /// Get learned optimal time for a reminder
  Future<Map<String, dynamic>?> getOptimalTiming(String reminderId) async {
    if (kDebugMode) {
      print('🧠 LearningService: Getting optimal timing for reminder: $reminderId');
    }
    
    try {
      final firestoreService = FirestoreService();
      final userDoc = firestoreService.userDoc;
      if (userDoc == null) {
        if (kDebugMode) {
          print('   ⚠️ User not authenticated');
        }
        return null;
      }

      final learningPatternsCollection = userDoc.collection('learning_patterns');
      final snapshot = await learningPatternsCollection
          .where('reminderId', isEqualTo: reminderId)
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('   No learning pattern found');
        }
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      
      final result = {
        'optimalHour': data['optimalTimeHour'] as int,
        'optimalMinute': data['optimalTimeMinute'] as int? ?? 0,
        'completionRate': (data['completionRate'] as num?)?.toDouble() ?? 0.0,
        'avgResponseTime': data['avgResponseTime'] as int? ?? 0,
        'sampleCount': data['sampleCount'] as int,
        'lastUpdated': data['lastUpdated'] != null
            ? (data['lastUpdated'] is Timestamp
                ? (data['lastUpdated'] as Timestamp).toDate().toIso8601String()
                : data['lastUpdated'].toString())
            : '',
      };

      if (kDebugMode) {
        print('   ✅ Found pattern:');
        print('     Optimal hour: ${result['optimalHour']}:00');
        print('     Completion rate: ${((result['completionRate'] as double) * 100).toStringAsFixed(1)}%');
        print('     Sample count: ${result['sampleCount']}');
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('   ❌ Error: $e');
      }
      debugPrint('Error getting optimal timing: $e');
      return null;
    }
  }

  /// Get optimal time adjustment for a reminder (considering learned patterns)
  Future<DateTime?> getAdjustedTime(String reminderId, DateTime originalTime) async {
    try {
      final optimal = await getOptimalTiming(reminderId);
      if (optimal == null) return null;

      final optimalHour = optimal['optimalHour'] as int;
      final currentHour = originalTime.hour;

      // If original time is close to optimal (within 2 hours), keep it
      if ((currentHour - optimalHour).abs() <= 2) {
        return originalTime;
      }

      // Adjust to optimal hour, keeping the same minute
      return DateTime(
        originalTime.year,
        originalTime.month,
        originalTime.day,
        optimalHour,
        originalTime.minute,
      );
    } catch (e) {
      debugPrint('Error adjusting time: $e');
      return null;
    }
  }

  /// Save learning pattern to database
  Future<void> _saveLearningPattern({
    required String reminderId,
    required int optimalHour,
    double? completionRate,
    int? avgResponseTime,
    required int sampleCount,
  }) async {
    try {
      final firestoreService = FirestoreService();
      final userDoc = firestoreService.userDoc;
      if (userDoc == null) {
        debugPrint('⚠️ Cannot save learning pattern: User not authenticated');
        return;
      }

      final learningPatternsCollection = userDoc.collection('learning_patterns');
      await learningPatternsCollection.doc(reminderId).set({
        'reminderId': reminderId,
        'optimalTimeHour': optimalHour,
        'optimalTimeMinute': 0,
        'completionRate': completionRate ?? 0.0,
        'avgResponseTime': avgResponseTime ?? 0,
        'sampleCount': sampleCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('✅ Saved learning pattern for reminder $reminderId: optimal hour = $optimalHour');
      }
    } catch (e) {
      debugPrint('Error saving learning pattern: $e');
    }
  }

  /// Re-learn patterns when new data is available
  Future<void> updatePatterns() async {
    try {
      final reminders = await _repository.getAllReminders();
      
      for (var reminder in reminders) {
        if (reminder.useSmartTiming) {
          await learnOptimalTiming(reminder.id);
        }
      }
    } catch (e) {
      debugPrint('Error updating patterns: $e');
    }
  }

  /// Check if reminder should use smart timing
  bool shouldUseSmartTiming(String reminderId, List<ContextEvent> events) {
    // Use smart timing if:
    // 1. We have enough data (at least 5 events)
    // 2. At least 30% completion rate
    if (events.length < 5) return false;

    final completedCount = events.where((e) => e.outcome == 'completed').length;
    final completionRate = completedCount / events.length;
    
    return completionRate >= 0.3;
  }
}

