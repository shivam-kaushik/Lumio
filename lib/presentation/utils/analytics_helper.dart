import 'package:intl/intl.dart';
import '../../data/models/goal_task.dart';

class AnalyticsHelper {
  
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    if (isSameDay(date, now)) return "Today";
    if (isSameDay(date, now.subtract(const Duration(days: 1)))) return "Yesterday";
    return DateFormat('EEE, MMM d').format(date);
  }

  /// Group tasks by their scheduledDate (or createdAt if null, normalized to day)
  static Map<DateTime, List<GoalTask>> groupTasksByDate(List<GoalTask> tasks) {
    final Map<DateTime, List<GoalTask>> grouped = {};
    
    for (var task in tasks) {
      // Determine effective date (Scheduled > Created)
      final rawDate = task.scheduledDate ?? task.createdAt;
      final date = DateTime(rawDate.year, rawDate.month, rawDate.day);
      
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(task);
    }
    
    // Sort tasks within days? (Optional)
    return grouped;
  }

  /// Calculate Focus Score (0-100)
  /// Based on Completion Rate * Consistency (simplified for now)
  static int calculateFocusScore(List<GoalTask> tasks) {
    if (tasks.isEmpty) return 0;
    
    int completed = tasks.where((t) => t.isCompleted).length;
    double rate = completed / tasks.length;
    
    // Bonus for logging time?
    // For now, just completion rate mapped to 0-100
    return (rate * 100).toInt();
  }
}
