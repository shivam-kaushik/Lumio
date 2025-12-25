import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;

import '../providers/growth_provider.dart';
import '../../data/models/goal_task.dart';
import '../theme/app_theme.dart';

class DailyReportScreen extends StatelessWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GrowthProvider>(
      builder: (context, provider, _) {
        final today = DateTime.now();
        final dateStr = "${today.year}-${today.month}-${today.day}";
        final goalName = "Daily Plan - $dateStr";
        
        // Fetch tasks from "Daily Plan" goal + Tasks from "Inbox" that were worked on today (startedAt or completedAt roughly)
        // For simplicity, we stick to the Plan.
        
        // Fetch tasks from "Daily Plan" goal + "Inbox" to match DayPlannerScreen
        final dailyGoal = provider.goals.where((g) => g.name == goalName).firstOrNull;
        final inboxGoal = provider.goals.where((g) => g.name == 'Inbox').firstOrNull;
        
        final List<GoalTask> tasks = [];
        
        if (dailyGoal != null) {
           tasks.addAll(provider.getTasksForGoal(dailyGoal.id));
        }
        if (inboxGoal != null) {
           tasks.addAll(provider.getTasksForGoal(inboxGoal.id));
        }
        
        // Calculate Metrics
        int totalEstMinutes = 0;
        int totalActMinutes = 0;
        int completedCount = 0;
        
        for (var t in tasks) {
            totalEstMinutes += t.estimatedMinutes ?? 0;
            totalActMinutes += t.actualMinutes ?? 0;
            if (t.isCompleted) completedCount++;
        }

        // Efficiency Score: (Planned / Actual) * CompletionRate
        // If Actual < Planned (Speedy), cap at 100% or allow bonus? Let's cap at 100 for now.
        // Actually, let's use a simpler metric: "Focus Score".
        // Base score = (Completed / Total) * 100.
        // Penalty for heavily exceeding time?
        // Let's stick to standard Efficiency: Start with 100. Deduct for missed tasks.
        
        // Efficiency Score: Just Completion Rate for now since we don't have estimates
        double completionRate = tasks.isEmpty ? 0 : completedCount / tasks.length;
        int focusScore = (completionRate * 100).toInt();

        // Theme
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF121212) : Colors.white;
        final text = isDark ? Colors.white : Colors.black;

        if (tasks.isEmpty) {
             return Scaffold(
                 appBar: AppBar(title: const Text('Daily Analytics')),
                 body: const Center(child: Text("No data for today yet.")),
             );
        }

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            title: Text('Daily Analytics', style: TextStyle(color: text)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: text),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Focus Score Gauge
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
                                Text("Completion", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                        ),
                        circularStrokeCap: CircularStrokeCap.round,
                        progressColor: AppTheme.primaryColor,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[200]!,
                    ),
                ).animate().scale(),

                const SizedBox(height: 32),

                // 2. Overview Cards (Total Time & Tasks)
                Row(
                   children: [
                       Expanded(
                           child: _buildStatCard(
                               "Total Focus", 
                               "${(totalActMinutes / 60).toStringAsFixed(1)}h", 
                               Icons.timer, 
                               Colors.blueAccent, 
                               isDark
                           ),
                       ),
                       const SizedBox(width: 16),
                       Expanded(
                           child: _buildStatCard(
                               "Tasks Done", 
                               "$completedCount/${tasks.length}", 
                               Icons.check_circle_outline, 
                               Colors.greenAccent, 
                               isDark
                           ),
                       ),
                   ],
                ),

                const SizedBox(height: 32),
                Text("Task Deep Dive", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: text)),
                const SizedBox(height: 16),

                // 4. Task List
                ...tasks.map((t) => _buildTaskAnalysisRow(t, isDark)).toList().animate(interval: 50.ms).slideX(),
                
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
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
              children: [
                  Icon(icon, color: color),
                  const SizedBox(height: 8),
                  Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
          ),
      );
  }



  Widget _buildTaskAnalysisRow(GoalTask t, bool isDark) {
      final act = t.actualMinutes ?? 0;
      
      // Calculate variance color
      Color varColor = AppTheme.primaryColor;
      if (t.isCompleted) varColor = Colors.green;
      
      // Just show a small progress bar representing "effort" relative to something?
      // Or just remove the bar entirely since we have no scale?
      // Let's keep a full width bar if it has any time, or empty if 0
      double pct = act > 0 ? 1.0 : 0.0;

      return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E20) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark ? [] : [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0,2))],
              border: Border.all(color: isDark ? Colors.white10 : Colors.transparent)
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          Expanded(
                              child: Text(t.title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                          ),
                          if (t.isCompleted)
                              const Icon(Icons.check_circle, color: Colors.green, size: 16)
                      ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Progress Bar (Visual only)
                  LinearPercentIndicator(
                      lineHeight: 6.0,
                      percent: pct,
                      progressColor: varColor,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey[100],
                      barRadius: const Radius.circular(3),
                      padding: EdgeInsets.zero,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                          Text("Time Spent", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                              "${act}m",
                              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                          )
                      ],
                  )
              ],
          ),
      );
  }
}
