import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/growth_provider.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import '../../data/models/subtask.dart' show Task;
import '../../data/models/goal_task.dart';
import '../../data/models/reminder.dart' hide TimeOfDay;
import '../../core/services/privacy_gpt_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/premium_service.dart';
import 'roadmap_management_screen.dart';

/// Screen for planning and editing goal tasks with calendar view
class GoalPlanningScreen extends StatefulWidget {
  final int goalId;
  final String goalName;
  final List<Task> initialTasks;
  final Map<String, dynamic> timeline;

  const GoalPlanningScreen({
    super.key,
    required this.goalId,
    required this.goalName,
    required this.initialTasks,
    required this.timeline,
  });

  @override
  State<GoalPlanningScreen> createState() => _GoalPlanningScreenState();
}

class _GoalPlanningScreenState extends State<GoalPlanningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Task> _tasks = [];
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  late DateTime _deadline;
  Map<DateTime, List<GoalTask>> _scheduledTasks = {};
  // Map to store phaseId for each task (using task title+description as key)
  final Map<String, int?> _taskPhaseMap = {}; // "title|description" -> phaseId
  // Map to store selected date for each task (using task title+description as key)
  final Map<String, DateTime?> _taskDateMap = {}; // "title|description" -> selectedDate

  String _getTaskKey(Task task) => '${task.title}|${task.description}';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tasks = List.from(widget.initialTasks);
    _deadline = (widget.timeline['deadline'] as DateTime?) ??
        DateTime.now().add(const Duration(days: 30));
    
    // Load existing tasks from database
    _loadExistingTasks();
  }

  Future<void> _loadExistingTasks() async {
    try {
      final growthProvider = context.read<GrowthProvider>();
      final existingGoalTasks = growthProvider.getTasksForGoal(widget.goalId);
      
      // Convert GoalTask to Task model
      final existingTasks = existingGoalTasks.map((goalTask) {
        return Task(
          title: goalTask.title,
          description: goalTask.description,
          priority: goalTask.priority,
          frequency: goalTask.frequency,
          suggestedTime: goalTask.suggestedTime,
          suggestedLocation: goalTask.suggestedLocation,
          estimatedHours: goalTask.estimatedHours,
          isMilestone: goalTask.isMilestone,
          motivationAnchor: goalTask.motivationAnchor,
          reminderTimeType: null, // GoalTask doesn't have this
          reminderTime: null, // GoalTask doesn't have this
        );
      }).toList();
      
      // Merge with initial tasks, avoiding duplicates
      final existingTitles = _tasks.map((t) => t.title.toLowerCase()).toSet();
      final newTasks = existingTasks.where(
        (t) => !existingTitles.contains(t.title.toLowerCase()),
      ).toList();
      
      // Load phase IDs and dates from existing tasks
      for (var goalTask in existingGoalTasks) {
        final taskKey = '${goalTask.title}|${goalTask.description}';
        _taskPhaseMap[taskKey] = goalTask.phaseId;
        if (goalTask.scheduledDate != null) {
          _taskDateMap[taskKey] = DateTime(
            goalTask.scheduledDate!.year,
            goalTask.scheduledDate!.month,
            goalTask.scheduledDate!.day,
          );
        }
      }
      
      setState(() {
        _tasks.addAll(newTasks);
        _scheduleTasks();
      });
    } catch (e) {
      debugPrint('Error loading existing tasks: $e');
      // If loading fails, just schedule the initial tasks
      _scheduleTasks();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _scheduleTasks() {
    final now = DateTime.now();
    final daysUntilDeadline = _deadline.difference(now).inDays;
    
    // Get hours per day from timeline (default to 2 if not set)
    final hoursPerDay = (widget.timeline['hoursPerDay'] as num?)?.toDouble() ?? 2.0;
    
    if (_tasks.isEmpty) {
      _scheduledTasks.clear();
      setState(() {});
      return;
    }
    
    // For very short deadlines (1 day or less), schedule all tasks on the deadline day
    if (daysUntilDeadline <= 1) {
      _scheduledTasks.clear();
      final deadlineDate = DateTime(_deadline.year, _deadline.month, _deadline.day);
      
      for (var task in _tasks) {
        final phaseId = _taskPhaseMap[_getTaskKey(task)];
        // Use user-selected date if available, otherwise use deadline
        final userSelectedDate = _taskDateMap[_getTaskKey(task)];
        final taskDate = userSelectedDate != null
            ? DateTime(userSelectedDate.year, userSelectedDate.month, userSelectedDate.day)
            : deadlineDate;
        
        final goalTask = GoalTask(
          id: 0, // Will be assigned on save
          goalId: widget.goalId,
          title: task.title,
          description: task.description,
          priority: task.priority,
          estimatedHours: task.estimatedHours ?? 1.0,
          scheduledDate: taskDate,
          phaseId: phaseId,
          isCompleted: false,
          isMilestone: task.isMilestone,
          motivationAnchor: task.motivationAnchor,
          createdAt: DateTime.now(),
        );
        
        _scheduledTasks.putIfAbsent(taskDate, () => []).add(goalTask);
      }
      
      setState(() {});
      return;
    }
    
    // Calculate total estimated hours
    double totalHours = 0;
    for (var task in _tasks) {
      totalHours += task.estimatedHours ?? 1.0; // Default 1 hour if not specified
    }
    
    if (totalHours == 0) {
      totalHours = _tasks.length.toDouble(); // Fallback: 1 hour per task
    }
    
    // Calculate available hours (leave 20% buffer for flexibility)
    final availableHours = (daysUntilDeadline * hoursPerDay * 0.8);
    
    // Warn if total hours exceed available
    if (totalHours > availableHours) {
      debugPrint('⚠️ Warning: Total hours ($totalHours) exceed available ($availableHours). Tasks will be distributed but may be tight.');
    }
    
    _scheduledTasks.clear();
    
    // Sort by priority first (high priority tasks should be scheduled earlier)
    final sortedTasks = _sortTasksByPriority(_tasks);
    
    // Calculate cumulative hours for percentage-based distribution
    double cumulativeHours = 0.0;
    
    for (var task in sortedTasks) {
      final estimatedHours = task.estimatedHours ?? 1.0;
      
      // Check if user has selected a date for this task
      final userSelectedDate = _taskDateMap[_getTaskKey(task)];
      DateTime finalDate;
      
      if (userSelectedDate != null) {
        // Use user-selected date
        finalDate = DateTime(userSelectedDate.year, userSelectedDate.month, userSelectedDate.day);
      } else {
        // Auto-schedule based on timeline
        // Calculate what percentage of total hours this task represents
        final taskPercentage = estimatedHours / totalHours;
        
        // Calculate what percentage of the timeline this should occupy
        // Use cumulative hours to spread tasks across the timeline
        final timelinePosition = cumulativeHours / totalHours;
        
        // Calculate the target day based on timeline position
        // Leave 10% buffer at the end for final tasks
        final effectiveDays = (daysUntilDeadline * 0.9).ceil();
        final targetDayIndex = (timelinePosition * effectiveDays).floor();
        
        // Ensure we don't go beyond deadline
        final dayIndex = targetDayIndex.clamp(0, daysUntilDeadline - 1);
        
        // Calculate the target date
        var targetDate = now.add(Duration(days: dayIndex));
        
        // Ensure we don't schedule beyond deadline
        if (targetDate.isAfter(_deadline)) {
          targetDate = _deadline.subtract(const Duration(days: 1));
        }
        
        // For tasks that might exceed daily capacity, distribute across multiple days
        // But for now, schedule on the calculated day
        final dateKey = DateTime(targetDate.year, targetDate.month, targetDate.day);
        
        // Check if this day already has too many hours scheduled
        final existingHoursOnDay = _scheduledTasks[dateKey]?.fold<double>(
          0.0,
          (sum, t) => sum + (t.estimatedHours ?? 1.0),
        ) ?? 0.0;
        
        // If adding this task would exceed daily capacity, try to find a nearby day
        finalDate = dateKey;
        if (existingHoursOnDay + estimatedHours > hoursPerDay) {
          // Try to find a nearby day with available capacity
          bool found = false;
          for (int offset = 1; offset <= 3 && !found; offset++) {
            // Try days after
            final candidateDate = dateKey.add(Duration(days: offset));
            if (candidateDate.isBefore(_deadline)) {
              final candidateKey = DateTime(candidateDate.year, candidateDate.month, candidateDate.day);
              final candidateHours = _scheduledTasks[candidateKey]?.fold<double>(
                0.0,
                (sum, t) => sum + (t.estimatedHours ?? 1.0),
              ) ?? 0.0;
              
              if (candidateHours + estimatedHours <= hoursPerDay) {
                finalDate = candidateKey;
                found = true;
                break;
              }
            }
            
            // Try days before
            final candidateDateBefore = dateKey.subtract(Duration(days: offset));
            if (candidateDateBefore.isAfter(now) || candidateDateBefore.isAtSameMomentAs(now)) {
              final candidateKey = DateTime(candidateDateBefore.year, candidateDateBefore.month, candidateDateBefore.day);
              final candidateHours = _scheduledTasks[candidateKey]?.fold<double>(
                0.0,
                (sum, t) => sum + (t.estimatedHours ?? 1.0),
              ) ?? 0.0;
              
              if (candidateHours + estimatedHours <= hoursPerDay) {
                finalDate = candidateKey;
                found = true;
                break;
              }
            }
          }
        }
      }
      
      if (!_scheduledTasks.containsKey(finalDate)) {
        _scheduledTasks[finalDate] = [];
      }
      
      // Apply suggested time
      DateTime scheduledDateTime = finalDate;
      if (task.suggestedTime != 'any') {
        int hour = 9; // Default to 9 AM
        if (task.suggestedTime == 'morning') hour = 9;
        else if (task.suggestedTime == 'afternoon') hour = 14;
        else if (task.suggestedTime == 'evening') hour = 18;
        scheduledDateTime = DateTime(finalDate.year, finalDate.month, finalDate.day, hour);
      }
      
      // Find phaseId for this task
      final phaseId = _taskPhaseMap[_getTaskKey(task)];
      
      final goalTask = GoalTask(
        id: 0,
        goalId: widget.goalId,
        title: task.title,
        description: task.description,
        estimatedHours: task.estimatedHours,
        priority: task.priority,
        frequency: task.frequency,
        suggestedTime: task.suggestedTime,
        suggestedLocation: task.suggestedLocation,
        isMilestone: task.isMilestone,
        motivationAnchor: task.motivationAnchor,
        scheduledDate: scheduledDateTime,
        phaseId: phaseId,
        createdAt: DateTime.now(),
      );
      
      _scheduledTasks[finalDate]!.add(goalTask);
      
      // Update cumulative hours for next iteration (only for auto-scheduled tasks)
      if (userSelectedDate == null) {
        cumulativeHours += estimatedHours;
      }
    }
    
    debugPrint('📅 Scheduled ${_scheduledTasks.values.fold(0, (sum, list) => sum + list.length)} tasks across ${_scheduledTasks.keys.length} days (deadline: ${daysUntilDeadline} days away)');
    
    setState(() {});
  }

  /// Sort tasks by priority and complexity
  List<Task> _sortTasksByPriority(List<Task> tasks) {
    // Sort by priority: high -> medium -> low
    final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
    final sorted = List<Task>.from(tasks);
    sorted.sort((a, b) {
      final aPriority = priorityOrder[a.priority] ?? 1;
      final bPriority = priorityOrder[b.priority] ?? 1;
      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      // If same priority, sort by estimated hours (shorter tasks first for better distribution)
      final aHours = a.estimatedHours ?? 1.0;
      final bHours = b.estimatedHours ?? 1.0;
      return aHours.compareTo(bHours);
    });
    return sorted;
  }

  List<GoalTask> _getTasksForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _scheduledTasks[dateKey] ?? [];
  }

  Future<void> _saveAndSchedule() async {
    try {
      final growthProvider = context.read<GrowthProvider>();
      final reminderProvider = context.read<ReminderProvider>();
      
      // Save tasks and create reminders
      for (var dateEntry in _scheduledTasks.entries) {
        for (var goalTask in dateEntry.value) {
          // Save task
          await growthProvider.createTask(goalTask);
          debugPrint('  ✅ Saved task "${goalTask.title}"');
          
          // Create reminder for task, linked to goal
          // Use reminder time from task if available, otherwise use scheduled date
          DateTime? reminderTime = goalTask.scheduledDate;
          
          // If task has a reminder time preference, apply it to the scheduled date
          if (goalTask.scheduledDate != null) {
            // Find the corresponding Task to get reminder time preference
            final task = _tasks.firstWhere(
              (t) => t.title == goalTask.title,
              orElse: () => Task(title: '', description: ''),
            );
            
            if (task.reminderTime != null) {
              // Apply the reminder time to the scheduled date
              reminderTime = DateTime(
                goalTask.scheduledDate!.year,
                goalTask.scheduledDate!.month,
                goalTask.scheduledDate!.day,
                task.reminderTime!.hour,
                task.reminderTime!.minute,
              );
            }
          }
          
          final reminder = Reminder(
            text: goalTask.description,
            timeAt: reminderTime,
            priority: _getReminderPriority(goalTask.priority),
            linkedGoalId: widget.goalId, // Direct link to goal for categorization
          );
          debugPrint('📝 Creating reminder: "${reminder.text}" with linkedGoalId: ${widget.goalId}');
          await reminderProvider.createReminder(reminder);
          debugPrint('✅ Reminder created with ID: ${reminder.id}');
        }
      }
      
      // Reload growth data
      await growthProvider.loadGrowthData();
      // Also reload reminders to ensure they're up to date
      await reminderProvider.loadReminders();
      
      debugPrint('📊 Summary: Created ${_scheduledTasks.values.fold(0, (sum, list) => sum + list.length)} tasks and reminders');
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal planned! Tasks scheduled.'),
            backgroundColor: Colors.green,
          ),
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

  ReminderPriority _getReminderPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return ReminderPriority.high;
      case 'low':
        return ReminderPriority.low;
      default:
        return ReminderPriority.medium;
    }
  }

  Future<void> _addNewTask() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditTaskDialog(
        task: Task(
          title: '',
          description: '',
          priority: 'medium',
          frequency: 'one-time',
        ),
        goalId: widget.goalId,
        isNew: true,
      ),
    );
    
    if (result != null && (result['task'] as Task).title.isNotEmpty) {
      final task = result['task'] as Task;
      final phaseId = result['phaseId'] as int?;
      final selectedDate = result['selectedDate'] as DateTime?;
      setState(() {
        _tasks.add(task);
        _taskPhaseMap[_getTaskKey(task)] = phaseId;
        _taskDateMap[_getTaskKey(task)] = selectedDate;
        _scheduleTasks();
      });
    }
  }

  Future<void> _generateTasksWithAI() async {
    // Check premium status
    final premiumService = PremiumService();
    final isPremium = await premiumService.isPremium();
    
    if (!isPremium) {
      final upgrade = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.star, color: Colors.amber),
              SizedBox(width: 8),
              Text('Premium Feature'),
            ],
          ),
          content: const Text(
            'AI-powered task generation is a premium feature. Upgrade to unlock intelligent task suggestions.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement premium upgrade flow
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Premium upgrade coming soon! You can add tasks manually.'),
                  ),
                );
                Navigator.pop(context, false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
              child: const Text('Upgrade'),
            ),
          ],
        ),
      );
      if (upgrade != true) return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final gptService = PrivacyGptService();
      final goal = await context.read<GrowthProvider>().goals.firstWhere(
        (g) => g.id == widget.goalId,
      );

      // Generate additional tasks for the goal
      final roadmap = await gptService.generateDetailedRoadmap(
        goal.name,
        targetDeadline: goal.targetDeadline ?? DateTime.now().add(const Duration(days: 30)),
        hoursPerDay: goal.hoursPerDay ?? 2.0,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        if (roadmap != null && roadmap['tasks'] != null) {
          final newTasks = (roadmap['tasks'] as List)
              .map((s) => Task.fromMap(s as Map<String, dynamic>))
              .toList();

          // Filter out tasks that already exist
          final existingTitles = _tasks.map((t) => t.title.toLowerCase()).toSet();
          final uniqueNewTasks = newTasks.where(
            (t) => !existingTitles.contains(t.title.toLowerCase()),
          ).toList();

          if (uniqueNewTasks.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No new tasks generated. All suggested tasks already exist.'),
              ),
            );
            return;
          }

          setState(() {
            _tasks.addAll(uniqueNewTasks);
            _scheduleTasks();
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generated ${uniqueNewTasks.length} new task(s)'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to generate tasks. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${_tasks[index].title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final task = _tasks[index];
      setState(() {
        _taskPhaseMap.remove(_getTaskKey(task));
        _taskDateMap.remove(_getTaskKey(task));
        _tasks.removeAt(index);
        _scheduleTasks();
      });
    }
  }

  Future<void> _editTask(int index) async {
    final task = _tasks[index];
    final currentPhaseId = _taskPhaseMap[_getTaskKey(task)];
    final currentDate = _taskDateMap[_getTaskKey(task)];
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _EditTaskDialog(
        task: task,
        goalId: widget.goalId,
        initialPhaseId: currentPhaseId,
        initialDate: currentDate,
      ),
    );
    
    if (result != null) {
      final oldKey = _getTaskKey(task);
      final newTask = result['task'] as Task;
      final newPhaseId = result['phaseId'] as int?;
      final selectedDate = result['selectedDate'] as DateTime?;
      setState(() {
        _taskPhaseMap.remove(oldKey);
        _taskDateMap.remove(oldKey);
        _tasks[index] = newTask;
        _taskPhaseMap[_getTaskKey(newTask)] = newPhaseId;
        _taskDateMap[_getTaskKey(newTask)] = selectedDate;
        _scheduleTasks();
      });
    }
  }

  Future<void> _editTaskTime(int index) async {
    final task = _tasks[index];
    
    // Find current scheduled date
    DateTime? currentDate;
    for (var entry in _scheduledTasks.entries) {
      final found = entry.value.firstWhere(
        (t) => t.title == task.title && t.description == task.description,
        orElse: () => GoalTask(
          id: 0,
          goalId: widget.goalId,
          title: '',
          description: '',
          createdAt: DateTime.now(),
        ),
      );
      if (found.title.isNotEmpty) {
        currentDate = found.scheduledDate;
        break;
      }
    }
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: _deadline,
      builder: (context, child) {
        // Use the full app theme, just ensure proper colors for date picker
        return Theme(
          data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
          child: child!,
        );
      },
    );
    
    if (selectedDate != null) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentDate ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: AppTheme.primaryColor,
                onPrimary: Colors.white,
                surface: theme.brightness == Brightness.dark
                    ? AppTheme.darkSurface
                    : AppTheme.surfaceColor,
                onSurface: theme.brightness == Brightness.dark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.textPrimary,
              ),
              dialogBackgroundColor: theme.brightness == Brightness.dark
                  ? AppTheme.darkSurface
                  : AppTheme.surfaceColor,
            ),
            child: child!,
          );
        },
      );
      
      if (selectedTime != null) {
        final newDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );
        
        setState(() {
          // Update scheduled date in _scheduledTasks
          final dateKey = DateTime(newDateTime.year, newDateTime.month, newDateTime.day);
          
          // Remove from old date
          for (var entry in _scheduledTasks.entries) {
            entry.value.removeWhere(
              (t) => t.title == task.title && t.description == task.description,
            );
          }
          
          // Add to new date
          if (!_scheduledTasks.containsKey(dateKey)) {
            _scheduledTasks[dateKey] = [];
          }
          
          // Find phaseId for this task
          final phaseId = _taskPhaseMap[_getTaskKey(task)];
          
          final goalTask = GoalTask(
            id: 0,
            goalId: widget.goalId,
            title: task.title,
            description: task.description,
            estimatedHours: task.estimatedHours,
            priority: task.priority,
            frequency: task.frequency,
            suggestedTime: task.suggestedTime,
            suggestedLocation: task.suggestedLocation,
            isMilestone: task.isMilestone,
            motivationAnchor: task.motivationAnchor,
            scheduledDate: newDateTime,
            phaseId: phaseId,
            createdAt: DateTime.now(),
          );
          
          _scheduledTasks[dateKey]!.add(goalTask);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.goalName),
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add Task',
            onSelected: (value) {
              if (value == 'manual') {
                _addNewTask();
              } else if (value == 'ai') {
                _generateTasksWithAI();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manual',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Add Manually'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'ai',
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 20, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('Generate with AI'),
                    SizedBox(width: 4),
                    Icon(Icons.star, size: 16, color: Colors.amber),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Tasks', icon: Icon(Icons.list_rounded)),
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_today_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildCalendarTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveAndSchedule,
        label: const Text('Save & Schedule'),
        icon: const Icon(Icons.check_rounded),
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 120,
              color: AppTheme.primaryColor.withOpacity(0.3),
            )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutCubic)
              .fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No tasks yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
            )
              .animate()
              .fadeIn(delay: 400.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 600.ms),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Create your first task to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            )
              .animate()
              .fadeIn(delay: 600.ms, duration: 600.ms)
              .slideY(begin: 0.2, end: 0, delay: 600.ms, duration: 600.ms),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: _addNewTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                elevation: 4,
              ),
            )
              .animate()
              .scale(delay: 800.ms, duration: 400.ms, curve: Curves.easeOutCubic)
              .fadeIn(delay: 800.ms, duration: 400.ms)
              .shimmer(
                delay: 1200.ms,
                duration: 1500.ms,
                color: Colors.white.withOpacity(0.3),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        // Find scheduled date for this task
        DateTime? scheduledDate;
        for (var entry in _scheduledTasks.entries) {
          final found = entry.value.firstWhere(
            (t) => t.title == task.title && t.description == task.description,
            orElse: () => GoalTask(
              id: 0,
              goalId: widget.goalId,
              title: '',
              description: '',
              createdAt: DateTime.now(),
            ),
          );
          if (found.title.isNotEmpty) {
            scheduledDate = found.scheduledDate;
            break;
          }
        }
        
        return ModernSmartCard(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryLight,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editTask(index);
                      } else if (value == 'time') {
                        _editTaskTime(index);
                      } else if (value == 'delete') {
                        _deleteTask(index);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'time',
                        child: Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Time'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSM,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.priority,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.estimatedHours != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSM,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.estimatedHours!.toStringAsFixed(1)}h',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (scheduledDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSM,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                        border: Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM d, y').format(scheduledDate),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (task.isMilestone)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSM,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryLight,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Milestone',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        )
          .animate()
          .fadeIn(delay: (index * 100).ms, duration: 400.ms)
          .slideY(
            begin: 0.2,
            end: 0,
            delay: (index * 100).ms,
            duration: 400.ms,
            curve: Curves.easeOutCubic,
          );
      },
    );
  }

  Widget _buildCalendarTab() {
    return Column(
      children: [
        // Simple calendar view using a custom implementation
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(
                          _focusedDay.year,
                          _focusedDay.month - 1,
                          _focusedDay.day,
                        );
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_focusedDay),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime(
                          _focusedDay.year,
                          _focusedDay.month + 1,
                          _focusedDay.day,
                        );
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMD),
              _buildCalendarGrid(),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            itemCount: _getTasksForDay(_selectedDay).length,
            itemBuilder: (context, index) {
              final task = _getTasksForDay(_selectedDay)[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text(task.description),
                  trailing: task.isMilestone
                      ? Icon(Icons.flag_rounded, color: AppTheme.primaryColor)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    final weeks = <List<DateTime>>[];
    var currentWeek = <DateTime>[];

    // Add empty cells for days before the first day of the month
    for (var i = 1; i < firstWeekday; i++) {
      currentWeek.add(DateTime(0));
    }

    // Add all days of the month
    for (var day = 1; day <= daysInMonth; day++) {
      currentWeek.add(DateTime(_focusedDay.year, _focusedDay.month, day));
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = <DateTime>[];
      }
    }

    // Add remaining empty cells
    while (currentWeek.length < 7 && currentWeek.isNotEmpty) {
      currentWeek.add(DateTime(0));
    }
    if (currentWeek.isNotEmpty) {
      weeks.add(currentWeek);
    }

    return Column(
      children: [
        // Weekday headers
        Row(
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppTheme.spacingSM),
        // Calendar days
        ...weeks.map((week) => Row(
              children: week.map((day) {
                if (day.year == 0) {
                  return Expanded(child: Container());
                }

                final isSelected = day.year == _selectedDay.year &&
                    day.month == _selectedDay.month &&
                    day.day == _selectedDay.day;
                final isToday = day.year == DateTime.now().year &&
                    day.month == DateTime.now().month &&
                    day.day == DateTime.now().day;
                final hasTasks = _getTasksForDay(day).isNotEmpty;
                final dateKey = DateTime(day.year, day.month, day.day);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              border: isToday && !isSelected
                                  ? Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.8),
                                width: 1.4,
                              )
                                  : null,
                            ),
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (hasTasks)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.primaryColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            )),
      ],
    );
  }
}

class _EditTaskDialog extends StatefulWidget {
  final Task task;
  final bool isNew;
  final int goalId;
  final int? initialPhaseId;
  final DateTime? initialDate;

  const _EditTaskDialog({
    required this.task,
    required this.goalId,
    this.isNew = false,
    this.initialPhaseId,
    this.initialDate,
  });

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _hoursController;
  final stt.SpeechToText _speech = stt.SpeechToText();
  String _priority = 'medium';
  String _frequency = 'one-time';
  String? _reminderTimeType;
  TimeOfDay? _reminderTime;
  int? _selectedPhaseId;
  DateTime? _selectedDate;
  bool _isListeningTitle = false;
  bool _isListeningDescription = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _hoursController = TextEditingController(
      text: widget.task.estimatedHours?.toStringAsFixed(1) ?? '',
    );
    _priority = widget.task.priority;
    _frequency = widget.task.frequency;
    _reminderTimeType = widget.task.reminderTimeType;
    _reminderTime = widget.task.reminderTime;
    _selectedPhaseId = widget.initialPhaseId;
    // Initialize selected date from widget if editing, otherwise null
    _selectedDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _transcribeVoiceInput(
    TextEditingController controller,
    bool isTitle,
  ) async {
    final permissionService = PermissionService();
    final hasPermission = await permissionService.requestMicrophonePermission();
    
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      setState(() {
        if (isTitle) {
          _isListeningTitle = false;
        } else {
          _isListeningDescription = false;
        }
      });
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
      setState(() {
        if (isTitle) {
          _isListeningTitle = false;
        } else {
          _isListeningDescription = false;
        }
      });
      return;
    }

    bool isFinal = false;
    await _speech.listen(
      onResult: (result) {
        setState(() {
          controller.text = result.recognizedWords;
          if (result.finalResult) {
            isFinal = true;
            _speech.stop();
            if (isTitle) {
              _isListeningTitle = false;
            } else {
              _isListeningDescription = false;
            }
          }
        });
      },
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );

    // Auto-stop after 5 seconds if no final result
    await Future.delayed(const Duration(seconds: 5));
    if (!isFinal) {
      await _speech.stop();
      setState(() {
        if (isTitle) {
          _isListeningTitle = false;
        } else {
          _isListeningDescription = false;
        }
      });
    }
  }

  Future<void> _selectReminderTime() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('When should you be reminded?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.wb_sunny, color: Colors.orange),
              title: const Text('Morning (9 AM)'),
              onTap: () => Navigator.pop(context, 'morning'),
            ),
            ListTile(
              leading: const Icon(Icons.wb_twilight, color: Colors.blue),
              title: const Text('Afternoon (2 PM)'),
              onTap: () => Navigator.pop(context, 'afternoon'),
            ),
            ListTile(
              leading: const Icon(Icons.nightlight, color: Colors.purple),
              title: const Text('Evening (6 PM)'),
              onTap: () => Navigator.pop(context, 'evening'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('Specific Time'),
              onTap: () => Navigator.pop(context, 'specific'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Custom Time Range'),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('No Reminder'),
              onTap: () => Navigator.pop(context, 'none'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == 'none') {
      setState(() {
        _reminderTimeType = null;
        _reminderTime = null;
      });
      return;
    }

    if (result == 'specific' || result == 'custom') {
      final time = await showTimePicker(
        context: context,
        initialTime: _reminderTime ?? TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _reminderTimeType = result;
          _reminderTime = time;
        });
      }
    } else {
      // Set default times for morning/afternoon/evening
      TimeOfDay defaultTime;
      switch (result) {
        case 'morning':
          defaultTime = const TimeOfDay(hour: 9, minute: 0);
          break;
        case 'afternoon':
          defaultTime = const TimeOfDay(hour: 14, minute: 0);
          break;
        case 'evening':
          defaultTime = const TimeOfDay(hour: 18, minute: 0);
          break;
        default:
          return;
      }
      setState(() {
        _reminderTimeType = result;
        _reminderTime = defaultTime;
      });
    }
  }

  String _getReminderTimeDisplay() {
    if (_reminderTimeType == null) return 'No reminder';
    switch (_reminderTimeType) {
      case 'morning':
        return 'Morning (9:00 AM)';
      case 'afternoon':
        return 'Afternoon (2:00 PM)';
      case 'evening':
        return 'Evening (6:00 PM)';
      case 'specific':
      case 'custom':
        if (_reminderTime != null) {
          return '${_reminderTime!.format(context)}';
        }
        return 'Custom time';
      default:
        return 'No reminder';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Add New Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title *',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isListeningTitle ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListeningTitle ? Colors.red : null,
                  ),
                  onPressed: () async {
                    setState(() => _isListeningTitle = true);
                    await _transcribeVoiceInput(_titleController, true);
                  },
                  tooltip: 'Voice input',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                suffixIcon: IconButton(
                  icon: Icon(
                    _isListeningDescription ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isListeningDescription ? Colors.red : null,
                  ),
                  onPressed: () async {
                    setState(() => _isListeningDescription = true);
                    await _transcribeVoiceInput(_descriptionController, false);
                  },
                  tooltip: 'Voice input',
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // Date picker
            InkWell(
              onTap: () async {
                final theme = Theme.of(context);
                final isDark = theme.brightness == Brightness.dark;
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                  builder: (context, child) {
                    // Use the full app theme, just ensure proper colors for date picker
                    return Theme(
                      data: isDark ? AppTheme.darkTheme : AppTheme.lightTheme,
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Task Date *',
                  suffixIcon: const Icon(Icons.calendar_today_rounded),
                ),
                child: Text(
                  _selectedDate != null
                      ? DateFormat('MMM d, y').format(_selectedDate!)
                      : 'Select a date',
                  style: TextStyle(
                    color: _selectedDate != null
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _hoursController,
              decoration: const InputDecoration(labelText: 'Estimated Hours'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: ['high', 'medium', 'low']
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (value) => setState(() => _priority = value!),
            ),
            const SizedBox(height: 16),
            // Phase selection
            Consumer<GrowthProvider>(
              builder: (context, growthProvider, child) {
                final phases = growthProvider.getPhasesForGoal(widget.goalId);
                if (phases.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phase',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No phases created yet. Create phases in Roadmap tab.',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  );
                }
                return DropdownButtonFormField<int?>(
                  value: _selectedPhaseId,
                  decoration: const InputDecoration(
                    labelText: 'Phase',
                    hintText: 'Select a phase (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No Phase'),
                    ),
                    ...phases.map((phase) => DropdownMenuItem<int?>(
                      value: phase.id,
                      child: Text(phase.name),
                    )),
                  ],
                  onChanged: (value) => setState(() => _selectedPhaseId = value),
                );
              },
            ),
            const SizedBox(height: 16),
            // Reminder time selection
            InkWell(
              onTap: _selectReminderTime,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Reminder Time',
                  suffixIcon: Icon(Icons.access_time),
                ),
                child: Text(_getReminderTimeDisplay()),
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
            if (_titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a task title')),
              );
              return;
            }
            if (_selectedDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select a task date')),
              );
              return;
            }
            Navigator.pop(
              context,
              {
                'task': widget.task.copyWith(
                  title: _titleController.text.trim(),
                  description: _descriptionController.text.trim(),
                  estimatedHours: double.tryParse(_hoursController.text),
                  priority: _priority,
                  frequency: _frequency,
                  reminderTimeType: _reminderTimeType,
                  reminderTime: _reminderTime,
                ),
                'phaseId': _selectedPhaseId,
                'selectedDate': _selectedDate,
              },
            );
          },
          child: Text(widget.isNew ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

