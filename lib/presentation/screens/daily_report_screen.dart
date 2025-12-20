import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/growth_provider.dart';
import '../../data/models/goal_task.dart';
import '../theme/app_theme.dart';

class DailyReportScreen extends StatelessWidget {
  const DailyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GrowthProvider>(
      builder: (context, provider, _) {
        // Fetch Today's Tasks
        // Logic: Find "Daily Plan - Today" goal or just filter all tasks by scheduledDate = today
        // For robustness, let's filter all tasks where scheduledDate is today (+/- logic)
        // Actually, we created them under "Daily Plan - yyyy-MM-dd".
        
        final today = DateTime.now();
        final dateStr = "${today.year}-${today.month}-${today.day}";
        final goalName = "Daily Plan - $dateStr";
        
        final dailyGoals = provider.goals.where((g) => g.name == goalName);
        final List<GoalTask> tasks = [];
        
        if (dailyGoals.isNotEmpty) {
           final goalId = dailyGoals.first.id;
           tasks.addAll(provider.getTasksForGoal(goalId));
        }
        
        // Also include any other task scheduled for today? 
        // For "Day Architect", we stick to the plan.
        
        if (tasks.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Daily Retro')),
            body: const Center(child: Text("No plan found for today.")),
          );
        }

        // Analytics
        int totalEstimated = 0;
        int totalActual = 0;
        int completedCount = 0;
        
        for (var t in tasks) {
          totalEstimated += t.estimatedMinutes ?? (t.estimatedHours != null ? (t.estimatedHours! * 60).round() : 0);
          totalActual += t.actualMinutes ?? 0;
          if (t.isCompleted) completedCount++;
        }
        
        double efficiency = totalActual > 0 ? (totalEstimated / totalActual) * 100 : 0;
        if (efficiency > 100) efficiency = 100; // Cap at 100 for simplicity or allow >100 for "Speedy"

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            title: const Text('Daily Retro'),
            backgroundColor: Colors.transparent,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Day Summary",
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  "${today.day}/${today.month}/${today.year}",
                  style: const TextStyle(color: Colors.white54, fontSize: 18),
                ),
                const SizedBox(height: 32),
                
                // Score Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildScoreCard("Tasks", "$completedCount/${tasks.length}", Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildScoreCard("Efficiency", "${efficiency.toInt()}%", efficiency > 80 ? Colors.green : Colors.orange),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildScoreCard("Planned", "${totalEstimated}m", Colors.white54),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildScoreCard("Actual", "${totalActual}m", Colors.white),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                const Text(
                  "Breakdown",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                ...tasks.map((t) => _buildTaskRow(t)).toList(),
                
                const SizedBox(height: 48),
                
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text("Close Day"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScoreCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTaskRow(GoalTask t) {
    final est = t.estimatedMinutes ?? 0;
    final act = t.actualMinutes ?? 0;
    final diff = act - est;
    Color diffColor = Colors.grey;
    if (diff > 0) diffColor = Colors.redAccent; // Took longer
    if (diff < 0) diffColor = Colors.greenAccent; // Faster
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
         color: Colors.white.withOpacity(0.05),
         borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: TextStyle(
                    color: Colors.white,
                    decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white54,
                  ),
                ),
                if (t.isCompleted)
                  Text("Completed", style: TextStyle(color: AppTheme.primaryColor, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Plan: ${est}m", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              Text(
                "Act: ${act}m", 
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              if (act > 0)
                Text(
                  "${diff > 0 ? '+' : ''}${diff}m",
                  style: TextStyle(color: diffColor, fontSize: 10),
                )
            ],
          )
        ],
      ),
    );
  }
}
