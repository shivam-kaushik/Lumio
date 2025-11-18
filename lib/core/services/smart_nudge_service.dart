import 'package:flutter/foundation.dart';
import '../../data/repositories/growth_repository.dart';
import '../../data/repositories/reminder_repository.dart';
import '../services/notification_service.dart';

/// Smart nudge service for goal accountability (skills removed)
class SmartNudgeService {
  static final SmartNudgeService _instance = SmartNudgeService._internal();
  factory SmartNudgeService() => _instance;
  SmartNudgeService._internal();

  final GrowthRepository _growthRepository = GrowthRepository();
  final ReminderRepository _reminderRepository = ReminderRepository();
  final NotificationService _notificationService = NotificationService();

  /// Check for goals with missed tasks and send nudges
  Future<void> checkAndSendStreakProtectionNudges() async {
    try {
      // Skills removed - this service is now disabled
      // Can be extended in the future for goal-based nudges
      debugPrint('Smart nudge service: Skills removed, service disabled');
    } catch (e) {
      debugPrint('Error checking streak protection: $e');
    }
  }

  /// Send momentum nudge when user is doing well (deprecated)
  Future<void> sendMomentumNudge(int goalId, int tasksCompletedThisWeek) async {
    try {
      final goal = await _growthRepository.getGoal(goalId);
      if (goal == null) return;

      final nudgeMessage = 
          'You\'ve completed $tasksCompletedThisWeek tasks this week. '
          'Keep up the momentum!';

      await _notificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch % 2147483647,
        title: '🚀 Great Progress!',
        body: nudgeMessage,
      );

      debugPrint('📢 Sent momentum nudge for goal: ${goal.name}');
    } catch (e) {
      debugPrint('Error sending momentum nudge: $e');
    }
  }
}
