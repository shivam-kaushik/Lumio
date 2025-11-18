import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';

/// Roadmap/Timeline view for phased projects
class RoadmapView extends StatelessWidget {
  final int goalId;

  const RoadmapView({
    super.key,
    required this.goalId,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GrowthProvider>(
      builder: (context, growthProvider, child) {
        final goal = growthProvider.goals.firstWhere(
          (g) => g.id == goalId,
          orElse: () => throw Exception('Goal not found'),
        );
        
        final tasks = growthProvider.getTasksForGoal(goalId);
        
        if (tasks.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timeline_rounded,
                    size: 64,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  Text(
                    'No roadmap yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'Create tasks to see your project roadmap',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        // Group tasks by phase (week or month based on deadline)
        final phases = _groupTasksByPhase(tasks, goal);
        
        return ListView.builder(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          itemCount: phases.length,
          itemBuilder: (context, index) {
            final phase = phases[index];
            return _buildPhaseCard(context, phase, index + 1);
          },
        );
      },
    );
  }

  List<Phase> _groupTasksByPhase(
    List<GoalTask> tasks,
    Goal goal,
  ) {
    final phases = <Phase>[];
    
    if (goal.targetDeadline == null) {
      // No deadline - single phase
      phases.add(Phase(
        name: 'All Tasks',
        tasks: tasks,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
      ));
      return phases;
    }

    // Calculate phase duration based on deadline
    final daysUntilDeadline = goal.targetDeadline!.difference(DateTime.now()).inDays;
    final phaseDuration = (daysUntilDeadline / 4).ceil(); // 4 phases
    
    var currentDate = DateTime.now();
    var phaseIndex = 1;
    
    for (var i = 0; i < 4 && currentDate.isBefore(goal.targetDeadline!); i++) {
      final phaseEndDate = currentDate.add(Duration(days: phaseDuration));
      final phaseEnd = phaseEndDate.isAfter(goal.targetDeadline!)
          ? goal.targetDeadline!
          : phaseEndDate;
      
      final phaseTasks = tasks.where((task) {
        if (task.scheduledDate == null) return false;
        return task.scheduledDate!.isAfter(currentDate.subtract(const Duration(days: 1))) &&
               task.scheduledDate!.isBefore(phaseEnd.add(const Duration(days: 1)));
      }).toList();
      
      if (phaseTasks.isNotEmpty || i == 0) {
        phases.add(Phase(
          name: 'Phase $phaseIndex',
          tasks: phaseTasks,
          startDate: currentDate,
          endDate: phaseEnd,
        ));
        phaseIndex++;
      }
      
      currentDate = phaseEnd;
    }
    
    return phases;
  }

  Widget _buildPhaseCard(BuildContext context, Phase phase, int phaseNumber) {
    final completedCount = phase.tasks.where((s) => s.isCompleted).length;
    final totalCount = phase.tasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        side: BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        phase.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('MMM d').format(phase.startDate)} - ${DateFormat('MMM d, y').format(phase.endDate)}',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '$completedCount/$totalCount',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: AppTheme.borderColor,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 0.8
                    ? Colors.green
                    : progress >= 0.5
                        ? Colors.orange
                        : AppTheme.primaryColor,
              ),
              minHeight: 8,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            ...phase.tasks.map((task) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                  child: Row(
                    children: [
                      Icon(
                        task.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: task.isCompleted
                            ? Colors.green
                            : AppTheme.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (task.scheduledDate != null)
                        Text(
                          DateFormat('MMM d').format(task.scheduledDate!),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class Phase {
  final String name;
  final List<GoalTask> tasks;
  final DateTime startDate;
  final DateTime endDate;

  Phase({
    required this.name,
    required this.tasks,
    required this.startDate,
    required this.endDate,
  });
}

