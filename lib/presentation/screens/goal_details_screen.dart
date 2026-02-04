import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_progress_bar.dart';
import '../widgets/ai_loading_dialog.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../../core/services/adaptive_rescheduling_service.dart';
import '../../core/services/premium_service.dart';
import '../../core/services/privacy_gpt_service.dart';
import 'goal_settings_screen.dart';

/// Goal details screen with modern, clean UI
class GoalDetailsScreen extends StatefulWidget {
  final int goalId;

  const GoalDetailsScreen({super.key, required this.goalId});

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  bool _isAddingTask = false;
  int? _editingTaskId;
  final _newTaskTitleController = TextEditingController();
  final _newTaskDescController = TextEditingController();
  final _scrollController = ScrollController();
  DateTime? _newTaskDate;
  String _newTaskPriority = 'medium';

  final Map<int, TextEditingController> _editTitleControllers = {};
  final Map<int, TextEditingController> _editDescControllers = {};

  final Map<int, DateTime?> _editDates = {};

  // Inline Subtask State
  int? _addingSubtaskParentId;
  int? _editingSubtaskId;
  final TextEditingController _inlineSubtaskController = TextEditingController();

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
    _newTaskTitleController.dispose();
    _newTaskDescController.dispose();
    _scrollController.dispose();
    for (var controller in _editTitleControllers.values) {
      controller.dispose();
    }
    for (var controller in _editDescControllers.values) {
      controller.dispose();
    }
    _inlineSubtaskController.dispose();
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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Start editing task inline
  void _startEditingTask(GoalTask task) {
    setState(() {
      _editingTaskId = task.id;
      _editTitleControllers[task.id] = TextEditingController(text: task.title);
      _editDescControllers[task.id] = TextEditingController(text: task.description);
      _editDates[task.id] = task.scheduledDate;
    });
  }

  // Save edited task
  Future<void> _saveEditedTask(GoalTask task, GrowthProvider growthProvider) async {
    final title = _editTitleControllers[task.id]?.text.trim() ?? '';
    if (title.isEmpty) return;

    final updatedTask = task.copyWith(
      title: title,
      description: _editDescControllers[task.id]?.text.trim() ?? '',
      scheduledDate: _editDates[task.id],
    );

    await growthProvider.updateTask(updatedTask);

    setState(() {
      _editingTaskId = null;
      _editTitleControllers[task.id]?.dispose();
      _editDescControllers[task.id]?.dispose();
      _editTitleControllers.remove(task.id);
      _editDescControllers.remove(task.id);
      _editDates.remove(task.id);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Task updated'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Cancel editing task
  void _cancelEditingTask(int taskId) {
    setState(() {
      _editingTaskId = null;
      _editTitleControllers[taskId]?.dispose();
      _editDescControllers[taskId]?.dispose();
      _editTitleControllers.remove(taskId);
      _editDescControllers.remove(taskId);
      _editDates.remove(taskId);
    });
  }

  Future<void> _editGoal(BuildContext context) async {
    final growthProvider = context.read<GrowthProvider>();
    final goal = growthProvider.goals.firstWhere((g) => g.id == widget.goalId);

    final titleController = TextEditingController(text: goal.name);
    DateTime? selectedDate = goal.targetDeadline;
    double? hoursPerDay = goal.hoursPerDay;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Edit Goal', style: TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Goal Name',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            selectedDate != null
                                ? DateFormat('MMM d, y').format(selectedDate!)
                                : 'Select deadline',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Hours per day',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                      text: hoursPerDay?.toString() ?? '',
                    ),
                    onChanged: (value) {
                      hoursPerDay = double.tryParse(value);
                    },
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
                  Navigator.pop(context, {
                    'name': titleController.text.trim(),
                    'deadline': selectedDate,
                    'hoursPerDay': hoursPerDay,
                  });
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      final updatedGoal = goal.copyWith(
        name: result['name'] as String,
        targetDeadline: result['deadline'] as DateTime?,
        hoursPerDay: result['hoursPerDay'] as double?,
      );
      await growthProvider.updateGoal(updatedGoal);
    }
  }

  Future<void> _deleteGoal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete Goal?'),
        content: const Text('This will delete the goal and all its tasks. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<GrowthProvider>().deleteGoal(widget.goalId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _openGoalSettings() async {
    final growthProvider = context.read<GrowthProvider>();
    final goal = growthProvider.goals.firstWhere((g) => g.id == widget.goalId);

    final newSettings = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GoalSettingsScreen(
          initialSettings: goal.settings,
        ),
      ),
    );

    if (newSettings != null && mounted) {
      final updatedGoal = goal.copyWith(settings: newSettings);
      await growthProvider.updateGoal(updatedGoal);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Goal settings updated'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _generateTasksWithAI() async {
    // Check premium
    final premiumService = PremiumService();
    if (!await premiumService.isPremium()) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Premium Feature'),
            content: const Text('AI task generation is a premium feature. Upgrade to unlock!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to premium screen
                },
                child: const Text('Upgrade'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Show modern loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AILoadingDialog(
          message: 'Generating tasks with AI...',
        ),
      );
    }

    try {
      final growthProvider = context.read<GrowthProvider>();
      final goal = growthProvider.goals.firstWhere((g) => g.id == widget.goalId);

      final gptService = PrivacyGptService();
      final result = await gptService.generateDetailedRoadmap(
        goal.name,
        targetDeadline: goal.targetDeadline ?? DateTime.now().add(const Duration(days: 30)),
        hoursPerDay: goal.hoursPerDay ?? 2.0,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
      }

      if (result != null && result['tasks'] != null) {
        final tasks = result['tasks'] as List;

        // Calculate distributed dates for tasks based on goal deadline
        final goalDeadline = goal.targetDeadline ?? DateTime.now().add(const Duration(days: 30));
        final now = DateTime.now();
        final totalDays = goalDeadline.difference(now).inDays;
        final daysPerTask = totalDays > 0 ? totalDays / tasks.length : 1;

        for (var i = 0; i < tasks.length; i++) {
          final taskData = tasks[i];

          // Calculate scheduled date for this task (distribute evenly)
          DateTime scheduledDate;
          if (taskData['scheduledDate'] != null) {
            // Use AI-provided date if available
            scheduledDate = DateTime.parse(taskData['scheduledDate']);
          } else {
            // Distribute tasks evenly from now to deadline
            final daysFromNow = (daysPerTask * (i + 1)).round();
            scheduledDate = now.add(Duration(days: daysFromNow));

            // Ensure it doesn't exceed goal deadline
            if (scheduledDate.isAfter(goalDeadline)) {
              scheduledDate = goalDeadline;
            }
          }

          final task = GoalTask(
            id: DateTime.now().millisecondsSinceEpoch + i,
            goalId: widget.goalId,
            title: taskData['title'] ?? taskData['name'] ?? 'Untitled Task',
            description: taskData['description'] ?? '',
            estimatedHours: (taskData['estimatedHours'] ?? 1.0).toDouble(),
            priority: taskData['priority'] ?? 'medium',
            scheduledDate: scheduledDate,
            createdAt: DateTime.now(),
          );
          await growthProvider.createTask(task);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✨ Generated ${tasks.length} tasks!'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _startAddingTask() {
    setState(() {
      _isAddingTask = true;
      _newTaskTitleController.clear();
      _newTaskDescController.clear();
      _newTaskDate = null;
      _newTaskPriority = 'medium';
    });

    // Scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 500, // Extra space for new form
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveNewTask() async {
    if (_newTaskTitleController.text.trim().isEmpty) return;

    final task = GoalTask(
      id: DateTime.now().millisecondsSinceEpoch,
      goalId: widget.goalId,
      title: _newTaskTitleController.text.trim(),
      description: _newTaskDescController.text.trim(),
      priority: _newTaskPriority,
      scheduledDate: _newTaskDate,
      createdAt: DateTime.now(),
    );

    await context.read<GrowthProvider>().createTask(task);

    setState(() {
      _isAddingTask = false;
      _newTaskTitleController.clear();
      _newTaskDescController.clear();
      _newTaskDate = null;
      _newTaskPriority = 'medium';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Task added'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _cancelAddingTask() {
    setState(() {
      _isAddingTask = false;
      _newTaskTitleController.clear();
      _newTaskDescController.clear();
      _newTaskDate = null;
      _newTaskPriority = 'medium';
    });
  }

  Future<void> _generateSubtasksForTask(GoalTask task) async {
    // Check premium
    final premiumService = PremiumService();
    if (!await premiumService.isPremium()) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Premium Feature'),
            content: const Text('AI subtask generation is a premium feature. Upgrade to unlock!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Show modern loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AILoadingDialog(
        message: 'Generating subtasks...',
      ),
    );

    try {
      final gptService = PrivacyGptService();
      // Use breakDownTask to generate subtasks
      final result = await gptService.breakDownTask(task.title);

      if (mounted) {
        Navigator.pop(context); // Close loading
      }

      if (result != null && result.isNotEmpty) {
        final updatedSubtasks = result.map((st) {
          return GoalTask(
            id: DateTime.now().millisecondsSinceEpoch + result.indexOf(st),
            goalId: widget.goalId,
            title: st['title'] ?? st['name'] ?? 'Subtask',
            description: st['description'] ?? '',
            estimatedHours: (st['estimatedHours'] ?? 0.5).toDouble(),
            priority: st['priority'] ?? task.priority,
            createdAt: DateTime.now(),
          );
        }).toList();

        final updatedTask = task.copyWith(subtasks: updatedSubtasks);
        await context.read<GrowthProvider>().updateTask(updatedTask);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✨ Generated ${result.length} subtasks!'),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating subtasks: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _showTaskMenu(GoalTask task) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.auto_awesome, color: Colors.purple),
              title: const Text('Generate Subtasks (AI)'),
              onTap: () {
                Navigator.pop(context);
                _generateSubtasksForTask(task);
              },
            ),
            ListTile(
              leading: Icon(Icons.add_task, color: AppTheme.primaryColor),
              title: const Text('Add Subtask'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _addingSubtaskParentId = task.id;
                  _inlineSubtaskController.clear();
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_rounded, color: AppTheme.errorColor),
              title: const Text('Delete Task'),
              onTap: () async {
                final provider = context.read<GrowthProvider>(); // Capture context safely
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('Delete Task?'),
                    content: Text('Delete "${task.title}"?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await provider.deleteTask(task.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getProgressStatus(double progress, DateTime? deadline) {
    if (deadline == null) return 'IN PROGRESS';
    final daysLeft = deadline.difference(DateTime.now()).inDays;
    if (progress >= 0.9) return 'ALMOST DONE';
    if (daysLeft < 0) return 'OVERDUE';
    if (daysLeft < 7 && progress < 0.5) return 'AT RISK';
    return 'ON TRACK';
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.75) return AppTheme.successColor;
    if (progress >= 0.5) return AppTheme.primaryColor;
    if (progress >= 0.25) return AppTheme.secondaryColor;
    return AppTheme.textSecondary;
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openGoalSettings,
            tooltip: 'Goal Settings',
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => _editGoal(context),
            tooltip: 'Edit Goal',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteGoal,
            tooltip: 'Delete Goal',
          ),
        ],
      ),
      body: Consumer<GrowthProvider>(
        builder: (context, growthProvider, child) {
          final goal = growthProvider.goals.firstWhere(
            (g) => g.id == widget.goalId,
            orElse: () => throw Exception('Goal not found'),
          );
          final tasks = growthProvider.getTasksForGoal(widget.goalId);

          // Calculate progress (counting only top-level tasks)
          int totalTasksCount = tasks.length;
          int completedTasksCount = tasks.where((t) => t.isCompleted).length;

          final progress = totalTasksCount > 0 ? completedTasksCount / totalTasksCount : 0.0;

          return ReorderableListView(
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (BuildContext context, Widget? child) {
                  final double animValue = Curves.easeInOut.transform(animation.value);
                  final double elevation = lerpDouble(0, 6, animValue)!;
                  return Material(
                    elevation: elevation,
                    color: Colors.transparent,
                    shadowColor: Colors.black.withOpacity(0.2),
                    child: child,
                  );
                },
                child: child,
              );
            },
            onReorder: (oldIndex, newIndex) {
              // Adjust index because of the header item (index 0)
              if (oldIndex == 0 || newIndex == 0) return; // Cannot move header
              
              // Map list logic considering header is index 0
              int taskOldIndex = oldIndex - 1;
              int taskNewIndex = newIndex - 1;
              
              if (taskOldIndex < taskNewIndex) {
                // taskNewIndex -= 1; // Handled by provider logic usually, but keep standard reorder logic
              }
              
              growthProvider.reorderTasks(widget.goalId, taskOldIndex, taskNewIndex);
            },
            header: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Hero Image
                    CachedNetworkImage(
                      imageUrl: goal.imageUrl ?? generateGoalImageUrl(goal.name),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      imageBuilder: (context, imageProvider) => Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                        ),
                      ),
                      placeholder: (context, url) => Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppTheme.primaryColor.withOpacity(0.1),
                        ),
                        child: Center(
                            child: CircularProgressIndicator(color: AppTheme.primaryColor)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: AppTheme.primaryColor.withOpacity(0.2),
                        ),
                        child: Center(
                            child: Icon(Icons.flag_rounded, size: 64, color: AppTheme.primaryColor)),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .shimmer(delay: 600.ms, duration: 2000.ms, color: Colors.white.withOpacity(0.3)),

                    const SizedBox(height: 16),
                    // Progress Section with Gradient
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getProgressColor(progress).withOpacity(0.15),
                            _getProgressColor(progress).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _getProgressColor(progress).withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _getProgressColor(progress),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  progress >= 0.9 ? Icons.celebration_rounded : Icons.trending_up_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Progress: ${(progress * 100).toInt()}% ${_getProgressStatus(progress, goal.targetDeadline)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: _getProgressColor(progress),
                                      ),
                                    ),
                                    if (goal.targetDeadline != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Due: ${DateFormat('MMM d, y').format(goal.targetDeadline!)}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          AnimatedProgressBar(
                            progress: progress,
                            height: 8,
                            backgroundColor: Colors.grey.shade200,
                            progressColor: _getProgressColor(progress),
                            showPercentage: false,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacingLG),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _generateTasksWithAI,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('AI Generate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _startAddingTask,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Add Task'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryColor,
                              side: BorderSide(color: AppTheme.primaryColor, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    Text(
                      'Tasks',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    
                    if (_isAddingTask)
                        _buildInlineTaskForm(),
                ],
              ),
            ),
            children: [
              for (int i = 0; i < tasks.length; i++)
                _buildTimelineTaskCard(context, tasks[i], i, growthProvider, isLast: i == tasks.length - 1)
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimelineTaskCard(
    BuildContext context,
    GoalTask task,
    int index,
    GrowthProvider growthProvider, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return IntrinsicHeight(
      key: ValueKey('task_${task.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Timeline Column
          SizedBox(
            width: 50,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical Line
                if (!isLast)
                  Positioned(
                    top: 24,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: theme.dividerColor,
                    ),
                  ),

                // Status Node (Checkmark or Circle)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      if (task.isCompleted) {
                          await growthProvider.uncompleteTask(task.id);
                      } else {
                          await growthProvider.completeTask(task.id);
                      }
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: task.isCompleted ? AppTheme.successColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: task.isCompleted 
                              ? AppTheme.successColor 
                              : (task.isMilestone ? AppTheme.primaryColor : theme.dividerColor),
                          width: 2,
                        ),
                      ),
                      child: task.isCompleted
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : (task.isMilestone 
                              ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)))
                              : null),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Card Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Dismissible(
                key: Key('dismiss_task_${task.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                   return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                         title: const Text("Delete Task?"),
                         content: Text('Are you sure you want to delete "${task.title}"?'),
                         actions: [
                           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                           TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                         ],
                      )
                   );
                },
                onDismissed: (direction) {
                   growthProvider.deleteTask(task.id);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Icon + Title + Menu
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Leading Icon
                             if (task.isMilestone)
                                Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.orange.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.flag_outlined, size: 20, color: AppTheme.primaryColor),
                                ),
                            
                            Expanded(
                              child: _editingTaskId == task.id
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TextField(
                                          controller: _editTitleControllers[task.id],
                                          decoration: InputDecoration(
                                            labelText: 'Title',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                          autofocus: true,
                                        ),
                                        const SizedBox(height: 8),
                                        TextField(
                                          controller: _editDescControllers[task.id],
                                          decoration: InputDecoration(
                                            labelText: 'Description (optional)',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            filled: true,
                                            fillColor: Colors.grey.shade50,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          ),
                                          maxLines: 2,
                                        ),
                                        const SizedBox(height: 8),
                                        // Save/Cancel buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => _cancelEditingTask(task.id),
                                                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () => _saveEditedTask(task, growthProvider),
                                                child: const Text('Save', style: TextStyle(fontSize: 12)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppTheme.primaryColor,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  : GestureDetector(
                                      onTap: () => _startEditingTask(task),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          if (task.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              task.description,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: isDark ? Colors.white60 : Colors.black54,
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ),
                            ),
                            
                            // Menu Icon (Draggable Handle implicit in ReorderableListView, but we add menu for actions)
                            IconButton(
                                icon: Icon(Icons.more_horiz, color: isDark ? Colors.white54 : Colors.grey),
                                onPressed: () => _showTaskMenu(task),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),

                      // SUBTASKS (Inline, no Add button here)
                      if (task.subtasks.isNotEmpty || _addingSubtaskParentId == task.id)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                ...task.subtasks.map((sub) => _buildInlineSubtask(context, sub, task, growthProvider)).toList(),
                                
                                // Inline Add Subtask Input
                                if (_addingSubtaskParentId == task.id)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, left: 28),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _inlineSubtaskController,
                                            autofocus: true,
                                            decoration: InputDecoration(
                                              hintText: 'Enter subtask name...',
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                              filled: true,
                                              fillColor: isDark ? Colors.grey.shade900 : Colors.white,
                                            ),
                                            onSubmitted: (_) async {
                                               if (_inlineSubtaskController.text.trim().isNotEmpty) {
                                                  final newSub = GoalTask(
                                                     id: DateTime.now().millisecondsSinceEpoch,
                                                     goalId: widget.goalId,
                                                     title: _inlineSubtaskController.text.trim(),
                                                     description: '',
                                                     estimatedHours: 0.5,
                                                     priority: task.priority,
                                                     createdAt: DateTime.now(),
                                                  );
                                                  final updatedSubtasks = [...task.subtasks, newSub];
                                                  await growthProvider.updateTask(task.copyWith(subtasks: updatedSubtasks));
                                                  _inlineSubtaskController.clear();
                                                  // Keep focus to add another? Or close? User request implies "fill in it", usually allowing repetitive entry is good.
                                                  // But for now let's keep it open until cancelled or "done"? 
                                                  // Actually standard pattern is keep adding until tap away or cancel.
                                                  // I'll keep it open.
                                               }
                                            },
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.check_circle, color: AppTheme.successColor),
                                          onPressed: () async {
                                               if (_inlineSubtaskController.text.trim().isNotEmpty) {
                                                  final newSub = GoalTask(
                                                     id: DateTime.now().millisecondsSinceEpoch,
                                                     goalId: widget.goalId,
                                                     title: _inlineSubtaskController.text.trim(),
                                                     description: '',
                                                     estimatedHours: 0.5,
                                                     priority: task.priority,
                                                     createdAt: DateTime.now(),
                                                  );
                                                  final updatedSubtasks = [...task.subtasks, newSub];
                                                  await growthProvider.updateTask(task.copyWith(subtasks: updatedSubtasks));
                                                  _inlineSubtaskController.clear();
                                               }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: Colors.grey),
                                          onPressed: () {
                                            setState(() {
                                              _addingSubtaskParentId = null;
                                              _inlineSubtaskController.clear();
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                      const SizedBox(height: 16),

                      // Footer: Meta info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black12 : Colors.grey.shade50,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          border: task.isMilestone 
                              ? const Border(bottom: BorderSide(color: AppTheme.primaryColor, width: 3))
                              : null, 
                        ),
                        child: Row(
                          children: [
                            Icon(
                              (task.frequency != 'one-time' && task.frequency != null)
                                  ? Icons.repeat_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 16,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            if (task.scheduledDate != null)
                               Text(
                                  DateFormat('MMM d').format(task.scheduledDate!),
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                               ),
                            const Spacer(),
                            if (task.subtasks.isNotEmpty)
                               Text(
                                  '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length} subtasks',
                                  style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                               ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Padding right for aesthetics
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildInlineSubtask(BuildContext context, GoalTask subtask, GoalTask parentTask, GrowthProvider provider) {
     final theme = Theme.of(context);
     final isDark = theme.brightness == Brightness.dark;
     
     return Dismissible(
       key: ValueKey('subtask_${subtask.id}'),
       direction: DismissDirection.endToStart,
       background: Container(
         alignment: Alignment.centerRight,
         padding: const EdgeInsets.only(right: 16),
         color: AppTheme.errorColor.withOpacity(0.1),
         child: const Icon(Icons.delete_rounded, color: AppTheme.errorColor, size: 20),
       ),
       confirmDismiss: (direction) async {
          return await showDialog<bool>(
             context: context,
             builder: (ctx) => AlertDialog(
                title: const Text("Delete Subtask?"),
                content: Text('Delete "${subtask.title}"?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                ],
             )
          );
       },
       onDismissed: (direction) async {
          final updatedSubtasks = parentTask.subtasks.where((st) => st.id != subtask.id).toList();
          await provider.updateTask(parentTask.copyWith(subtasks: updatedSubtasks));
       },
       child: Padding(
         padding: const EdgeInsets.only(bottom: 8.0, left: 4),
       child: Row(
         children: [
            InkWell(
               onTap: () async {
                  // Toggle subtask completion
                  // Logic requires updating parent task manually or adding subtask completion logic to provider
                  final updatedSubtasks = parentTask.subtasks.map((s) {
                     if (s.id == subtask.id) {
                        return s.copyWith(isCompleted: !s.isCompleted);
                     }
                     return s;
                  }).toList();
                  provider.updateTask(parentTask.copyWith(subtasks: updatedSubtasks));
               },
               child: Icon(
                  subtask.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: subtask.isCompleted ? AppTheme.successColor : Colors.grey.shade400,
               ),
            ),
            const SizedBox(width: 8),
            Expanded(
               child: _editingSubtaskId == subtask.id
                   ? Row(
                       children: [
                         Expanded(
                           child: TextField(
                             controller: _inlineSubtaskController,
                             autofocus: true,
                             decoration: const InputDecoration(
                               isDense: true,
                               contentPadding: EdgeInsets.symmetric(vertical: 4),
                               border: InputBorder.none,
                             ),
                             onSubmitted: (value) async {
                               if (value.trim().isNotEmpty) {
                                 final updatedSubtasks = parentTask.subtasks.map((s) {
                                    if (s.id == subtask.id) return s.copyWith(title: value.trim());
                                    return s;
                                 }).toList();
                                 await provider.updateTask(parentTask.copyWith(subtasks: updatedSubtasks));
                                 setState(() => _editingSubtaskId = null);
                                 _inlineSubtaskController.clear();
                               }
                             },
                           ),
                         ),
                         IconButton(
                           icon: const Icon(Icons.check, size: 18, color: AppTheme.successColor),
                           onPressed: () async {
                               if (_inlineSubtaskController.text.trim().isNotEmpty) {
                                 final updatedSubtasks = parentTask.subtasks.map((s) {
                                    if (s.id == subtask.id) return s.copyWith(title: _inlineSubtaskController.text.trim());
                                    return s;
                                 }).toList();
                                 await provider.updateTask(parentTask.copyWith(subtasks: updatedSubtasks));
                                 setState(() => _editingSubtaskId = null);
                                 _inlineSubtaskController.clear();
                               }
                           },
                         ),
                         IconButton(
                           icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                           onPressed: () {
                              setState(() => _editingSubtaskId = null);
                              _inlineSubtaskController.clear();
                           },
                         ),
                       ],
                     )
                   : GestureDetector(
                       onTap: () {
                         setState(() {
                           _editingSubtaskId = subtask.id;
                           _inlineSubtaskController.text = subtask.title;
                         });
                       },
                       child: Text(
                          subtask.title,
                          style: TextStyle(
                             fontSize: 14,
                             decoration: subtask.isCompleted ? TextDecoration.lineThrough : null,
                             color: isDark ? Colors.white70 : Colors.black87,
                          ),
                       ),
                     ),
            ),
         ],
       ),
       ),
     );
  }

  // Helper to build inline form (simplified)
  Widget _buildInlineTaskForm() {
      return Padding(
          padding: const EdgeInsets.only(bottom: 16, left: 50, right: 16), // Align with cards
          child: Column(
             children: [
                 TextField(
                     controller: _newTaskTitleController,
                     decoration: InputDecoration(
                        hintText: "Enter task name...",
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                     ),
                 ),
                 const SizedBox(height: 8),
                 Row(
                    children: [
                       ElevatedButton(onPressed: _saveNewTask, child: const Text("Save")),
                       TextButton(onPressed: _cancelAddingTask, child: const Text("Cancel")),
                    ],
                 )
             ],
          ),
      );
  }


  Widget _buildStatusBadge(GoalTask task) {
    String status;
    Color color;
    IconData icon;

    if (task.isCompleted) {
      status = 'Completed';
      color = AppTheme.successColor;
      icon = Icons.check_circle;
    } else if (task.scheduledDate == null) {
      status = 'Upcoming';
      color = Colors.blue;
      icon = Icons.schedule;
    } else if (task.scheduledDate!.isBefore(DateTime.now())) {
      status = 'Overdue';
      color = AppTheme.errorColor;
      icon = Icons.warning_rounded;
    } else if (task.scheduledDate!.difference(DateTime.now()).inDays <= 1) {
      status = 'In Progress';
      color = AppTheme.primaryColor;
      icon = Icons.play_circle_filled;
    } else {
      status = 'Upcoming';
      color = Colors.blue;
      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    GoalTask task,
    int index,
    GrowthProvider growthProvider,
  ) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key('task_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Delete Task?'),
            content: Text('Delete "${task.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) async {
        await growthProvider.deleteTask(task.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Task deleted'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: task.isCompleted
                ? Colors.grey.shade200
                : AppTheme.primaryColor.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Checkbox - ONLY way to mark complete
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  if (task.isCompleted) {
                    await growthProvider.uncompleteTask(task.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Task unmarked'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  } else {
                    final message = await growthProvider.completeTask(task.id);
                    if (mounted && message != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: AppTheme.successColor,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.isCompleted
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                      width: 2.5,
                    ),
                    color: task.isCompleted
                        ? AppTheme.successColor
                        : Colors.transparent,
                  ),
                  child: task.isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Task Title & Description - Tap to edit or show edit fields
              Expanded(
                child: _editingTaskId == task.id
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _editTitleControllers[task.id],
                            decoration: InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            autofocus: true,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _editDescControllers[task.id],
                            decoration: InputDecoration(
                              labelText: 'Description (optional)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          // Date picker
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _editDates[task.id] ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (date != null) {
                                setState(() => _editDates[task.id] = date);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderColor),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.grey.shade50,
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                                  const SizedBox(width: 6),
                                  Text(
                                    _editDates[task.id] != null
                                        ? DateFormat('MMM d, y').format(_editDates[task.id]!)
                                        : 'Set date',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const Spacer(),
                                  if (_editDates[task.id] != null)
                                    IconButton(
                                      icon: Icon(Icons.clear, size: 14),
                                      onPressed: () => setState(() => _editDates[task.id] = null),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Save/Cancel buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _cancelEditingTask(task.id),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _saveEditedTask(task, growthProvider),
                                  child: const Text('Save', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : GestureDetector(
                        onTap: () => _startEditingTask(task),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
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
                          ],
                        ),
                      ),
              ),

              // Menu Button
              IconButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.textSecondary,
                ),
                onPressed: () => _showTaskMenu(task),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom Row: Status, Date, Priority
          Row(
            children: [
              _buildStatusBadge(task),
              const SizedBox(width: 8),
              if (task.scheduledDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d').format(task.scheduledDate!),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (task.isMilestone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Milestone',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Subtasks section with add button
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.subtasks.isEmpty
                          ? 'Subtasks'
                          : '${task.subtasks.length} Subtasks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    // Add Subtask Button
                    GestureDetector(
                      onTap: () => _showAddSubtaskDialog(task, growthProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (task.subtasks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Show ALL subtasks
                  ...task.subtasks.map((subtask) => _buildSubtaskItem(subtask, task, growthProvider)),
                ],
              ],
            ),
          ),
        ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (50 * index).ms)
        .slideX(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildSubtaskItem(GoalTask subtask, GoalTask parentTask, GrowthProvider growthProvider) {
    return Dismissible(
      key: Key('subtask_${subtask.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Delete Subtask?'),
            content: Text('Delete "${subtask.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) async {
        // Remove subtask from parent task
        final updatedSubtasks = parentTask.subtasks
            .where((st) => st.id != subtask.id)
            .toList();
        final updatedParentTask = parentTask.copyWith(subtasks: updatedSubtasks);
        await growthProvider.updateTask(updatedParentTask);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Subtask deleted'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: subtask.isCompleted
                ? Colors.grey.shade200
                : AppTheme.primaryColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subtask Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  // Toggle subtask completion
                  final updatedSubtask = subtask.copyWith(isCompleted: !subtask.isCompleted);
                  final updatedSubtasks = parentTask.subtasks.map((st) {
                    return st.id == subtask.id ? updatedSubtask : st;
                  }).toList();
                  final updatedParentTask = parentTask.copyWith(subtasks: updatedSubtasks);
                  await growthProvider.updateTask(updatedParentTask);
                },
                child: Icon(
                  subtask.isCompleted
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 20,
                  color: subtask.isCompleted
                      ? AppTheme.successColor
                      : Colors.grey.shade400,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Subtask Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtask Title - Tap to edit
                  GestureDetector(
                    onTap: () => _showSubtaskEditDialog(subtask, parentTask, growthProvider),
                    child: Text(
                      subtask.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: subtask.isCompleted
                            ? Colors.grey.shade500
                            : Colors.grey.shade800,
                        decoration: subtask.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),

                  // Subtask Date - Tap to edit
                  if (subtask.scheduledDate != null) ...[
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _showSubtaskEditDialog(subtask, parentTask, growthProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 10,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MMM d, y').format(subtask.scheduledDate!),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSubtaskEditDialog(
    GoalTask subtask,
    GoalTask parentTask,
    GrowthProvider growthProvider,
  ) async {
    final titleController = TextEditingController(text: subtask.title);
    DateTime? selectedDate = subtask.scheduledDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Edit Subtask', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Subtask Title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),

                  // Date picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            selectedDate != null
                                ? DateFormat('MMM d, y').format(selectedDate!)
                                : 'Set date (optional)',
                            style: TextStyle(
                              color: selectedDate != null ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          if (selectedDate != null)
                            IconButton(
                              icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade600),
                              onPressed: () => setState(() => selectedDate = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'title': titleController.text.trim(),
                    'date': selectedDate,
                  });
                },
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      final updatedSubtask = subtask.copyWith(
        title: result['title'] as String,
        scheduledDate: result['date'] as DateTime?,
      );
      final updatedSubtasks = parentTask.subtasks.map((st) {
        return st.id == subtask.id ? updatedSubtask : st;
      }).toList();
      final updatedParentTask = parentTask.copyWith(subtasks: updatedSubtasks);
      await growthProvider.updateTask(updatedParentTask);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Subtask updated'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showAddSubtaskDialog(
    GoalTask parentTask,
    GrowthProvider growthProvider,
  ) async {
    final titleController = TextEditingController();
    DateTime? selectedDate;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(Icons.add_task_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                const Text('Add Subtask', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Subtask Title',
                      hintText: 'e.g., Research competitors',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),

                  // Date picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            selectedDate != null
                                ? DateFormat('MMM d, y').format(selectedDate!)
                                : 'Set date (optional)',
                            style: TextStyle(
                              color: selectedDate != null ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          if (selectedDate != null)
                            IconButton(
                              icon: Icon(Icons.clear, size: 18, color: Colors.grey.shade600),
                              onPressed: () => setState(() => selectedDate = null),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Please enter a subtask title'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, {
                    'title': titleController.text.trim(),
                    'date': selectedDate,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      // Create new subtask
      final newSubtask = GoalTask(
        id: DateTime.now().millisecondsSinceEpoch,
        goalId: parentTask.goalId,
        title: result['title'] as String,
        description: '',
        scheduledDate: result['date'] as DateTime?,
        createdAt: DateTime.now(),
        priority: parentTask.priority,
      );

      // Add to parent task's subtasks
      final updatedSubtasks = [...parentTask.subtasks, newSubtask];
      final updatedParentTask = parentTask.copyWith(subtasks: updatedSubtasks);
      await growthProvider.updateTask(updatedParentTask);

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Subtask added'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }





  // Helper to build inline form (simplified)

}
