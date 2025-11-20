import '../../data/repositories/firestore_reminder_repository.dart';

/// Service for analyzing weekly patterns and generating insights
class WeeklyInsightsService {
  final FirestoreReminderRepository _repository;

  WeeklyInsightsService(this._repository);

  /// Get completion rates by day of week for the last 4 weeks
  Future<Map<String, dynamic>> getWeeklyCompletionTrends() async {
    final now = DateTime.now();
    final fourWeeksAgo = now.subtract(const Duration(days: 28));
    
    final events = await _repository.getAllContextEvents();
    
    // Filter events from last 4 weeks
    final recentEvents = events.where((e) => 
      e.triggerTime.isAfter(fourWeeksAgo)
    ).toList();

    // Group by week
    final weeklyStats = <String, Map<String, int>>{};
    
    for (final event in recentEvents) {
      final weekKey = _getWeekKey(event.triggerTime);
      weeklyStats.putIfAbsent(weekKey, () => {
        'total': 0,
        'completed': 0,
        'missed': 0,
        'snoozed': 0,
      });
      
      weeklyStats[weekKey]!['total'] = 
          (weeklyStats[weekKey]!['total'] ?? 0) + 1;
      
      if (event.outcome == 'completed') {
        weeklyStats[weekKey]!['completed'] = 
            (weeklyStats[weekKey]!['completed'] ?? 0) + 1;
      } else if (event.outcome == 'missed') {
        weeklyStats[weekKey]!['missed'] = 
            (weeklyStats[weekKey]!['missed'] ?? 0) + 1;
      } else if (event.outcome == 'snoozed') {
        weeklyStats[weekKey]!['snoozed'] = 
            (weeklyStats[weekKey]!['snoozed'] ?? 0) + 1;
      }
    }

    // Calculate completion rates
    final trends = weeklyStats.entries.map((entry) {
      final stats = entry.value;
      final total = stats['total'] ?? 1;
      final completed = stats['completed'] ?? 0;
      
      return {
        'week': entry.key,
        'completionRate': total > 0 ? (completed / total * 100).round() : 0,
        'total': total,
        'completed': completed,
        'missed': stats['missed'] ?? 0,
        'snoozed': stats['snoozed'] ?? 0,
      };
    }).toList();

    return {
      'trends': trends,
      'averageCompletionRate': trends.isNotEmpty
          ? (trends.map((t) => t['completionRate'] as int).reduce((a, b) => a + b) / trends.length).round()
          : 0,
      'trend': trends.length >= 2
          ? (trends.last['completionRate'] as int) - (trends[trends.length - 2]['completionRate'] as int)
          : 0,
    };
  }

  /// Get completion rates by hour of day (to identify peak times)
  Future<Map<String, dynamic>> getHourlyCompletionPatterns() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    final events = await _repository.getAllContextEvents();
    final recentEvents = events.where((e) => 
      e.triggerTime.isAfter(thirtyDaysAgo) && 
      e.outcome == 'completed'
    ).toList();

    // Group by hour
    final hourlyStats = <int, Map<String, int>>{};
    
    for (int hour = 0; hour < 24; hour++) {
      hourlyStats[hour] = {'total': 0, 'completed': 0};
    }

    for (final event in recentEvents) {
      final hour = event.triggerTime.hour;
      hourlyStats[hour]!['total'] = 
          (hourlyStats[hour]!['total'] ?? 0) + 1;
      hourlyStats[hour]!['completed'] = 
          (hourlyStats[hour]!['completed'] ?? 0) + 1;
    }

    // Find peak hour (highest completion rate)
    int? peakHour;
    int maxCompletions = 0;
    
    hourlyStats.forEach((hour, stats) {
      if (stats['completed']! > maxCompletions) {
        maxCompletions = stats['completed']!;
        peakHour = hour;
      }
    });

    return {
      'hourlyData': hourlyStats,
      'peakHour': peakHour,
      'maxCompletions': maxCompletions,
    };
  }

  /// Get completion rates by day of week
  Future<Map<String, dynamic>> getDayOfWeekPatterns() async {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    
    final events = await _repository.getAllContextEvents();
    final recentEvents = events.where((e) => 
      e.triggerTime.isAfter(thirtyDaysAgo)
    ).toList();

    // Group by day of week (1=Monday, 7=Sunday)
    final dayStats = <int, Map<String, int>>{};
    
    for (int day = 1; day <= 7; day++) {
      dayStats[day] = {'total': 0, 'completed': 0};
    }

    for (final event in recentEvents) {
      final day = event.triggerTime.weekday;
      dayStats[day]!['total'] = (dayStats[day]!['total'] ?? 0) + 1;
      if (event.outcome == 'completed') {
        dayStats[day]!['completed'] = 
            (dayStats[day]!['completed'] ?? 0) + 1;
      }
    }

    // Calculate completion rates
    final dayRates = dayStats.map((day, stats) {
      final total = stats['total'] ?? 1;
      final completed = stats['completed'] ?? 0;
      return MapEntry(
        day,
        total > 0 ? (completed / total * 100).round() : 0,
      );
    });

    // Find best and worst days
    final sortedDays = dayRates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final bestDay = sortedDays.isNotEmpty ? sortedDays.first.key : null;
    final worstDay = sortedDays.isNotEmpty ? sortedDays.last.key : null;

    return {
      'dayRates': dayRates,
      'bestDay': bestDay,
      'worstDay': worstDay,
      'dayNames': {
        1: 'Monday',
        2: 'Tuesday',
        3: 'Wednesday',
        4: 'Thursday',
        5: 'Friday',
        6: 'Saturday',
        7: 'Sunday',
      },
    };
  }

  /// Generate actionable insights based on patterns
  Future<List<Map<String, dynamic>>> generateInsights() async {
    final insights = <Map<String, dynamic>>[];
    
    final trends = await getWeeklyCompletionTrends();
    final hourlyPatterns = await getHourlyCompletionPatterns();
    final dayPatterns = await getDayOfWeekPatterns();

    // Trend insight
    final trendValue = trends['trend'] as int;
    if (trendValue > 5) {
      insights.add({
        'type': 'positive',
        'icon': '📈',
        'title': 'Improving Consistency',
        'description': 'Your completion rate improved by $trendValue% this week! Keep it up!',
      });
    } else if (trendValue < -5) {
      insights.add({
        'type': 'warning',
        'icon': '📉',
        'title': 'Declining Performance',
        'description': 'Your completion rate dropped by ${trendValue.abs()}%. Try setting reminders at optimal times.',
      });
    }

    // Peak hour insight
    final peakHour = hourlyPatterns['peakHour'] as int?;
    if (peakHour != null) {
      final hourDisplay = _formatHour(peakHour);
      insights.add({
        'type': 'info',
        'icon': '⏰',
        'title': 'Peak Performance Time',
        'description': 'You\'re most productive at $hourDisplay. Consider scheduling important reminders then.',
      });
    }

    // Best day insight
    final bestDay = dayPatterns['bestDay'] as int?;
    if (bestDay != null) {
      final dayNames = dayPatterns['dayNames'] as Map<int, String>;
      final bestDayName = dayNames[bestDay];
      insights.add({
        'type': 'positive',
        'icon': '⭐',
        'title': 'Best Day',
        'description': '$bestDayName is your most productive day. Great job staying consistent!',
      });
    }

    // Default encouragement if no insights
    if (insights.isEmpty) {
      insights.add({
        'type': 'info',
        'icon': '💪',
        'title': 'Keep Going!',
        'description': 'Continue using reminders regularly to build better habits and see insights.',
      });
    }

    return insights;
  }

  /// Get week key for grouping (e.g., "2024-W01")
  String _getWeekKey(DateTime date) {
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    final weekNumber = ((weekStart.difference(
      DateTime(weekStart.year, 1, 1)
    ).inDays) / 7).floor() + 1;
    return '${weekStart.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Format hour for display (e.g., "9 AM", "2 PM")
  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}

