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
import '../widgets/roadmap_view.dart';
import '../../core/services/adaptive_rescheduling_service.dart';
import 'goal_planning_screen.dart';
import 'roadmap_management_screen.dart';

/// Goal details screen with modern, interactive UI
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

  Future<void> _editGoal(BuildContext context) async {
    final growthProvider = context.read<GrowthProvider>();
    final goal = growthProvider.goals.firstWhere(
      (g) => g.id == widget.goalId,
    );

    final nameController = TextEditingController(text: goal.name);
    DateTime? selectedDeadline = goal.targetDeadline;
    double? hoursPerDay = goal.hoursPerDay;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Edit Goal'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Goal Name',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  const Text(
                    'Deadline',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDeadline ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) {
                        setState(() => selectedDeadline = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 20, color: AppTheme.textSecondary),
                          const SizedBox(width: AppTheme.spacingSM),
                          Text(
                            selectedDeadline != null
                                ? DateFormat('MMM d, y').format(selectedDeadline!)
                                : 'No deadline',
                            style: TextStyle(
                              color: selectedDeadline != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                          if (selectedDeadline != null) ...[
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => selectedDeadline = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  const Text(
                    'Hours per day',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Slider(
                    value: hoursPerDay ?? 2.0,
                    min: 0.5,
                    max: 8.0,
                    divisions: 15,
                    label: '${(hoursPerDay ?? 2.0).toStringAsFixed(1)} hours/day',
                    onChanged: (value) {
                      setState(() => hoursPerDay = value);
                    },
                  ),
                  Text(
                    '${(hoursPerDay ?? 2.0).toStringAsFixed(1)} hours per day',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a goal name')),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'name': nameController.text.trim(),
                    'deadline': selectedDeadline,
                    'hoursPerDay': hoursPerDay,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      try {
        final updatedGoal = goal.copyWith(
          name: result['name'] as String,
          targetDeadline: result['deadline'] as DateTime?,
          hoursPerDay: result['hoursPerDay'] as double?,
        );
        await growthProvider.updateGoal(updatedGoal);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating goal: $e')),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Consumer<GrowthProvider>(
          builder: (context, growthProvider, child) {
            final goal = growthProvider.goals.firstWhere(
              (g) => g.id == widget.goalId,
              orElse: () => throw Exception('Goal not found'),
            );
            return Text(
              goal.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            );
          },
        )
          .animate()
          .fadeIn(duration: 500.ms)
          .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Consumer<GrowthProvider>(
            builder: (context, growthProvider, child) {
              final goal = growthProvider.goals.firstWhere(
                (g) => g.id == widget.goalId,
                orElse: () => throw Exception('Goal not found'),
              );
              return IconButton(
                icon: const Icon(Icons.timeline_rounded),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RoadmapManagementScreen(
                        goalId: widget.goalId,
                        goalName: goal.name,
                      ),
                    ),
                  ).then((_) {
                    context.read<GrowthProvider>().loadGrowthData();
                  });
                },
                tooltip: 'Manage Roadmap',
              )
                .animate()
                .scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteGoal,
            tooltip: 'Delete Goal',
          )
            .animate()
            .scale(delay: 300.ms, duration: 500.ms, curve: Curves.elasticOut),
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
        final progress = tasks.isNotEmpty ? completedTasks / tasks.length : 0.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Goal Header Card
              ModernSmartCard(
                useGradient: true,
                elevationLevel: 2,
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            AppTheme.primaryLight.withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.flag_rounded,
                        color: AppTheme.primaryColor,
                        size: 36,
                      ),
                    )
                      .animate()
                      .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),
                    const SizedBox(height: AppTheme.spacingMD),
                    Text(
                      goal.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 500.ms)
                      .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                    const SizedBox(height: AppTheme.spacingMD),
                    
                    // Progress Section
                    if (tasks.isNotEmpty) ...[
                      AnimatedProgressBar(
                        progress: progress,
                        height: 10,
                        showPercentage: true,
                        progressColor: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                    ],
                    
                    // Goal Info Badges
                    Wrap(
                      spacing: AppTheme.spacingSM,
                      runSpacing: AppTheme.spacingSM,
                      alignment: WrapAlignment.center,
                      children: [
                        if (goal.targetDeadline != null)
                          _buildInfoBadge(
                            Icons.calendar_today_rounded,
                            DateFormat('MMM d, y').format(goal.targetDeadline!),
                            AppTheme.primaryColor,
                          ),
                        if (goal.hoursPerDay != null)
                          _buildInfoBadge(
                            Icons.access_time_rounded,
                            '${goal.hoursPerDay} hrs/day',
                            AppTheme.primaryLight,
                          ),
                        if (goal.totalEstimatedHours != null)
                          _buildInfoBadge(
                            Icons.timer_rounded,
                            '~${goal.totalEstimatedHours} hrs',
                            AppTheme.secondaryColor,
                          ),
                      ],
                    )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 500.ms)
                      .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                    
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
              )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
                .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutCubic),

              const SizedBox(height: AppTheme.spacingLG),

              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Tasks',
                      '${tasks.length}',
                      Icons.checklist_rtl_rounded,
                      0,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Completed',
                      '$completedTasks',
                      Icons.check_circle_rounded,
                      1,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // Overview Section Header with Edit Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _editGoal(context),
                    tooltip: 'Edit Goal',
                    iconSize: 20,
                  )
                    .animate()
                    .scale(delay: 300.ms, duration: 500.ms, curve: Curves.elasticOut),
                ],
              ),

              const SizedBox(height: AppTheme.spacingMD),

              // Tasks section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tasks',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Row(
                    children: [
                      Text(
                        '${tasks.length} total • $completedTasks completed',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      IconButton(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GoalPlanningScreen(
                                goalId: widget.goalId,
                                goalName: goal.name,
                                initialTasks: [],
                                timeline: {
                                  'deadline': goal.targetDeadline ?? DateTime.now().add(const Duration(days: 30)),
                                  'hoursPerDay': goal.hoursPerDay ?? 2.0,
                                },
                              ),
                            ),
                          );
                        },
                        tooltip: 'Add/Edit Tasks',
                        iconSize: 20,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),

              // Tasks List
              Builder(
                builder: (context) {
                  if (tasks.isEmpty) {
                    return ModernSmartCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacingXL),
                        child: Column(
                          children: [
                            Icon(
                              Icons.task_alt_rounded,
                              size: 48,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            Text(
                              'No tasks planned yet',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            Text(
                              'Add tasks to start tracking your progress',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 500.ms)
                      .scale(delay: 400.ms, duration: 500.ms, curve: Curves.easeOutCubic);
                  }
                  return Column(
                    children: tasks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final task = entry.value;
                      return _buildTaskCard(context, task, index, growthProvider);
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSM,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    int index,
  ) {
    return ModernSmartCard(
      useGradient: true,
      elevationLevel: 1,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.2),
                  AppTheme.primaryLight.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    )
      .animate()
      .fadeIn(delay: (300 + index * 100).ms, duration: 500.ms)
      .slideY(begin: 0.2, end: 0, duration: 500.ms, delay: (300 + index * 100).ms, curve: Curves.easeOutCubic)
      .scale(delay: (300 + index * 100).ms, duration: 500.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildTaskCard(
    BuildContext context,
    GoalTask task,
    int index,
    GrowthProvider growthProvider,
  ) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () async {
        if (!task.isCompleted) {
          HapticFeedback.mediumImpact();
          final message = await growthProvider.completeTask(task.id);
          if (mounted && message != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppTheme.successColor,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: ModernSmartCard(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
        useGradient: false,
        elevationLevel: task.isCompleted ? 0 : 1,
        child: Row(
          children: [
            // Checkbox
            Container(
              width: 24,
              height: 24,
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
                      size: 16,
                    )
                  : null,
            ),
            const SizedBox(width: AppTheme.spacingMD),
            
            // Task Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (task.scheduledDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, y').format(task.scheduledDate!),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
              ),
          ],
        ),
      )
        .animate()
        .fadeIn(delay: (400 + index * 50).ms, duration: 500.ms)
        .slideX(begin: -0.2, end: 0, duration: 500.ms, delay: (400 + index * 50).ms, curve: Curves.easeOutCubic),
    );
  }
}
