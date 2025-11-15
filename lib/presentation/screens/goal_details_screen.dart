import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../../data/models/goal.dart';
import '../../data/models/skill.dart';
import '../../data/models/goal_subtask.dart';
import 'skill_details_screen.dart';
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

  Future<void> _addSkill() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Skill'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Skill name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        await context.read<GrowthProvider>().createSkill(result, goalId: widget.goalId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Skill added!')),
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
        final skills = growthProvider.getSkillsForGoal(widget.goalId);
        final totalReps = skills.fold<int>(
          0,
          (sum, skill) => sum + growthProvider.getRepsForSkill(skill.id).length,
        );

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
                        'Skills',
                        '${skills.length}',
                        Icons.track_changes_rounded,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total Reps',
                        '$totalReps',
                        Icons.repeat_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingLG),

                // Subtasks section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtasks',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '${growthProvider.getSubtasksForGoal(widget.goalId).length} tasks',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),

                Builder(
                  builder: (context) {
                    final subtasks = growthProvider.getSubtasksForGoal(widget.goalId);
                    if (subtasks.isEmpty) {
                      return Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Center(
                      child: Text(
                        'No subtasks planned yet',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  );
                    }
                    return Column(
                      children: subtasks.map((subtask) => Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                    child: ListTile(
                      leading: subtask.isCompleted
                          ? Icon(Icons.check_circle_rounded, color: Colors.green)
                          : Icon(Icons.radio_button_unchecked_rounded),
                      title: Text(
                        subtask.title,
                        style: TextStyle(
                          decoration: subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(subtask.description),
                          if (subtask.scheduledDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Scheduled: ${DateFormat('MMM d, y').format(subtask.scheduledDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: subtask.isMilestone
                          ? Icon(Icons.flag_rounded, color: AppTheme.primaryColor)
                          : null,
                            onTap: () async {
                              if (!subtask.isCompleted) {
                                final message = await growthProvider.completeSubtask(subtask.id);
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

                const SizedBox(height: AppTheme.spacingLG),

                // Skills section with progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Skills Progress',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: _addSkill,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Skill'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),

                if (skills.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingXL),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.track_changes_rounded,
                            size: 48,
                            color: AppTheme.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            'No skills yet',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: AppTheme.spacingSM),
                          ElevatedButton.icon(
                            onPressed: _addSkill,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add First Skill'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...skills.map((skill) {
                    final reps = growthProvider.getRepsForSkill(skill.id);
                    return _buildSkillCard(context, skill, reps.length);
                  }),
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

  Widget _buildSkillCard(BuildContext context, Skill skill, int repCount) {
    // Calculate progress (toward 30-day streak goal)
    final progress = skill.currentStreak > 0 ? (skill.currentStreak / 30.0).clamp(0.0, 1.0) : 0.0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                  child: Text(
                    skill.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (skill.currentStreak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${skill.currentStreak}',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSM),
                Text(
                  '${skill.totalReps} reps',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

