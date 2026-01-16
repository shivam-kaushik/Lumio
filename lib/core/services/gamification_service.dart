import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<UserStats> addXP(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int currentXp = prefs.getInt(_keyXp) ?? 0;
    int newXp = currentXp + amount;
    
    // Calculate Level
    // Simple Formula: 100 XP per level for MVP
    int newLevel = (newXp / 100).floor() + 1;
    
    await prefs.setInt(_keyXp, newXp);
    await prefs.setInt(_keyLevel, newLevel);

    return UserStats(xp: newXp, level: newLevel, streak: prefs.getInt(_keyStreak) ?? 0);
  }

  Future<int> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_keyLastCompletion);
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    
    int currentStreak = prefs.getInt(_keyStreak) ?? 0;

    if (lastDateStr == todayStr) {
      // Already active for today
      return currentStreak;
    }

    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      final difference = DateTime(now.year, now.month, now.day)
          .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
          .inDays;

      if (difference == 1) {
        // Consecutive day
        currentStreak++;
      } else if (difference > 1) {
        // Streak broken
        currentStreak = 1;
      }
    } else {
      // First ever task
      currentStreak = 1;
    }

    await prefs.setInt(_keyStreak, currentStreak);
    await prefs.setString(_keyLastCompletion, todayStr);
    
    return currentStreak;
  }
}

class UserStats {
  final int xp;
  final int level;
  final int streak;

  UserStats({required this.xp, required this.level, required this.streak});
}
