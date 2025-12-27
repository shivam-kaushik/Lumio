import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/growth_provider.dart';
import '../utils/analytics_helper.dart';
import '../theme/app_theme.dart';

class DayPlannerHistoryScreen extends StatelessWidget {
  const DayPlannerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Planner History", style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Consumer<GrowthProvider>(
        builder: (context, provider, _) {
          // 1. Fetch relevant tasks (Daily Plan + Inbox)
          final relevantTasks = provider.allTasks.where((t) {
             // Find parent goal to check name
             try {
               final goal = provider.goals.firstWhere((g) => g.id == t.goalId);
               final name = goal.name;
               return name.startsWith("Daily Plan") || name == "Inbox";
             } catch (e) {
               return false;
             }
          }).toList();

          if (relevantTasks.isEmpty) {
             return Center(child: Text("No history yet", style: TextStyle(color: Colors.grey)));
          }

          // 2. Group by Date
          final groups = AnalyticsHelper.groupTasksByDate(relevantTasks);
          
          // 3. Sort Dates (Descending)
          final sortedDates = groups.keys.toList()
            ..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final date = sortedDates[index];
              final tasks = groups[date]!;
              final title = AnalyticsHelper.formatDate(date);
              
              // Calculate daily stats
              final completed = tasks.where((t) => t.isCompleted).length;
              final total = tasks.length;
              final progress = total > 0 ? completed / total : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Date Header
                   Padding(
                     padding: const EdgeInsets.symmetric(vertical: 12),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                         Text("$completed/$total", style: TextStyle(color: Colors.grey)),
                       ],
                     ),
                   ),
                   
                   // Task List for Day
                   ...tasks.map((task) => Container(
                     margin: const EdgeInsets.only(bottom: 8),
                     decoration: BoxDecoration(
                       color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                     ),
                     child: ListTile(
                       dense: true,
                       leading: Icon(
                         task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                         color: task.isCompleted ? Colors.green : Colors.grey,
                         size: 20,
                       ),
                       title: Text(
                         task.title,
                         style: TextStyle(
                            color: textColor,
                            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                            fontSize: 14,
                         ),
                       ),
                     ),
                   )),
                   const Divider(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
