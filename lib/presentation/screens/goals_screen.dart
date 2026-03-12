import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import '../widgets/animated_progress_bar.dart';
import 'animated_goal_creation_screen.dart';
import 'goal_details_screen.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';

/// Goals screen with Stitch AI styling
/// Features: Goal cards in grid layout, progress tracking, quick actions
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  String _getGoalStatus(Goal goal, int totalTasks, int completedTasks) {
    if (totalTasks == 0) return 'Not Started';
    if (completedTasks == totalTasks) return 'Completed';
    final progress = completedTasks / totalTasks;
    if (progress >= 0.75) return 'Almost There';
    if (progress >= 0.5) return 'In Progress';
    if (progress >= 0.25) return 'Getting Started';
    return 'Just Started';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return LumioColors.success;
      case 'Almost There':
        return LumioColors.primary;
      case 'In Progress':
        return LumioColors.info;
      case 'Getting Started':
        return LumioColors.warning;
      case 'Just Started':
        return LumioColors.categoryPersonal;
      default:
        return LumioColors.primary;
    }
  }

  String _getDaysRemaining(DateTime? deadline) {
    if (deadline == null) return '';
    final now = DateTime.now();
    final difference = deadline.difference(now);
    if (difference.inDays < 0) return 'Overdue';
    if (difference.inDays == 0) return 'Due Today';
    if (difference.inDays == 1) return '1 day left';
    if (difference.inDays < 7) return '${difference.inDays} days left';
    if (difference.inDays < 30) return '${(difference.inDays / 7).ceil()} weeks left';
    return '${(difference.inDays / 30).ceil()} months left';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Stitch-style App Bar
          _buildStickyHeader(context),

          // Content
          Consumer<GrowthProvider>(
            builder: (context, growthProvider, child) {
              if (growthProvider.isLoading) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: LumioColors.primary,
                    ),
                  ),
                );
              }

              final allGoals = growthProvider.goals;
              // Filter out system goals (Inbox, Daily Plans)
              final goals = allGoals
                  .where((g) => g.name != 'Inbox' && !g.name.startsWith('Daily Plan'))
                  .toList();

              if (goals.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(context),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.all(LumioSpacing.screenHorizontal),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: LumioSpacing.md,
                    mainAxisSpacing: LumioSpacing.md,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = goals[index];
                      final tasks = growthProvider.getTasksForGoal(goal.id);

                      int totalTasks = 0;
                      int completedCount = 0;

                      void countRecursive(List<GoalTask> list) {
                        for (var t in list) {
                          totalTasks++;
                          if (t.isCompleted) completedCount++;
                          if (t.subtasks.isNotEmpty) countRecursive(t.subtasks);
                        }
                      }

                      countRecursive(tasks);

                      return _buildGoalCard(
                        context,
                        goal,
                        totalTasks,
                        completedCount,
                        index,
                        tasks,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                          .scale(
                            begin: const Offset(0.95, 0.95),
                            delay: (50 * index).ms,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic,
                          );
                    },
                    childCount: goals.length,
                  ),
                ),
              );
            },
          ),

          // Bottom padding for nav bar
          SliverPadding(padding: EdgeInsets.only(bottom: 120)),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: LumioColors.background(context).withOpacity(0.9),
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: 100,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Goals',
          style: LumioTypography.headlineMedium.copyWith(
            color: LumioColors.textPrimary(context),
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideX(begin: -0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        titlePadding: EdgeInsets.only(
          left: LumioSpacing.screenHorizontal,
          bottom: LumioSpacing.md,
        ),
        centerTitle: false,
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: LumioSpacing.screenHorizontal),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LumioColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnimatedGoalCreationScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              icon: Icon(Icons.add_rounded, color: LumioColors.primary),
              tooltip: 'Add Goal',
            ),
          )
              .animate()
              .scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LumioSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with decorative rings (Stitch style)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: LumioColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: LumioColors.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LumioColors.primaryLight,
                  ),
                  child: Icon(
                    Icons.flag_rounded,
                    size: 40,
                    color: LumioColors.primary,
                  ),
                ),
              ],
            )
                .animate()
                .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),

            SizedBox(height: LumioSpacing.xl),

            Text(
              'No goals yet',
              style: LumioTypography.headlineSmall.copyWith(
                color: LumioColors.textPrimary(context),
              ),
            ),

            SizedBox(height: LumioSpacing.sm),

            Text(
              'Create your first goal to start\nturning ambition into action',
              textAlign: TextAlign.center,
              style: LumioTypography.bodyLarge.copyWith(
                color: LumioColors.textSecondary(context),
                height: 1.5,
              ),
            ),

            SizedBox(height: LumioSpacing.xl),

            // CTA Button (Stitch style)
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnimatedGoalCreationScreen(),
                    fullscreenDialog: true,
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: LumioSpacing.xl,
                  vertical: LumioSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: LumioColors.primary,
                  borderRadius: LumioRadius.radiusFull,
                  boxShadow: LumioShadows.fab,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 20),
                    SizedBox(width: LumioSpacing.sm),
                    Text(
                      'Create Goal',
                      style: LumioTypography.ctaButton.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: LumioColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: LumioRadius.radiusXXL),
        title: Text(
          'Delete Goal?',
          style: LumioTypography.titleLarge.copyWith(
            color: LumioColors.textPrimary(context),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${goal.name}"? This action cannot be undone.',
          style: LumioTypography.bodyMedium.copyWith(
            color: LumioColors.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: LumioColors.textSecondary(context)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GrowthProvider>().deleteGoal(goal.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: LumioColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    Goal goal,
    int taskCount,
    int completedTasks,
    int index,
    List<GoalTask> tasks,
  ) {
    final progress = taskCount > 0 ? completedTasks / taskCount : 0.0;
    final status = _getGoalStatus(goal, taskCount, completedTasks);
    final statusColor = _getStatusColor(status);
    final daysRemaining = _getDaysRemaining(goal.targetDeadline);

    // Get preview tasks (top 4 incomplete, or completed if none)
    final previewTasks = tasks.where((t) => !t.isCompleted).take(4).toList();
    if (previewTasks.isEmpty && tasks.isNotEmpty) {
      previewTasks.addAll(tasks.take(4));
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GoalDetailsScreen(goalId: goal.id),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.radiusXXL,
          boxShadow: LumioShadows.getSoft(context),
          border: Border.all(
            color: LumioColors.border(context).withOpacity(0.5),
          ),
        ),
        child: Padding(
          padding: LumioSpacing.paddingMD,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title + Delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LumioTypography.titleMedium.copyWith(
                        color: LumioColors.textPrimary(context),
                        height: 1.2,
                      ),
                    ),
                  ),
                  SizedBox(width: LumioSpacing.xs),
                  GestureDetector(
                    onTap: () => _showDeleteConfirmation(context, goal),
                    child: Container(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 18,
                        color: LumioColors.textTertiary(context),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: LumioSpacing.sm),

              // Status Badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: LumioSpacing.sm,
                  vertical: LumioSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: LumioRadius.radiusFull,
                ),
                child: Text(
                  status,
                  style: LumioTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              SizedBox(height: LumioSpacing.md),

              // Task Preview
              Expanded(
                child: previewTasks.isEmpty
                    ? Text(
                        'No tasks yet',
                        style: LumioTypography.bodySmall.copyWith(
                          color: LumioColors.textTertiary(context),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...previewTasks.map(
                            (t) => Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: t.isCompleted
                                          ? LumioColors.success.withOpacity(0.15)
                                          : LumioColors.border(context),
                                    ),
                                    child: t.isCompleted
                                        ? Icon(
                                            Icons.check_rounded,
                                            size: 10,
                                            color: LumioColors.success,
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: LumioSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: LumioTypography.bodySmall.copyWith(
                                        color: t.isCompleted
                                            ? LumioColors.textTertiary(context)
                                            : LumioColors.textSecondary(context),
                                        decoration: t.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (tasks.length > 4)
                            Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                '+${tasks.length - 4} more',
                                style: LumioTypography.labelSmall.copyWith(
                                  color: LumioColors.textTertiary(context),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),

              // Footer: Progress
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: LumioTypography.labelMedium.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (daysRemaining.isNotEmpty)
                        Text(
                          daysRemaining,
                          style: LumioTypography.labelSmall.copyWith(
                            color: daysRemaining == 'Overdue'
                                ? LumioColors.error
                                : LumioColors.textTertiary(context),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: LumioSpacing.xs),
                  ClipRRect(
                    borderRadius: LumioRadius.radiusFull,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: LumioColors.border(context),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
