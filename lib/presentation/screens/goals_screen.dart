import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import '../widgets/animated_progress_bar.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/premium_service.dart';
import 'unified_goal_editor_screen.dart'; // Unified Editor
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart'; // Import GoalTask
import '../../core/services/privacy_gpt_service.dart';
import '../../data/models/subtask.dart' show Task;

/// Goals screen showing all business goals with modern, interactive UI
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
        return AppTheme.successColor;
      case 'Almost There':
        return AppTheme.primaryColor;
      case 'In Progress':
        return AppTheme.primaryLight;
      case 'Getting Started':
        return AppTheme.secondaryColor;
      case 'Just Started':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textTertiary;
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern App Bar with large title
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppTheme.backgroundColor,
            scrolledUnderElevation: 0,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'My Goals',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
              titlePadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: AppTheme.spacingMD),
              centerTitle: false,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacingMD),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const UnifiedGoalEditorScreen(isNew: true),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
                    tooltip: 'Add Goal',
                  ),
                )
                  .animate()
                  .scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
              ),
            ],
          ),
          
          // Content
          Consumer<GrowthProvider>(
            builder: (context, growthProvider, child) {
              if (growthProvider.isLoading) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              }

              final allGoals = growthProvider.goals;
              // Filter out system goals (Inbox, Daily Plans)
              final goals = allGoals.where((g) => 
                  g.name != 'Inbox' && 
                  !g.name.startsWith('Daily Plan')
              ).toList();

              if (goals.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(context),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppTheme.spacingMD,
                    mainAxisSpacing: AppTheme.spacingMD,
                    childAspectRatio: 0.75, // Shorter cards to reduce empty space
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

                      // Staggered animation for grid items
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
                        .scale(begin: const Offset(0.9, 0.9), delay: (50 * index).ms, duration: 400.ms, curve: Curves.easeOutCubic);
                    },
                    childCount: goals.length,
                  ),
                ),
              );
            },
          ),
          // Bottom padding
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.flag_rounded,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .shimmer(delay: 800.ms, duration: 2000.ms, color: AppTheme.primaryColor.withOpacity(0.3)),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No goals, just dreams',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Create your first goal to start turning\nyour dreams into reality',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const UnifiedGoalEditorScreen(isNew: true),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Start New Goal'),
              style: ElevatedButton.styleFrom(
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingMD,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to delete "${goal.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GrowthProvider>().deleteGoal(goal.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = taskCount > 0 ? completedTasks / taskCount : 0.0;
    final status = _getGoalStatus(goal, taskCount, completedTasks);
    final statusColor = _getStatusColor(status);
    final daysRemaining = _getDaysRemaining(goal.targetDeadline);
    
    // Get preview tasks (fill space - top 5)
    final previewTasks = tasks.where((t) => !t.isCompleted).take(5).toList();
    if (previewTasks.isEmpty && tasks.isNotEmpty) {
      previewTasks.addAll(tasks.take(5));
    }

    return ModernSmartCard(
      onTap: () {
        // Navigate to Unified Editor
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UnifiedGoalEditorScreen(
              isNew: false,
              existingGoal: goal,
              initialTasks: tasks, // Pass actual tasks
            ),
          ),
        );
      },
      padding: EdgeInsets.zero, // We handle padding inside
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Delete
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dustbin (Delete) Icon
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showDeleteConfirmation(context, goal),
                        child: Container(
                          padding: const EdgeInsets.all(4), 
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Content Preview (Mini Task List)
                Expanded(
                  child: previewTasks.isEmpty
                      ? Text(
                          "No tasks yet",
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 12,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...previewTasks.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    t.isCompleted ? Icons.check_circle_outline : Icons.circle_outlined,
                                    size: 10,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            if (tasks.length > 5)
                              Text(
                                "+ ${tasks.length - 5} more",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                ),
                
                const SizedBox(height: 12),
                
                // Footer: Progress
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (daysRemaining.isNotEmpty)
                          Text(
                            daysRemaining.split(' ').first + (daysRemaining.contains('left') ? ' days' : ''), // Shorten text
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    AnimatedProgressBar(
                      progress: progress,
                      height: 4,
                      backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                      progressColor: statusColor,
                      showPercentage: false, // Disable duplicate percentage
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
