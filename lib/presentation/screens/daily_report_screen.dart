import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../providers/growth_provider.dart';
import '../../data/models/goal_task.dart';
import '../theme/app_theme.dart';
import '../utils/analytics_helper.dart';

enum TimeRange { day, week, month, all }

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  TimeRange _range = TimeRange.day;
  DateTime _referenceDate = DateTime.now(); // The "anchor" for the range (e.g. "this week containing X")

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;

    return Consumer<GrowthProvider>(
      builder: (context, provider, _) {
        // 1. Filter Tasks based on Range
        final allTasks = provider.allTasks; // Helper to get flat list
        final goals = provider.goals;
        final tasks = _getTasksForRange(allTasks, goals, _range, _referenceDate);
        
        // 2. Metrics
        final focusScore = AnalyticsHelper.calculateFocusScore(tasks);
        final completed = tasks.where((t) => t.isCompleted).length;
        final total = tasks.length;
        int totalMinutes = 0;
        int totalEst = 0;
        for (var t in tasks) {
           totalMinutes += t.actualMinutes ?? 0;
           totalEst += t.estimatedMinutes ?? 0;
        }

        // 3. Consistency (Simple: Days with > 0 focus / Total Days in range)
        int activeDays = 0;
        if (_range != TimeRange.day) {
           final grouped = AnalyticsHelper.groupTasksByDate(tasks);
            // Count days with > 10 mins focus
           activeDays = grouped.values.where((list) {
               final dayMins = list.fold(0, (sum, t) => sum + (t.actualMinutes ?? 0));
               return dayMins > 10;
           }).length;
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: Text('Analytics', style: TextStyle(color: text)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: text),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Range Selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                        _buildRangeChip("Today", TimeRange.day),
                        const SizedBox(width: 8),
                        _buildRangeChip("This Week", TimeRange.week),
                        const SizedBox(width: 8),
                        _buildRangeChip("This Month", TimeRange.month),
                        const SizedBox(width: 8),
                        _buildRangeChip("All Time", TimeRange.all),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Main Focus Gauge (Day Mode) or Summary (Week Mode)
                Center(
                    child: CircularPercentIndicator(
                        radius: 80.0,
                        lineWidth: 12.0,
                        animation: true,
                        percent: focusScore / 100,
                        center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                Text(
                                    "$focusScore",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40.0, color: text),
                                ),
                                Text(_range == TimeRange.day ? "Focus Score" : "Avg Score", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                        ),
                        circularStrokeCap: CircularStrokeCap.round,
                        progressColor: _getScoreColor(focusScore),
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[200]!,
                    ),
                ).animate().scale(),

                const SizedBox(height: 32),

                // Grid stats
                GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                        _buildStatCard("Total Focus", "${(totalMinutes/60).toStringAsFixed(1)}h", Icons.timer, Colors.blue, isDark),
                        if (_range == TimeRange.day)
                            _buildStatCard("Tasks Done", "$completed/$total", Icons.check_circle, Colors.green, isDark)
                        else
                            _buildStatCard("Active Days", "$activeDays", Icons.calendar_today, Colors.orange, isDark),
                            
                        _buildStatCard("Completion", "${total == 0 ? 0 : ((completed/total)*100).toInt()}%", Icons.done_all, Colors.purple, isDark),
                        _buildStatCard("Est. vs Act.", "${(totalEst/60).toStringAsFixed(1)}h", Icons.balance, Colors.teal, isDark),
                    ],
                ),

                const SizedBox(height: 32),
                
                // Detailed List (Only if Day mode, or summarize if Week?)
                // For MVP, just list tasks for Day, or Grouped Breakdown for Week
                Text(_range == TimeRange.day ? "Today's Breakdown" :"Recent Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text)),
                const SizedBox(height: 16),
                
                ...tasks.take(50).map((t) => _buildTaskRow(t, isDark)).toList(),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // Helpers
  List<GoalTask> _getTasksForRange(List<GoalTask> all, List<dynamic> goals, TimeRange range, DateTime ref) {
      return all.where((t) {
          // 1. First, check if it belongs to a "Daily Plan" goal OR "Inbox"
          bool isRelevant = false;
          DateTime? taskDate;

          try {
             final goal = goals.firstWhere((g) => g.id == t.goalId);
             
             // A. Daily Plan
             if (goal.name.startsWith("Daily Plan")) {
                 isRelevant = true;
                 // Extract date from "Daily Plan - YYYY-M-D"
                 final parts = goal.name.split(' - ');
                 if (parts.length >= 2) {
                     final dateParts = parts[1].split('-');
                     if (dateParts.length == 3) {
                         final y = int.parse(dateParts[0]);
                         final m = int.parse(dateParts[1]);
                         final d = int.parse(dateParts[2]);
                         taskDate = DateTime(y, m, d);
                     }
                 }
             } 
             // B. Inbox
             else if (goal.name == "Inbox") {
                 isRelevant = true;
                 taskDate = t.scheduledDate ?? t.createdAt;
             }
          } catch (e) {
             return false;
          }

          if (!isRelevant) return false;
          if (taskDate == null) taskDate = t.scheduledDate ?? t.createdAt;


          // 2. Then check Date Range using the Goal's Date
          if (range == TimeRange.day) {
             return AnalyticsHelper.isSameDay(taskDate, ref);
          } else if (range == TimeRange.week) {
             final startOfWeek = ref.subtract(Duration(days: ref.weekday - 1));
             final endOfWeek = startOfWeek.add(const Duration(days: 6));
             // Normalize to YMD for comparison
             final check = DateTime(taskDate.year, taskDate.month, taskDate.day);
             final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
             final end = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day).add(const Duration(days: 1)); // End is exclusive boundary
             
             return check.isAtSameMomentAs(start) || (check.isAfter(start) && check.isBefore(end));
          } else if (range == TimeRange.month) {
             return taskDate.year == ref.year && taskDate.month == ref.month;
          }
          return true; // All
      }).toList();
  }
  
  Widget _buildRangeChip(String label, TimeRange r) {
      final selected = _range == r;
      return ChoiceChip(
        label: Text(label), 
        selected: selected,
        onSelected: (val) {
           if (val) setState(() => _range = r); 
        },
        selectedColor: AppTheme.primaryColor,
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.grey),
        backgroundColor: Colors.transparent,
      );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(height: 8),
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
          ),
      );
  }
  
  Widget _buildTaskRow(GoalTask t, bool isDark) {
      return Container(
         margin: const EdgeInsets.only(bottom: 8),
         child: Row(
             children: [
                 Icon(t.isCompleted ? Icons.check_circle : Icons.circle_outlined, size: 16, color: t.isCompleted ? Colors.green : Colors.grey),
                 const SizedBox(width: 8),
                 Expanded(child: Text(t.title, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87))),
                 Text("${t.actualMinutes ?? 0}m", style: const TextStyle(color: Colors.grey, fontSize: 12)),
             ],
         ),
      );
  }

  Color _getScoreColor(int score) {
      if (score >= 80) return Colors.green;
      if (score >= 50) return Colors.orange;
      return Colors.red;
  }
}
