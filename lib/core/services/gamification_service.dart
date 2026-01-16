import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/goal_task.dart'; // Added


class GamificationService {
  static const String _keyXp = 'user_xp';
  static const String _keyLevel = 'user_level';
  static const String _keyStreak = 'current_streak';
  static const String _keyLastCompletion = 'last_completion_date';

  // Level Calc: Level = sqrt(XP) * 0.1 (Sample curve)
  // XP = (Level / 0.1)^2
  
  Future<UserStats> loadStats() async {
    final prefs = await SharedPreferences.getInstance();
    return UserStats(
      xp: prefs.getInt(_keyXp) ?? 0,
      level: prefs.getInt(_keyLevel) ?? 1,
      streak: prefs.getInt(_keyStreak) ?? 0,
    );
  }

  // Returns (New Stats, Did Level Up)
  Future<({UserStats stats, bool didLevelUp})> addXP(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load current
    int currentXp = prefs.getInt(_keyXp) ?? 0;
    int currentLevel = prefs.getInt(_keyLevel) ?? 1;
    
    int newXp = currentXp + amount;
    int newLevel = (newXp / 100).floor() + 1;
    
    bool didLevelUp = newLevel > currentLevel;
    
    await prefs.setInt(_keyXp, newXp);
    await prefs.setInt(_keyLevel, newLevel);

    final stats = UserStats(xp: newXp, level: newLevel, streak: prefs.getInt(_keyStreak) ?? 0);
    return (stats: stats, didLevelUp: didLevelUp);
  }

  // Robust History-Based Streak Calculation
  Future<int> calculateStreak(List<GoalTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Filter and Sort Dates
    final completedDates = tasks
        .where((t) => t.isCompleted && t.completedAt != null)
        .map((t) {
            final d = t.completedAt!;
            return DateTime(d.year, d.month, d.day); // Normalize to midnight
        })
        .toSet()
        .toList();
        
    completedDates.sort((a, b) => b.compareTo(a)); // Descending (Newest first)
    
    if (completedDates.isEmpty) {
        await prefs.setInt(_keyStreak, 0);
        return 0;
    }
    
    // 2. Check current streak
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    // If the most recent completion is before yesterday, streak is broken -> 0
    if (completedDates.first.isBefore(yesterday)) {
         await prefs.setInt(_keyStreak, 0);
         return 0;
    }
    
    int streak = 0;
    DateTime checkDate = today;

    // Check if we have a completion for TODAY
    if (!completedDates.contains(today)) {
        // If not today, we MUST have yesterday to keep streak alive
        if (!completedDates.contains(yesterday)) {
             await prefs.setInt(_keyStreak, 0);
             return 0;
        }
        checkDate = yesterday;
    }
    
    // Count consecutive days
    while (completedDates.contains(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
    }

    await prefs.setInt(_keyStreak, streak);
    return streak;
  }
}

class UserStats {
  final int xp;
  final int level;
  final int streak;

  UserStats({required this.xp, required this.level, required this.streak});
}
