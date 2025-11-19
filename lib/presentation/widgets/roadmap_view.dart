import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import '../widgets/animated_progress_bar.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal_phase.dart';
import '../screens/roadmap_management_screen.dart';

/// Roadmap/Timeline view for phased projects with modern UI
class RoadmapView extends StatelessWidget {
  final int goalId;

  const RoadmapView({
    super.key,
    required this.goalId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Consumer<GrowthProvider>(
      builder: (context, growthProvider, child) {
        final goal = growthProvider.goals.firstWhere(
          (g) => g.id == goalId,
          orElse: () => throw Exception('Goal not found'),
        );
        
        final tasks = growthProvider.getTasksForGoal(goalId);
        final dbPhases = growthProvider.getPhasesForGoal(goalId);
        
        // Only show empty state if both tasks and phases are empty
        if (tasks.isEmpty && dbPhases.isEmpty) {
          return _buildEmptyState(context, goal);
        }

        // Only show phases if they exist in the database (user-created)
        // Don't auto-generate phases
        if (dbPhases.isEmpty) {
          // No phases created yet - show empty state encouraging user to create phases
          return _buildEmptyStateWithTasks(context, goal, tasks);
        } else {
          // Use phases from database
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final phase = dbPhases[index];
                      final phaseTasks = tasks.where((t) => t.phaseId == phase.id).toList();
                      return _buildPhaseCardFromDB(context, phase, phaseTasks, index + 1, index);
                    },
                    childCount: dbPhases.length,
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, Goal goal) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.primaryLight.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(
                Icons.timeline_rounded,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .shimmer(delay: 800.ms, duration: 2000.ms, color: AppTheme.primaryColor.withOpacity(0.3)),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No roadmap yet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Create phases to organize your goal roadmap\nand visualize your journey',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            )
              .animate()
              .fadeIn(delay: 600.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoadmapManagementScreen(
                      goalId: goalId,
                      goalName: goal.name,
                    ),
                  ),
                ).then((_) {
                  context.read<GrowthProvider>().loadGrowthData();
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Create Phases',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLG,
                  vertical: AppTheme.spacingMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                elevation: 4,
              ),
            )
              .animate()
              .fadeIn(delay: 800.ms, duration: 500.ms)
              .scale(delay: 800.ms, duration: 500.ms, curve: Curves.elasticOut),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateWithTasks(BuildContext context, Goal goal, List<GoalTask> tasks) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.primaryLight.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(
                Icons.timeline_rounded,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .shimmer(delay: 800.ms, duration: 2000.ms, color: AppTheme.primaryColor.withOpacity(0.3)),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No phases created yet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'You have ${tasks.length} task${tasks.length == 1 ? '' : 's'}.\nCreate phases to organize them into a roadmap.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            )
              .animate()
              .fadeIn(delay: 600.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RoadmapManagementScreen(
                      goalId: goalId,
                      goalName: goal.name,
                    ),
                  ),
                ).then((_) {
                  context.read<GrowthProvider>().loadGrowthData();
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Create Phases',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLG,
                  vertical: AppTheme.spacingMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                elevation: 4,
              ),
            )
              .animate()
              .fadeIn(delay: 800.ms, duration: 500.ms)
              .scale(delay: 800.ms, duration: 500.ms, curve: Curves.elasticOut),
          ],
        ),
      ),
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

  Widget _buildPhaseCardFromDB(
    BuildContext context,
    GoalPhase phase,
    List<GoalTask> phaseTasks,
    int phaseNumber,
    int index,
  ) {
    final completedCount = phaseTasks.where((s) => s.isCompleted).length;
    final totalCount = phaseTasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final theme = Theme.of(context);
    
    return ModernSmartCard(
      useGradient: true,
      elevationLevel: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phase Number Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.primaryLight.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Center(
                  child: Text(
                    '$phaseNumber',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              
              // Phase Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (phase.description != null && phase.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        phase.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spacingSM),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('MMM d').format(phase.startDate)} - ${DateFormat('MMM d, y').format(phase.endDate)}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Progress Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getProgressColor(progress).withOpacity(0.15),
                      _getProgressColor(progress).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: _getProgressColor(progress).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$completedCount',
                      style: TextStyle(
                        color: _getProgressColor(progress),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '/$totalCount',
                      style: TextStyle(
                        color: _getProgressColor(progress),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Progress Bar
          if (totalCount > 0) ...[
            const SizedBox(height: AppTheme.spacingMD),
            AnimatedProgressBar(
              progress: progress,
              height: 10,
              showPercentage: false,
              progressColor: _getProgressColor(progress),
            ),
          ],
          
          // Tasks List
          if (phaseTasks.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingMD),
            ...phaseTasks.asMap().entries.map((entry) {
              final taskIndex = entry.key;
              final task = entry.value;
              return _buildTaskItem(context, task, taskIndex);
            }),
          ] else ...[
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.textSecondary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: AppTheme.spacingSM),
                  Text(
                    'No tasks assigned to this phase',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    )
      .animate()
      .fadeIn(duration: 600.ms, delay: (index * 100).ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: (index * 100).ms, curve: Curves.easeOutCubic)
      .scale(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1.0, 1.0),
        duration: 600.ms,
        delay: (index * 100).ms,
        curve: Curves.easeOutCubic,
      );
  }

  Widget _buildPhaseCard(
    BuildContext context,
    Phase phase,
    int phaseNumber,
    int index,
  ) {
    final completedCount = phase.tasks.where((s) => s.isCompleted).length;
    final totalCount = phase.tasks.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;
    final theme = Theme.of(context);
    
    return ModernSmartCard(
      useGradient: true,
      elevationLevel: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phase Number Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.2),
                      AppTheme.primaryLight.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Center(
                  child: Text(
                    '$phaseNumber',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              
              // Phase Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phase.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('MMM d').format(phase.startDate)} - ${DateFormat('MMM d, y').format(phase.endDate)}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Progress Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getProgressColor(progress).withOpacity(0.15),
                      _getProgressColor(progress).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: _getProgressColor(progress).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$completedCount',
                      style: TextStyle(
                        color: _getProgressColor(progress),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '/$totalCount',
                      style: TextStyle(
                        color: _getProgressColor(progress),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Progress Bar
          if (totalCount > 0) ...[
            const SizedBox(height: AppTheme.spacingMD),
            AnimatedProgressBar(
              progress: progress,
              height: 10,
              showPercentage: false,
              progressColor: _getProgressColor(progress),
            ),
          ],
          
          // Tasks List
          if (phase.tasks.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingMD),
            ...phase.tasks.asMap().entries.map((entry) {
              final taskIndex = entry.key;
              final task = entry.value;
              return _buildTaskItem(context, task, taskIndex);
            }),
          ],
        ],
      ),
    )
      .animate()
      .fadeIn(duration: 600.ms, delay: (index * 100).ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: (index * 100).ms, curve: Curves.easeOutCubic)
      .scale(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1.0, 1.0),
        duration: 600.ms,
        delay: (index * 100).ms,
        curve: Curves.easeOutCubic,
      );
  }

  Widget _buildTaskItem(BuildContext context, GoalTask task, int index) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: task.isCompleted
              ? AppTheme.successColor.withOpacity(0.05)
              : AppTheme.textSecondary.withOpacity(0.02),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: task.isCompleted
                ? AppTheme.successColor.withOpacity(0.2)
                : AppTheme.borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.isCompleted
                      ? AppTheme.successColor
                      : AppTheme.borderColor,
                  width: 2,
                ),
                color: task.isCompleted
                    ? AppTheme.successColor
                    : Colors.transparent,
              ),
              child: task.isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
            const SizedBox(width: AppTheme.spacingSM),
            
            // Task Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  if (task.scheduledDate != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d').format(task.scheduledDate!),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            // Milestone Badge
            if (task.isMilestone)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  size: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
          ],
        ),
      )
        .animate()
        .fadeIn(delay: (index * 30).ms, duration: 400.ms)
        .slideX(begin: -0.1, end: 0, duration: 400.ms, delay: (index * 30).ms, curve: Curves.easeOutCubic),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.8) return AppTheme.successColor;
    if (progress >= 0.5) return AppTheme.primaryColor;
    if (progress >= 0.25) return AppTheme.primaryLight;
    return AppTheme.textSecondary;
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
