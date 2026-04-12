import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import '../widgets/ai_loading_dialog.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal_settings.dart';
import '../../core/services/adaptive_rescheduling_service.dart';
import '../../core/services/premium_service.dart';
import '../../core/services/privacy_gpt_service.dart';
import 'goal_settings_screen.dart';
import 'premium_subscription_screen.dart';

/// Stitch-style Goal Details Screen
/// Features: Large progress ring, AI insights, milestones timeline
class GoalDetailsScreen extends StatefulWidget {
  final int goalId;

  const GoalDetailsScreen({super.key, required this.goalId});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  bool _isAddingTask = false;
  int? _editingTaskId;
  int? _editingSubtaskId;
  final _newTaskController = TextEditingController();
  final _inlineTaskController = TextEditingController();
  final _inlineSubtaskController = TextEditingController();
  final _scrollController = ScrollController();
  final Set<int> _expandedTasks = {};
  int? _addingSubtaskForTaskId;
  final _newSubtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
      _checkMissedTasks();
    });
  }

  @override
  void dispose() {
    _newTaskController.dispose();
    _inlineTaskController.dispose();
    _inlineSubtaskController.dispose();
    _scrollController.dispose();
    _newSubtaskController.dispose();
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
          content: Text('${result['rescheduledCount']} missed task(s) rescheduled'),
          backgroundColor: LumioColors.info,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: LumioRadius.radiusMD),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: Consumer<GrowthProvider>(
        builder: (context, provider, _) {
          final goal = provider.goals.firstWhere(
            (g) => g.id == widget.goalId,
            orElse: () => Goal(id: -1, name: 'Loading...', createdAt: DateTime.now()),
          );

          if (goal.id == -1) {
            return const Center(child: CircularProgressIndicator());
          }

          final tasks = provider.getTasksForGoal(widget.goalId);
          final progress = _calculateProgress(tasks);
          final completedTasks = tasks.where((t) => t.isCompleted).length;
          final totalTasks = tasks.length;

          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(context, goal),
              ),

              // Progress Ring
              SliverToBoxAdapter(
                child: _buildProgressRing(context, progress, goal),
              ),

              // AI Insight Card
              SliverToBoxAdapter(
                child: _buildAIInsightCard(context, goal, progress),
              ),

              // Milestones Section
              SliverToBoxAdapter(
                child: _buildMilestonesSection(context, tasks, provider),
              ),

              // Add Task Section
              if (_isAddingTask)
                SliverToBoxAdapter(
                  child: _buildAddTaskInput(context, provider),
                ),

              // Bottom padding (accounts for nav bar)
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Goal goal) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        LumioSpacing.md,
        MediaQuery.of(context).padding.top + LumioSpacing.md,
        LumioSpacing.md,
        LumioSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: LumioColors.background(context).withOpacity(0.95),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: LumioRadius.radiusFull,
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: LumioColors.textPrimary(context),
                size: 24,
              ),
            ),
          ),

          // Title
          Expanded(
            child: Center(
              child: Text(
                goal.name,
                style: LumioTypography.titleMedium.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Settings / more options button
          GestureDetector(
            onTap: () => _showGoalOptionsSheet(context, goal),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: Icon(
                Icons.settings_outlined,
                color: LumioColors.textPrimary(context),
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing(BuildContext context, double progress, Goal goal) {
    final percentage = (progress * 100).round();
    final dueText = goal.targetDeadline != null
        ? 'On track to finish by ${DateFormat('MMM d').format(goal.targetDeadline!)}'
        : 'No deadline set';

    return Padding(
      padding: EdgeInsets.all(LumioSpacing.screenHorizontal),
      child: Column(
        children: [
          // Large progress ring
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _CircleProgressPainter(
                    progress: 1.0,
                    color: LumioColors.border(context),
                    strokeWidth: 8,
                  ),
                ),
                // Progress ring
                CustomPaint(
                  size: const Size(180, 180),
                  painter: _CircleProgressPainter(
                    progress: progress.clamp(0.0, 1.0),
                    color: LumioColors.primary,
                    strokeWidth: 8,
                  ),
                ),
                // Center content
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$percentage%',
                      style: LumioTypography.displaySmall.copyWith(
                        color: LumioColors.textPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Complete',
                      style: LumioTypography.labelMedium.copyWith(
                        color: LumioColors.textSecondary(context),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: LumioSpacing.md),

          // Due text
          Text(
            dueText,
            style: LumioTypography.bodyMedium.copyWith(
              color: LumioColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightCard(BuildContext context, Goal goal, double progress) {
    String insightText;
    if (progress < 0.25) {
      insightText = "You're just getting started! Let me help you break down this goal into manageable steps.";
    } else if (progress < 0.5) {
      insightText = "Great progress so far! You're building momentum. Keep up the consistency!";
    } else if (progress < 0.75) {
      insightText = "You're more than halfway there! This is where persistence pays off.";
    } else {
      insightText = "You're crushing it! Just a few more tasks and you'll reach your goal.";
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: LumioSpacing.screenHorizontal),
      child: Container(
        padding: EdgeInsets.all(LumioSpacing.lg),
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.card,
          border: Border.all(
            color: LumioColors.primary.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: LumioShadows.getSoft(context),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LumioColors.primary.withOpacity(0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: LumioColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: LumioColors.primary,
                    size: 18,
                  ),
                ),
                SizedBox(width: LumioSpacing.sm),
                Text(
                  'AI Insight',
                  style: LumioTypography.labelMedium.copyWith(
                    color: LumioColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),

            SizedBox(height: LumioSpacing.md),

            // Insight text
            Text(
              insightText,
              style: LumioTypography.bodyMedium.copyWith(
                color: LumioColors.textSecondary(context),
                height: 1.5,
              ),
            ),

            SizedBox(height: LumioSpacing.md),

            // Action button
            GestureDetector(
              onTap: () => _generateTasksWithAI(context),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: LumioSpacing.md,
                  vertical: LumioSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: LumioColors.primary,
                  borderRadius: LumioRadius.radiusFull,
                  boxShadow: [
                    BoxShadow(
                      color: LumioColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Generate',
                      style: LumioTypography.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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

  Widget _buildMilestonesSection(BuildContext context, List<GoalTask> tasks, GrowthProvider provider) {
    // Sort: incomplete first, completed at bottom
    final sorted = [
      ...tasks.where((t) => !t.isCompleted),
      ...tasks.where((t) => t.isCompleted),
    ];

    return Padding(
      padding: EdgeInsets.all(LumioSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Milestones',
                style: LumioTypography.titleMedium.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isAddingTask = !_isAddingTask;
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: LumioColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isAddingTask ? Icons.close_rounded : Icons.add_rounded,
                    color: LumioColors.primary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: LumioSpacing.md),

          // Tasks container
          Container(
            padding: EdgeInsets.all(LumioSpacing.lg),
            decoration: BoxDecoration(
              color: LumioColors.surface(context),
              borderRadius: LumioRadius.card,
              border: Border.all(
                color: LumioColors.border(context),
                width: 1,
              ),
              boxShadow: LumioShadows.getSoft(context),
            ),
            child: tasks.isEmpty
                ? _buildEmptyTasksState(context)
                : Column(
                    children: sorted
                        .map((task) => _buildTaskItem(context, task, provider))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, GoalTask task, GrowthProvider provider) {
    final isCompleted = task.isCompleted;
    final hasSubtasks = task.subtasks.isNotEmpty;
    final isExpanded = _expandedTasks.contains(task.id);
    final isAddingSubtask = _addingSubtaskForTaskId == task.id;

    final completedSubtasks = task.subtasks.where((s) => s.isCompleted).length;

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: EdgeInsets.symmetric(vertical: LumioSpacing.sm),
        decoration: BoxDecoration(
          color: LumioColors.error,
          borderRadius: LumioRadius.taskItem,
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (_) => provider.deleteTask(task.id),
      child: Padding(
      padding: EdgeInsets.symmetric(vertical: LumioSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main task card
          Container(
            padding: EdgeInsets.all(LumioSpacing.md),
            decoration: BoxDecoration(
              color: LumioColors.background(context),
              borderRadius: LumioRadius.taskItem,
              border: Border.all(
                color: isCompleted
                    ? LumioColors.primary.withOpacity(0.2)
                    : LumioColors.border(context).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checkbox — tap to toggle completion
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (isCompleted) {
                          provider.uncompleteTask(task.id);
                        } else {
                          provider.completeTask(task.id);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isCompleted ? LumioColors.primary : Colors.transparent,
                            borderRadius: LumioRadius.radiusXS,
                            border: isCompleted
                                ? null
                                : Border.all(color: LumioColors.border(context), width: 2),
                          ),
                          child: isCompleted
                              ? Icon(Icons.check_rounded, color: Colors.white, size: 14)
                              : null,
                        ),
                      ),
                    ),

                    SizedBox(width: LumioSpacing.md),

                    // Task title + deadline — tap to edit inline
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _editingTaskId == task.id
                              ? TextField(
                                  controller: _inlineTaskController,
                                  autofocus: true,
                                  style: LumioTypography.bodyMedium.copyWith(
                                    color: LumioColors.textPrimary(context),
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                    isDense: true,
                                  ),
                                  onSubmitted: (v) => _saveInlineTaskEdit(task, provider, v),
                                  onTapOutside: (_) => _saveInlineTaskEdit(
                                      task, provider, _inlineTaskController.text),
                                )
                              : GestureDetector(
                                  onTap: () => setState(() {
                                    _editingTaskId = task.id;
                                    _inlineTaskController.text = task.title;
                                  }),
                                  child: Text(
                                    task.title,
                                    style: LumioTypography.bodyMedium.copyWith(
                                      color: isCompleted
                                          ? LumioColors.textSecondary(context)
                                          : LumioColors.textPrimary(context),
                                      decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                          if (task.scheduledDate != null) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _editTaskDeadline(task, provider),
                              child: _buildDeadlineBadge(context, task.scheduledDate!),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Subtask count + expand toggle
                    if (hasSubtasks) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedTasks.remove(task.id);
                            } else {
                              _expandedTasks.add(task.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: LumioColors.primary.withOpacity(0.1),
                            borderRadius: LumioRadius.phaseBadge,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$completedSubtasks/${task.subtasks.length}',
                                style: LumioTypography.labelSmall.copyWith(
                                  color: LumioColors.primary,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                color: LumioColors.primary,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: LumioSpacing.xs),
                    ],

                    // Add subtask button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isAddingSubtask) {
                            _addingSubtaskForTaskId = null;
                            _newSubtaskController.clear();
                          } else {
                            _addingSubtaskForTaskId = task.id;
                            _expandedTasks.add(task.id);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          Icons.add_circle_outline_rounded,
                          color: isAddingSubtask
                              ? LumioColors.primary
                              : LumioColors.textTertiary(context),
                          size: 18,
                        ),
                      ),
                    ),

                    SizedBox(width: LumioSpacing.xs),

                    // More options
                    GestureDetector(
                      onTap: () => _showTaskOptions(context, task, provider),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: LumioColors.textTertiary(context),
                        size: 20,
                      ),
                    ),
                  ],
                ),

                // Inline add-subtask input
                if (isAddingSubtask) ...[
                  SizedBox(height: LumioSpacing.sm),
                  _buildAddSubtaskInput(context, task, provider),
                ],
              ],
            ),
          ),

          // Subtasks list (shown when expanded)
          if (isExpanded && task.subtasks.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: LumioSpacing.xl + 4),
              child: Column(
                children: task.subtasks
                    .map((s) => _buildSubtaskItem(context, s, task, provider))
                    .toList(),
              ),
            ),
        ],
      ),
      ), // end Dismissible child Padding
    );
  }

  Widget _buildSubtaskItem(
    BuildContext context,
    GoalTask subtask,
    GoalTask parentTask,
    GrowthProvider provider,
  ) {
    final isCompleted = subtask.isCompleted;

    return Dismissible(
      key: ValueKey('subtask_${subtask.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: LumioColors.error.withOpacity(0.12),
          borderRadius: LumioRadius.taskItem,
        ),
        child: Icon(Icons.delete_rounded, color: LumioColors.error, size: 18),
      ),
      confirmDismiss: (_) async {
        HapticFeedback.lightImpact();
        return true;
      },
      onDismissed: (_) {
        final newSubtasks = parentTask.subtasks.where((s) => s.id != subtask.id).toList();
        provider.updateTask(parentTask.copyWith(subtasks: newSubtasks));
      },
      child: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Timeline connector dot
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: isCompleted
                  ? LumioColors.primary
                  : LumioColors.border(context),
              shape: BoxShape.circle,
            ),
          ),

          // Subtask checkbox
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              final updated = subtask.copyWith(isCompleted: !isCompleted);
              final newSubtasks = parentTask.subtasks
                  .map((s) => s.id == subtask.id ? updated : s)
                  .toList();
              provider.updateTask(parentTask.copyWith(subtasks: newSubtasks));
            },
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: isCompleted ? LumioColors.primary : Colors.transparent,
                borderRadius: LumioRadius.radiusXS,
                border: isCompleted
                    ? null
                    : Border.all(color: LumioColors.border(context), width: 1.5),
              ),
              child: isCompleted
                  ? Icon(Icons.check_rounded, color: Colors.white, size: 10)
                  : null,
            ),
          ),

          const SizedBox(width: 8),

          // Subtask title — tap to edit inline
          Expanded(
            child: _editingSubtaskId == subtask.id
                ? TextField(
                    controller: _inlineSubtaskController,
                    autofocus: true,
                    style: LumioTypography.bodySmall.copyWith(
                      color: LumioColors.textSecondary(context),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onSubmitted: (v) =>
                        _saveInlineSubtaskEdit(subtask, parentTask, provider, v),
                    onTapOutside: (_) => _saveInlineSubtaskEdit(
                        subtask, parentTask, provider, _inlineSubtaskController.text),
                  )
                : GestureDetector(
                    onTap: () => setState(() {
                      _editingSubtaskId = subtask.id;
                      _inlineSubtaskController.text = subtask.title;
                    }),
                    child: Text(
                      subtask.title,
                      style: LumioTypography.bodySmall.copyWith(
                        color: isCompleted
                            ? LumioColors.textTertiary(context)
                            : LumioColors.textSecondary(context),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
          ),

        ],
      ),
      ), // end Dismissible child Padding
    );
  }

  Widget _buildAddSubtaskInput(
    BuildContext context,
    GoalTask parentTask,
    GrowthProvider provider,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: LumioSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.taskItem,
        border: Border.all(color: LumioColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right_rounded,
              size: 14, color: LumioColors.textTertiary(context)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _newSubtaskController,
              autofocus: true,
              style: LumioTypography.bodySmall.copyWith(
                color: LumioColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Add subtask...',
                hintStyle: LumioTypography.bodySmall.copyWith(
                  color: LumioColors.textTertiary(context),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              onSubmitted: (value) =>
                  _addSubtask(context, parentTask, provider, value.trim()),
            ),
          ),
          GestureDetector(
            onTap: () => _addSubtask(
                context, parentTask, provider, _newSubtaskController.text.trim()),
            child: Icon(Icons.add_circle_rounded,
                color: LumioColors.primary, size: 20),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                _addingSubtaskForTaskId = null;
                _newSubtaskController.clear();
              });
            },
            child: Icon(Icons.close_rounded,
                size: 16, color: LumioColors.textTertiary(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlineBadge(BuildContext context, DateTime date) {
    final overdue = date.isBefore(DateTime.now());
    final color = overdue ? LumioColors.error : LumioColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: LumioRadius.phaseBadge,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            DateFormat('MMM d').format(date),
            style: LumioTypography.labelSmall.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 3),
          Icon(Icons.edit_rounded, size: 9, color: color.withOpacity(0.7)),
        ],
      ),
    );
  }

  Future<void> _addSubtask(
    BuildContext context,
    GoalTask parentTask,
    GrowthProvider provider,
    String title,
  ) async {
    if (title.isEmpty) return;

    final newSubtask = GoalTask(
      id: DateTime.now().millisecondsSinceEpoch,
      goalId: parentTask.goalId,
      title: title,
      description: '',
      createdAt: DateTime.now(),
      indentLevel: 1,
      order: parentTask.subtasks.length,
    );

    final updatedTask = parentTask.copyWith(
      subtasks: [...parentTask.subtasks, newSubtask],
    );
    await provider.updateTask(updatedTask);

    setState(() {
      _addingSubtaskForTaskId = null;
      _newSubtaskController.clear();
      _expandedTasks.add(parentTask.id);
    });
  }

  Widget _buildEmptyTasksState(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(LumioSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.checklist_rounded,
            color: LumioColors.textTertiary(context),
            size: 48,
          ),
          SizedBox(height: LumioSpacing.md),
          Text(
            'No tasks yet',
            style: LumioTypography.titleSmall.copyWith(
              color: LumioColors.textSecondary(context),
            ),
          ),
          SizedBox(height: LumioSpacing.xs),
          Text(
            'Add tasks or let AI generate them',
            style: LumioTypography.bodySmall.copyWith(
              color: LumioColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTaskInput(BuildContext context, GrowthProvider provider) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: LumioSpacing.screenHorizontal),
      child: Container(
        padding: EdgeInsets.all(LumioSpacing.md),
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.card,
          border: Border.all(color: LumioColors.primary.withOpacity(0.3)),
          boxShadow: LumioShadows.getSoft(context),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _newTaskController,
                autofocus: true,
                style: LumioTypography.bodyMedium.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: 'Add a new task...',
                  hintStyle: LumioTypography.bodyMedium.copyWith(
                    color: LumioColors.textTertiary(context),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (value) => _addTask(context, provider),
              ),
            ),
            GestureDetector(
              onTap: () => _addTask(context, provider),
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: LumioColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRescheduleButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 90,
      ),
      child: GestureDetector(
        onTap: () => _showRescheduleSheet(context),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: LumioColors.surface(context),
            borderRadius: LumioRadius.radiusFull,
            border: Border.all(
              color: LumioColors.border(context),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: LumioColors.primary,
                size: 20,
              ),
              SizedBox(width: LumioSpacing.sm),
              Text(
                'Reschedule Goal',
                style: LumioTypography.titleSmall.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods

  double _calculateProgress(List<GoalTask> tasks) {
    if (tasks.isEmpty) return 0;
    int total = 0;
    int completed = 0;

    void count(List<GoalTask> list) {
      for (var t in list) {
        total++;
        if (t.isCompleted) completed++;
        if (t.subtasks.isNotEmpty) count(t.subtasks);
      }
    }

    count(tasks);
    return total > 0 ? completed / total : 0;
  }

  Future<void> _addTask(BuildContext context, GrowthProvider provider) async {
    final title = _newTaskController.text.trim();
    if (title.isEmpty) return;

    final task = GoalTask(
      id: DateTime.now().millisecondsSinceEpoch,
      goalId: widget.goalId,
      title: title,
      description: '',
      createdAt: DateTime.now(),
      estimatedHours: 0.5,
    );

    await provider.createTask(task);

    setState(() {
      _newTaskController.clear();
      _isAddingTask = false;
    });
  }

  Future<void> _saveInlineTaskEdit(GoalTask task, GrowthProvider provider, String value) async {
    final trimmed = value.trim();
    setState(() => _editingTaskId = null);
    if (trimmed.isNotEmpty && trimmed != task.title) {
      await provider.updateTask(task.copyWith(title: trimmed));
    }
  }

  Future<void> _saveInlineSubtaskEdit(
    GoalTask subtask,
    GoalTask parentTask,
    GrowthProvider provider,
    String value,
  ) async {
    final trimmed = value.trim();
    setState(() => _editingSubtaskId = null);
    if (trimmed.isNotEmpty && trimmed != subtask.title) {
      final updatedSubtask = subtask.copyWith(title: trimmed);
      final newSubtasks = parentTask.subtasks
          .map((s) => s.id == subtask.id ? updatedSubtask : s)
          .toList();
      await provider.updateTask(parentTask.copyWith(subtasks: newSubtasks));
    }
  }

  void _showTaskOptions(BuildContext context, GoalTask task, GrowthProvider provider) {
    final goal = provider.goals.firstWhere(
      (g) => g.id == widget.goalId,
      orElse: () => Goal(id: -1, name: '', createdAt: DateTime.now()),
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.bottomSheet,
        ),
        padding: EdgeInsets.all(LumioSpacing.lg),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LumioColors.border(context),
                    borderRadius: LumioRadius.radiusFull,
                  ),
                ),
              ),
              SizedBox(height: LumioSpacing.lg),

              // Task name header
              Padding(
                padding: EdgeInsets.only(bottom: LumioSpacing.sm),
                child: Text(
                  task.title,
                  style: LumioTypography.titleSmall.copyWith(
                    color: LumioColors.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              Divider(color: LumioColors.border(context)),
              SizedBox(height: LumioSpacing.xs),

              // Edit option
              _buildOptionTile(
                context,
                icon: Icons.edit_rounded,
                color: LumioColors.primary,
                label: 'Edit Task',
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editingTaskId = task.id;
                    _inlineTaskController.text = task.title;
                  });
                },
              ),

              // Change deadline
              _buildOptionTile(
                context,
                icon: Icons.event_rounded,
                color: LumioColors.info,
                label: 'Change Deadline',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _editTaskDeadline(task, provider);
                },
              ),

              // Generate subtasks with AI
              _buildOptionTile(
                context,
                icon: Icons.auto_awesome_rounded,
                color: LumioColors.warning,
                label: 'Generate Subtasks with AI',
                onTap: () {
                  Navigator.pop(ctx);
                  _generateSubtasksForTaskWithAI(context, task, provider, goal.name);
                },
              ),

              // Delete option
              _buildOptionTile(
                context,
                icon: Icons.delete_rounded,
                color: LumioColors.error,
                label: 'Delete Task',
                onTap: () {
                  Navigator.pop(ctx);
                  provider.deleteTask(task.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: LumioRadius.radiusMD,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: LumioSpacing.sm, vertical: LumioSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: LumioRadius.radiusMD,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: LumioSpacing.md),
            Text(
              label,
              style: LumioTypography.bodyMedium.copyWith(
                color: color == LumioColors.error ? LumioColors.error : LumioColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateSubtasksForTaskWithAI(
    BuildContext context,
    GoalTask task,
    GrowthProvider provider,
    String goalName,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (context) => const AILoadingDialog(message: 'Generating subtasks with AI...'),
    );

    try {
      final gptService = PrivacyGptService();
      final subtaskData = await gptService.generateSubtasksForTask(
        goalName,
        task.title,
        taskDescription: task.description,
      );

      if (mounted) Navigator.pop(context);

      if (subtaskData.isNotEmpty) {
        final newSubtasks = subtaskData.asMap().entries.map((entry) {
          final s = entry.value;
          return GoalTask(
            id: DateTime.now().millisecondsSinceEpoch + entry.key + 1,
            goalId: task.goalId,
            title: s['title'] as String? ?? 'Subtask',
            description: s['description'] as String? ?? '',
            createdAt: DateTime.now(),
            indentLevel: 1,
            order: task.subtasks.length + entry.key,
          );
        }).toList();

        final updatedTask = task.copyWith(
          subtasks: [...task.subtasks, ...newSubtasks],
        );
        await provider.updateTask(updatedTask);

        setState(() => _expandedTasks.add(task.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generated ${newSubtasks.length} subtasks!'),
              backgroundColor: LumioColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: LumioRadius.radiusMD),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating subtasks: $e'),
            backgroundColor: LumioColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }


  Future<void> _editTaskDeadline(GoalTask task, GrowthProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.scheduledDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null && mounted) {
      await provider.updateTask(task.copyWith(scheduledDate: picked));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Date updated to ${DateFormat('MMM d').format(picked)}'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: LumioRadius.radiusMD),
        ),
      );
    }
  }

  void _showRescheduleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(LumioSpacing.lg),
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.bottomSheet,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LumioColors.border(context),
                  borderRadius: LumioRadius.radiusFull,
                ),
              ),
              SizedBox(height: LumioSpacing.lg),
              Text(
                'Reschedule Goal',
                style: LumioTypography.titleLarge.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
              ),
              SizedBox(height: LumioSpacing.md),
              Text(
                'This will automatically redistribute all remaining tasks based on the new deadline.',
                textAlign: TextAlign.center,
                style: LumioTypography.bodyMedium.copyWith(
                  color: LumioColors.textSecondary(context),
                ),
              ),
              SizedBox(height: LumioSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _selectNewDeadline(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LumioColors.primary,
                    padding: EdgeInsets.symmetric(vertical: LumioSpacing.md),
                    shape: RoundedRectangleBorder(borderRadius: LumioRadius.button),
                  ),
                  child: Text(
                    'Choose New Deadline',
                    style: LumioTypography.ctaButton.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectNewDeadline(BuildContext context) async {
    final provider = context.read<GrowthProvider>();
    final goal = provider.goals.firstWhere((g) => g.id == widget.goalId);

    final picked = await showDatePicker(
      context: context,
      initialDate: goal.targetDeadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );

    if (picked != null && mounted) {
      // Update goal deadline
      await provider.updateGoal(goal.copyWith(targetDeadline: picked));

      // Note: Task rescheduling would be handled by provider

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Goal rescheduled to ${DateFormat('MMM d, y').format(picked)}'),
          backgroundColor: LumioColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: LumioRadius.radiusMD),
        ),
      );
    }
  }

  void _showGoalOptionsSheet(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: false,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.bottomSheet,
        ),
        padding: EdgeInsets.all(LumioSpacing.lg),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LumioColors.border(context),
                    borderRadius: LumioRadius.radiusFull,
                  ),
                ),
              ),
              SizedBox(height: LumioSpacing.lg),

              // Edit Goal
              _buildOptionTile(
                context,
                icon: Icons.edit_rounded,
                color: LumioColors.primary,
                label: 'Edit Goal',
                onTap: () {
                  Navigator.pop(ctx);
                  _editGoal(context);
                },
              ),

              // Notification Settings
              _buildOptionTile(
                context,
                icon: Icons.notifications_outlined,
                color: LumioColors.info,
                label: 'Notification Settings',
                onTap: () async {
                  Navigator.pop(ctx);
                  final provider = context.read<GrowthProvider>();
                  final updatedSettings = await Navigator.of(context).push<GoalSettings>(
                    MaterialPageRoute(
                      builder: (_) => GoalSettingsScreen(initialSettings: goal.settings),
                    ),
                  );
                  if (updatedSettings != null && mounted) {
                    await provider.updateGoal(goal.copyWith(settings: updatedSettings));
                  }
                },
              ),

              Divider(color: LumioColors.border(context), height: LumioSpacing.lg),

              // Delete Goal
              _buildOptionTile(
                context,
                icon: Icons.delete_rounded,
                color: LumioColors.error,
                label: 'Delete Goal',
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteGoal(context, goal);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, Goal goal) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: LumioColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: LumioRadius.dialog),
        title: Text('Delete Goal', style: LumioTypography.titleMedium.copyWith(color: LumioColors.error)),
        content: Text(
          'Delete "${goal.name}"? This will remove all tasks and cannot be undone.',
          style: LumioTypography.bodyMedium.copyWith(color: LumioColors.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: LumioColors.textSecondary(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: LumioColors.error,
              shape: RoundedRectangleBorder(borderRadius: LumioRadius.button),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final provider = context.read<GrowthProvider>();
      await provider.deleteGoal(goal.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _editGoal(BuildContext context) async {
    final provider = context.read<GrowthProvider>();
    final goal = provider.goals.firstWhere((g) => g.id == widget.goalId);

    final titleController = TextEditingController(text: goal.name);
    DateTime? selectedDate = goal.targetDeadline;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: LumioColors.surface(context),
          shape: RoundedRectangleBorder(borderRadius: LumioRadius.dialog),
          title: Text('Edit Goal', style: LumioTypography.titleLarge),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Goal Name',
                    border: OutlineInputBorder(borderRadius: LumioRadius.input),
                  ),
                ),
                SizedBox(height: LumioSpacing.md),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(LumioSpacing.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: LumioColors.border(context)),
                      borderRadius: LumioRadius.input,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 20, color: LumioColors.primary),
                        SizedBox(width: LumioSpacing.sm),
                        Text(
                          selectedDate != null
                              ? DateFormat('MMM d, y').format(selectedDate!)
                              : 'Select deadline',
                          style: LumioTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'name': titleController.text.trim(),
                  'deadline': selectedDate,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LumioColors.primary,
                shape: RoundedRectangleBorder(borderRadius: LumioRadius.button),
              ),
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await provider.updateGoal(goal.copyWith(
        name: result['name'] as String,
        targetDeadline: result['deadline'] as DateTime?,
      ));
    }
  }

  Future<void> _generateTasksWithAI(BuildContext context) async {
    final premiumService = PremiumService();
    if (!await premiumService.isPremium()) {
      if (!mounted) return;
      final parentContext = context;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: LumioColors.surface(dialogContext),
          shape: RoundedRectangleBorder(borderRadius: LumioRadius.dialog),
          title: Text('Premium Feature', style: LumioTypography.titleLarge),
          content: Text(
            'AI task generation is a premium feature. Upgrade to unlock!',
            style: LumioTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openPremiumPaywall(parentContext);
              },
              style: ElevatedButton.styleFrom(backgroundColor: LumioColors.primary),
              child: Text('Upgrade'),
            ),
          ],
        ),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (context) => const AILoadingDialog(message: 'Generating tasks...'),
    );

    try {
      final provider = context.read<GrowthProvider>();
      final goal = provider.goals.firstWhere((g) => g.id == widget.goalId);

      final gptService = PrivacyGptService();
      final result = await gptService.generateDetailedRoadmap(
        goal.name,
        targetDeadline: goal.targetDeadline ?? DateTime.now().add(const Duration(days: 30)),
        hoursPerDay: goal.hoursPerDay ?? 2.0,
      );

      int savedCount = 0;
      if (result != null && result['tasks'] != null) {
        final tasks = result['tasks'] as List;
        final goalDeadline = goal.targetDeadline ?? DateTime.now().add(const Duration(days: 30));
        final now = DateTime.now();
        final totalDays = goalDeadline.difference(now).inDays;
        final daysPerTask = totalDays > 0 ? totalDays / tasks.length : 1;

        for (var i = 0; i < tasks.length; i++) {
          final taskData = tasks[i];
          final daysFromNow = (daysPerTask * (i + 1)).round();
          var scheduledDate = now.add(Duration(days: daysFromNow));
          if (scheduledDate.isAfter(goalDeadline)) scheduledDate = goalDeadline;

          // Parse nested subtasks from AI response
          final subtaskData = taskData['subtasks'] as List? ?? [];
          final subtasks = subtaskData.asMap().entries.map((entry) {
            final s = entry.value as Map<String, dynamic>;
            return GoalTask(
              id: DateTime.now().millisecondsSinceEpoch + i * 1000 + entry.key + 1,
              goalId: widget.goalId,
              title: s['title'] ?? 'Subtask',
              description: s['description'] ?? '',
              estimatedHours: (s['estimatedHours'] ?? 0.5).toDouble(),
              createdAt: DateTime.now(),
              indentLevel: 1,
              order: entry.key,
            );
          }).toList();

          final task = GoalTask(
            id: DateTime.now().millisecondsSinceEpoch + i,
            goalId: widget.goalId,
            title: taskData['title'] ?? taskData['name'] ?? 'Untitled Task',
            description: taskData['description'] ?? '',
            estimatedHours: (taskData['estimatedHours'] ?? 1.0).toDouble(),
            priority: taskData['priority'] ?? 'medium',
            scheduledDate: scheduledDate,
            createdAt: DateTime.now(),
            subtasks: subtasks,
          );
          await provider.createTask(task);
          savedCount++;
        }
      }

      // Close dialog AFTER all tasks are saved
      if (mounted) Navigator.pop(context);

      if (mounted && savedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Generated $savedCount tasks with subtasks!'),
            backgroundColor: LumioColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: LumioRadius.radiusMD),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not generate tasks. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating tasks: $e'),
            backgroundColor: LumioColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

/// Custom painter for circular progress
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
