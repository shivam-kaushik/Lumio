import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/reminder_provider.dart';
import '../providers/growth_provider.dart';
import '../widgets/context_group_card.dart';
import '../theme/theme.dart';

import '../../data/models/reminder.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/services/home_detection_service.dart';
import '../utils/analytics_helper.dart';
import '../navigation/main_navigator.dart';

import 'chat_screen.dart';
import '../widgets/execution_card.dart';
import '../widgets/day_planner_widgets.dart';
import '../widgets/quick_task_input_sheet.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal.dart';

/// Home screen with Stitch AI styling
/// Features: Greeting header, stats, task list, AI assistant access
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  String? _currentActivity;
  bool _hideCompleted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().loadReminders();
      context.read<GrowthProvider>().loadGrowthData();
      _updateContext();
    });
  }

  Future<void> _updateContext() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.whileInUse ||
          hasPermission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
        });
      }

      final homeService = HomeDetectionService();
    } catch (e) {
      debugPrint('Error updating context: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Stitch-style header
          _buildStitchHeader(context),

          // Main content
          Expanded(
            child: Consumer<ReminderProvider>(
              builder: (context, reminderProvider, child) {
                if (reminderProvider.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: LumioColors.primary,
                    ),
                  );
                }

                if (reminderProvider.error != null) {
                  return _buildErrorState(context, reminderProvider);
                }

                final visibleReminders = reminderProvider.reminders;

                return Consumer<GrowthProvider>(
                  builder: (context, growthProvider, _) {
                    // Get unified list of tasks
                    final allReminders = _getAllReminders(
                      visibleReminders,
                      growthProvider,
                    );

                    // Calculate today's plan stats
                    final today = DateTime.now();
                    final dateStr = "${today.year}-${today.month}-${today.day}";
                    final todayGoalName = "Daily Plan - $dateStr";

                    List<GoalTask> calculatedTasks = [];

                    // Daily Plan Tasks
                    final dailyPlanGoal = growthProvider.goals.firstWhere(
                      (g) => g.name == todayGoalName,
                      orElse: () => Goal(id: -1, name: 'temp', createdAt: DateTime.now()),
                    );
                    if (dailyPlanGoal.id != -1) {
                      calculatedTasks.addAll(growthProvider.getTasksForGoal(dailyPlanGoal.id));
                    }

                    // Inbox Tasks (Scheduled for Today)
                    final inboxGoal = growthProvider.goals.firstWhere(
                      (g) => g.name == 'Inbox',
                      orElse: () => Goal(id: -1, name: 'temp', createdAt: DateTime.now()),
                    );
                    if (inboxGoal.id != -1) {
                      final inboxTasks = growthProvider.getTasksForGoal(inboxGoal.id);
                      calculatedTasks.addAll(inboxTasks.where((t) {
                        if (t.scheduledDate == null) return false;
                        return AnalyticsHelper.isSameDay(t.scheduledDate!, today);
                      }));
                    }

                    final completedTaskCount = calculatedTasks.where((t) => t.isCompleted).length;
                    final totalTaskCount = calculatedTasks.length;

                    // Find active task
                    GoalTask? activeTask;
                    final allGoalTasks = growthProvider.tasksByGoal.values.expand((l) => l);
                    for (var t in allGoalTasks) {
                      if (t.startedAt != null) {
                        activeTask = t;
                        break;
                      }
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        await reminderProvider.loadReminders();
                        await growthProvider.loadGrowthData();
                        await _updateContext();
                      },
                      color: LumioColors.primary,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        slivers: [
                          // Stats card
                          SliverToBoxAdapter(
                            child: _buildStatsCard(context, reminderProvider),
                          ),

                          // Hero section (active task, daily summary, or morning hero)
                          Builder(
                            builder: (context) {
                              // Active Execution
                              if (activeTask != null) {
                                return SliverPadding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: LumioSpacing.screenHorizontal,
                                    vertical: LumioSpacing.sm,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: ExecutionCard(task: activeTask!),
                                  ),
                                );
                              }

                              // Daily Summary
                              if (totalTaskCount > 0) {
                                return SliverPadding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: LumioSpacing.screenHorizontal,
                                    vertical: LumioSpacing.sm,
                                  ),
                                  sliver: SliverToBoxAdapter(
                                    child: DailySummaryCard(
                                      completedTasks: completedTaskCount,
                                      totalTasks: totalTaskCount,
                                      onTap: () {
                                        MainNavigator.of(context).switchToDayPlanner();
                                      },
                                    ),
                                  ),
                                );
                              }

                              // Morning Hero (no plan)
                              return SliverPadding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: LumioSpacing.screenHorizontal,
                                  vertical: LumioSpacing.sm,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: MorningHeroCard(
                                    userName: "there",
                                    onTap: () {
                                      MainNavigator.of(context).switchToDayPlanner();
                                    },
                                  ),
                                ),
                              );
                            },
                          ),

                          // Empty state
                          if (allReminders.isEmpty)
                            SliverFillRemaining(child: _buildEmptyState(context)),

                          // Task List
                          if (allReminders.isNotEmpty)
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                LumioSpacing.screenHorizontal,
                                LumioSpacing.sm,
                                LumioSpacing.screenHorizontal,
                                LumioSpacing.md,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: ContextGroupCard(
                                  contextTitle: 'Tasks',
                                  reminders: allReminders,
                                  contextIcon: '📝',
                                  currentPosition: _currentPosition,
                                  onReminderTap: (reminder) => _handleReminderTap(
                                    context,
                                    reminder,
                                    growthProvider,
                                    reminderProvider,
                                  ),
                                  onToggle: (id, enabled) => _handleToggle(
                                    id,
                                    enabled,
                                    growthProvider,
                                    reminderProvider,
                                  ),
                                  onDelete: (id) => _handleDelete(
                                    id,
                                    growthProvider,
                                    reminderProvider,
                                  ),
                                ),
                              ),
                            ),

                          // Bottom padding
                          SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStitchHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        LumioSpacing.screenHorizontal,
        LumioSpacing.md,
        LumioSpacing.screenHorizontal,
        LumioSpacing.md,
      ),
      child: Row(
        children: [
          // Logo with Stitch styling
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: LumioColors.primaryLight,
              borderRadius: LumioRadius.radiusMD,
              boxShadow: LumioShadows.getSoft(context),
            ),
            child: ClipRRect(
              borderRadius: LumioRadius.radiusMD,
              child: Image.asset(
                'assets/icons/Lumio_logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.lightbulb_rounded,
                  color: LumioColors.primary,
                  size: 28,
                ),
              ),
            ),
          )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut),

          SizedBox(width: LumioSpacing.md),

          // Greeting
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: LumioTypography.greeting.copyWith(
                    color: LumioColors.textPrimary(context),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 100.ms)
                    .slideX(begin: -0.1, end: 0, duration: 600.ms),
                SizedBox(height: 2),
                Text(
                  'Ready to achieve more?',
                  style: LumioTypography.bodySmall.copyWith(
                    color: LumioColors.textSecondary(context),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 200.ms)
                    .slideX(begin: -0.1, end: 0, duration: 600.ms),
              ],
            ),
          ),

          // AI Assistant Button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LumioColors.surface(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: LumioColors.border(context),
                width: 1,
              ),
              boxShadow: LumioShadows.getSoft(context),
            ),
            child: IconButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(),
                  ),
                );
              },
              icon: Icon(
                Icons.smart_toy_outlined,
                color: LumioColors.primary,
                size: 22,
              ),
              tooltip: 'AI Assistant',
            ),
          )
              .animate()
              .scale(delay: 400.ms, duration: 500.ms, curve: Curves.elasticOut),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, ReminderProvider provider) {
    final stats = provider.statistics;
    if (stats == null) return const SizedBox.shrink();

    final total = stats['total'] ?? 0;
    final active = stats['active'] ?? 0;
    final completionRate = stats['completionRate'] ?? 0;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.fromLTRB(
        LumioSpacing.screenHorizontal,
        LumioSpacing.sm,
        LumioSpacing.screenHorizontal,
        LumioSpacing.md,
      ),
      padding: LumioSpacing.paddingMD,
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.radiusXXL,
        boxShadow: LumioShadows.getSoft(context),
        border: Border.all(
          color: LumioColors.border(context).withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(context, '$active', 'Active'),
          ),
          Container(
            width: 1,
            height: 40,
            color: LumioColors.border(context),
          ),
          Expanded(
            child: _buildStatItem(context, '$completionRate%', 'Done'),
          ),
          Container(
            width: 1,
            height: 40,
            color: LumioColors.border(context),
          ),
          Expanded(
            child: _buildStatItem(context, '$total', 'Total'),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 600.ms, delay: 100.ms)
        .slideY(begin: -0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: LumioTypography.statsNumber.copyWith(
            color: LumioColors.primary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: LumioTypography.statsLabel.copyWith(
            color: LumioColors.textSecondary(context),
          ),
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
            // Stitch-style icon with rings
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: LumioColors.primary.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: LumioColors.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LumioColors.primaryLight,
                  ),
                  child: Icon(
                    Icons.task_alt_rounded,
                    size: 32,
                    color: LumioColors.primary,
                  ),
                ),
              ],
            ),

            SizedBox(height: LumioSpacing.xl),

            Text(
              'All clear!',
              style: LumioTypography.headlineSmall.copyWith(
                color: LumioColors.textPrimary(context),
              ),
            ),

            SizedBox(height: LumioSpacing.sm),

            Text(
              'No tasks yet. Create one to\nstart being productive!',
              textAlign: TextAlign.center,
              style: LumioTypography.bodyLarge.copyWith(
                color: LumioColors.textSecondary(context),
                height: 1.5,
              ),
            ),

            SizedBox(height: LumioSpacing.xl),

            // CTA Button
            GestureDetector(
              onTap: () => _showCreateTaskSheet(context),
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
                      'Create Task',
                      style: LumioTypography.ctaButton.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ReminderProvider provider) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LumioSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LumioColors.error.withOpacity(0.1),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: LumioColors.error,
              ),
            ),

            SizedBox(height: LumioSpacing.lg),

            Text(
              'Something went wrong',
              style: LumioTypography.titleLarge.copyWith(
                color: LumioColors.textPrimary(context),
              ),
            ),

            SizedBox(height: LumioSpacing.sm),

            Text(
              provider.error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: LumioTypography.bodyMedium.copyWith(
                color: LumioColors.textSecondary(context),
              ),
            ),

            SizedBox(height: LumioSpacing.xl),

            ElevatedButton(
              onPressed: () => provider.loadReminders(),
              style: ElevatedButton.styleFrom(
                backgroundColor: LumioColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickTaskInputSheet(
        onSubmit: (title, date, priority, tags, repeat, location) {
          final start = date ?? DateTime.now();
          int? inboxId;
          try {
            inboxId = context.read<GrowthProvider>().goals.firstWhere((g) => g.name == 'Inbox').id;
          } catch (_) {}

          if (inboxId != null) {
            final newTask = GoalTask(
              id: 0,
              goalId: inboxId,
              title: title,
              description: tags.map((t) => "#$t").join(" "),
              createdAt: DateTime.now(),
              scheduledDate: start,
              priority: priority,
              frequency: repeat ?? 'one-time',
              suggestedLocation: location ?? 'any',
            );
            context.read<GrowthProvider>().createTask(newTask);
          }
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _handleReminderTap(
    BuildContext context,
    Reminder reminder,
    GrowthProvider growthProvider,
    ReminderProvider reminderProvider,
  ) async {
    if (reminder.id.startsWith('task_')) {
      final taskId = int.tryParse(reminder.id.substring(5));
      if (taskId != null) {
        GoalTask? originalTask;
        for (var tasks in growthProvider.tasksByGoal.values) {
          try {
            originalTask = tasks.firstWhere((t) => t.id == taskId);
            break;
          } catch (_) {}
        }

        if (originalTask != null) {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => QuickTaskInputSheet(
              isEditing: true,
              initialTitle: originalTask!.title,
              initialPriority: originalTask!.priority,
              initialTags: RegExp(r'(#[a-zA-Z0-9_]+)', caseSensitive: false)
                  .allMatches(originalTask!.description ?? '')
                  .map((m) => m.group(0)!)
                  .toList(),
              initialRepeat: originalTask!.frequency != 'one-time' ? originalTask!.frequency : null,
              initialLocation: originalTask!.suggestedLocation != 'any' ? originalTask!.suggestedLocation : null,
              onSubmit: (title, date, priority, tags, repeat, location) {
                final updatedTask = originalTask!.copyWith(
                  title: title,
                  description: tags.join(" "),
                  priority: priority,
                  frequency: repeat ?? 'one-time',
                  suggestedLocation: location ?? 'any',
                  scheduledDate: date ?? originalTask!.scheduledDate,
                );
                growthProvider.updateTask(updatedTask);
                Navigator.pop(context);
              },
            ),
          );
        }
      }
      return;
    }

    // Standard Reminder Edit
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickTaskInputSheet(
        isEditing: true,
        initialTitle: reminder.text,
        initialPriority: reminder.priority.name,
        initialDate: reminder.timeAt,
        initialTags: [reminder.category.name],
        onSubmit: (title, date, priority, tags, repeat, location) {
          ReminderCategory newCat = ReminderCategory.other;
          for (var tag in tags) {
            try {
              final cleanTag = tag.startsWith('#') ? tag.substring(1) : tag;
              newCat = ReminderCategory.values.firstWhere(
                  (e) => e.name.toLowerCase() == cleanTag.toLowerCase());
              break;
            } catch (_) {}
          }

          ReminderPriority newPrio = ReminderPriority.medium;
          switch (priority.toLowerCase()) {
            case 'high':
              newPrio = ReminderPriority.high;
              break;
            case 'low':
              newPrio = ReminderPriority.low;
              break;
            case 'critical':
              newPrio = ReminderPriority.critical;
              break;
          }

          final updated = reminder.copyWith(
            text: title,
            timeAt: date ?? reminder.timeAt,
            priority: newPrio,
            category: newCat,
          );
          reminderProvider.updateReminder(updated);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _handleToggle(
    String id,
    bool enabled,
    GrowthProvider growthProvider,
    ReminderProvider reminderProvider,
  ) {
    if (id.startsWith('task_')) {
      final taskId = int.tryParse(id.substring(5));
      if (taskId != null) {
        if (enabled) {
          growthProvider.uncompleteTask(taskId);
        } else {
          growthProvider.completeTask(taskId);
        }
      }
    } else {
      reminderProvider.toggleReminder(id, enabled);
    }
  }

  void _handleDelete(
    String id,
    GrowthProvider growthProvider,
    ReminderProvider reminderProvider,
  ) {
    if (id.startsWith('task_')) {
      final taskId = int.tryParse(id.substring(5));
      if (taskId != null) {
        growthProvider.deleteTask(taskId);
      }
    } else {
      reminderProvider.deleteReminder(id);
    }
  }

  List<Reminder> _getAllReminders(
    List<Reminder> reminders,
    GrowthProvider growthProvider,
  ) {
    final allReminders = [...reminders];

    if (growthProvider.tasksByGoal.isNotEmpty) {
      final allTasks = growthProvider.tasksByGoal.values.expand((list) => list).toList();

      int? inboxGoalId;
      try {
        final inboxGoal = growthProvider.goals.firstWhere((g) => g.name == 'Inbox');
        inboxGoalId = inboxGoal.id;
      } catch (_) {}

      for (var task in allTasks) {
        final isInbox = inboxGoalId != null && task.goalId == inboxGoalId;
        if (!isInbox) continue;

        final displayTitle = task.title
            .replaceAll(RegExp(r'#[a-zA-Z0-9_]+', caseSensitive: false), '')
            .trim();

        allReminders.add(Reminder(
          id: "task_${task.id}",
          text: displayTitle.isNotEmpty ? displayTitle : 'Untitled Task',
          timeAt: task.scheduledDate ?? task.createdAt,
          priority: _mapPriority(task.priority),
          category: _parseCategoryFromDescription(task.description),
          linkedGoalId: task.goalId,
          geofenceId: task.suggestedLocation != 'any' ? task.suggestedLocation : null,
          enabled: !task.isCompleted,
        ));
      }
    }

    allReminders.sort((a, b) {
      if (a.enabled != b.enabled) {
        return a.enabled ? -1 : 1;
      }
      if (a.timeAt != null && b.timeAt != null) {
        return a.timeAt!.compareTo(b.timeAt!);
      }
      return 0;
    });

    return allReminders;
  }

  ReminderCategory _parseCategoryFromDescription(String description) {
    final tagPattern = RegExp(r'(#[a-zA-Z0-9_]+)', caseSensitive: false);
    final match = tagPattern.firstMatch(description);
    if (match != null) {
      final tag = match.group(0)!.substring(1).toLowerCase();
      try {
        return ReminderCategory.values.firstWhere((e) => e.name.toLowerCase() == tag);
      } catch (_) {}
    }
    return ReminderCategory.other;
  }

  ReminderPriority _mapPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return ReminderPriority.high;
      case 'low':
        return ReminderPriority.low;
      case 'critical':
        return ReminderPriority.critical;
      case 'medium':
      default:
        return ReminderPriority.medium;
    }
  }
}
