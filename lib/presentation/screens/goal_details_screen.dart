import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../widgets/roadmap_view.dart';
import '../../core/services/adaptive_rescheduling_service.dart';

/// Goal details screen showing skills and progress
class GoalDetailsScreen extends StatefulWidget {
  final int goalId;

  const GoalDetailsScreen({super.key, required this.goalId});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
      _checkMissedTasks();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkMissedTasks() async {
    final reschedulingService = AdaptiveReschedulingService();
    final result = await reschedulingService.checkAndRescheduleMissedTasks(
      widget.goalId,
      autoReschedule: true,
    );

    if (mounted && result['missedCount'] > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['rescheduledCount']} missed task(s) rescheduled automatically',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _deleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: const Text('This will delete the goal and all its skills. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<GrowthProvider>().deleteGoal(widget.goalId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Goal Details'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteGoal,
            tooltip: 'Delete Goal',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Overview', icon: Icon(Icons.dashboard_rounded, size: 20)),
              Tab(text: 'Roadmap', icon: Icon(Icons.timeline_rounded, size: 20)),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          RoadmapView(goalId: widget.goalId),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Consumer<GrowthProvider>(
      builder: (context, growthProvider, child) {
        final goal = growthProvider.goals.firstWhere(
          (g) => g.id == widget.goalId,
          orElse: () => throw Exception('Goal not found'),
        );
        final tasks = growthProvider.getTasksForGoal(widget.goalId);
        final completedTasks = tasks.where((t) => t.isCompleted).length;

        return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Goal header
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    side: BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flag_rounded,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMD),
                        Text(
                          goal.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        if (goal.targetDeadline != null || goal.hoursPerDay != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacingMD,
                              vertical: AppTheme.spacingSM,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                            ),
                            child: Column(
                              children: [
                                if (goal.targetDeadline != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Deadline: ${DateFormat('MMM d, y').format(goal.targetDeadline!)}',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (goal.hoursPerDay != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.access_time_rounded, size: 14, color: AppTheme.primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Capacity: ${goal.hoursPerDay} hours/day',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (goal.totalEstimatedHours != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_rounded, size: 14, color: AppTheme.primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Total: ~${goal.totalEstimatedHours} hours',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Text(
                          'Created ${DateFormat('MMM d, y').format(goal.createdAt)}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingLG),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Tasks',
                        '${tasks.length}',
                        Icons.checklist_rtl_rounded,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Completed',
                        '$completedTasks',
                        Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingLG),

                // Tasks section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tasks',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '${tasks.length} total • $completedTasks completed',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),

                Builder(
                  builder: (context) {
                    if (tasks.isEmpty) {
                      return Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Center(
                      child: Text(
                        'No tasks planned yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                    }
                    return Column(
                      children: tasks.map((task) => Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                    child: ListTile(
                      leading: task.isCompleted
                          ? Icon(Icons.check_circle_rounded, color: Colors.green)
                          : Icon(Icons.radio_button_unchecked_rounded),
                      title: Text(
                        task.title,
                        style: TextStyle(
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.description),
                          if (task.scheduledDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Scheduled: ${DateFormat('MMM d, y').format(task.scheduledDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: task.isMilestone
                          ? Icon(Icons.flag_rounded, color: AppTheme.primaryColor)
                          : null,
                            onTap: () async {
                              if (!task.isCompleted) {
                                final message = await growthProvider.completeTask(task.id);
                                if (mounted && message != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(message),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                      )).toList(),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 24),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
