import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/growth_provider.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';
import '../../data/models/goal_roadmap.dart';
import '../../data/models/subtask.dart' show Task;
import '../../data/models/reminder.dart';

/// Screen for reviewing AI-generated goal roadmap and scheduling tasks
class GoalRoadmapScreen extends StatefulWidget {
  final Map<String, dynamic> roadmapData;

  const GoalRoadmapScreen({super.key, required this.roadmapData});

  @override
  State<GoalRoadmapScreen> createState() => _GoalRoadmapScreenState();
}

class _GoalRoadmapScreenState extends State<GoalRoadmapScreen> {
  final List<Task> _tasks = [];
  String _goalName = '';
  DateTime? _targetDeadline;
  double? _hoursPerDay;
  int? _totalEstimatedHours;
  List<String> _weeklyGoals = [];
  List<String> _riskAlerts = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _parseRoadmap();
  }

  void _parseRoadmap() {
    final roadmap = GoalRoadmap.fromGptResponse(widget.roadmapData);
    _goalName = roadmap.goalName;
    _tasks.addAll(roadmap.tasks);
    _targetDeadline = roadmap.targetDeadline;
    _hoursPerDay = roadmap.hoursPerDay;
    _totalEstimatedHours = roadmap.totalEstimatedHours;
    _weeklyGoals = roadmap.weeklyGoals;
    _riskAlerts = roadmap.riskAlerts;
  }

  Future<void> _createGoalAndSchedule() async {
    if (_isCreating) return;

    setState(() => _isCreating = true);

    try {
      final growthProvider = context.read<GrowthProvider>();
      final reminderProvider = context.read<ReminderProvider>();

      // 1. Create goal with deadline and capacity
      final goalId = await growthProvider.createGoal(
        _goalName,
        targetDeadline: _targetDeadline,
        hoursPerDay: _hoursPerDay,
        totalEstimatedHours: _totalEstimatedHours,
      );

      // 2. Schedule reminders based on capacity and deadline
      final scheduledReminders = _scheduleRemindersBasedOnCapacity(
        _tasks,
        goalId,
        _targetDeadline ?? DateTime.now().add(const Duration(days: 30)),
        _hoursPerDay ?? 2.0,
      );

      for (var reminderData in scheduledReminders) {
        await reminderProvider.createReminder(reminderData['reminder'] as Reminder);
      }

      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal created! Reminders scheduled.'),
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
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  /// Schedule reminders based on capacity and deadline
  List<Map<String, dynamic>> _scheduleRemindersBasedOnCapacity(
    List<Task> tasks,
    int goalId,
    DateTime deadline,
    double hoursPerDay,
  ) {
    final scheduledReminders = <Map<String, dynamic>>[];
    final now = DateTime.now();
    final daysUntilDeadline = deadline.difference(now).inDays;
    
    // Sort tasks by priority and dependencies
    final sortedTasks = _sortTasksByDependencies(tasks);
    
    // Distribute tasks across timeline
    var currentDate = DateTime(now.year, now.month, now.day);
    var dailyHoursUsed = 0.0;
    var dayIndex = 0;
    
    for (var i = 0; i < sortedTasks.length; i++) {
      final task = sortedTasks[i];
      final estimatedHours = task.estimatedHours ?? 1.0;
      
      // Check if we need to move to next day
      if (dailyHoursUsed + estimatedHours > hoursPerDay && dailyHoursUsed > 0) {
        dayIndex++;
        dailyHoursUsed = 0.0;
        currentDate = now.add(Duration(days: dayIndex));
      }
      
      // Don't schedule beyond deadline
      if (dayIndex >= daysUntilDeadline) {
        break;
      }
      
      // Determine time based on suggested time
      final timeAt = _getTimeForSuggestedTime(task.suggestedTime, currentDate);
      
      // Determine frequency and scheduling
      DateTime? reminderTime;
      int? repeatInterval;
      String? repeatUnit;
      
      if (task.frequency == 'daily') {
        repeatInterval = 1;
        repeatUnit = 'days';
        reminderTime = timeAt;
      } else if (task.frequency == 'weekly') {
        repeatInterval = 1;
        repeatUnit = 'weeks';
        reminderTime = timeAt;
      } else if (task.frequency == 'monthly') {
        repeatInterval = 1;
        repeatUnit = 'months';
        reminderTime = timeAt;
      } else {
        // One-time: schedule at calculated time
        reminderTime = timeAt;
      }
      
      // Create reminder
      final reminder = Reminder(
        text: task.description,
        timeAt: reminderTime,
        repeatInterval: repeatInterval,
        repeatUnit: repeatUnit,
        priority: _getPriorityFromString(task.priority),
        linkedGoalId: goalId,
      );
      
      scheduledReminders.add({
        'reminder': reminder,
        'task': task,
      });
      
      dailyHoursUsed += estimatedHours;
    }
    
    return scheduledReminders;
  }

  /// Sort tasks respecting dependencies
  List<Task> _sortTasksByDependencies(List<Task> tasks) {
    final sorted = <Task>[];
    final added = <String>{};
    
    // Add tasks with no dependencies first
    for (var task in tasks) {
      if (task.dependencies.isEmpty) {
        sorted.add(task);
        added.add(task.title);
      }
    }
    
    // Add dependent tasks
    var changed = true;
    while (changed && sorted.length < tasks.length) {
      changed = false;
      for (var task in tasks) {
        if (!added.contains(task.title)) {
          final allDepsMet = task.dependencies.every((dep) => added.contains(dep));
          if (allDepsMet) {
            sorted.add(task);
            added.add(task.title);
            changed = true;
          }
        }
      }
    }
    
    // Add any remaining tasks
    for (var task in tasks) {
      if (!added.contains(task.title)) {
        sorted.add(task);
      }
    }
    
    return sorted;
  }

  DateTime _getTimeForSuggestedTime(String suggestedTime, DateTime baseDate) {
    switch (suggestedTime.toLowerCase()) {
      case 'morning':
        return DateTime(baseDate.year, baseDate.month, baseDate.day, 9, 0);
      case 'afternoon':
        return DateTime(baseDate.year, baseDate.month, baseDate.day, 14, 0);
      case 'evening':
        return DateTime(baseDate.year, baseDate.month, baseDate.day, 18, 0);
      default:
        return DateTime(baseDate.year, baseDate.month, baseDate.day, 10, 0);
    }
  }

  ReminderPriority _getPriorityFromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return ReminderPriority.high;
      case 'low':
        return ReminderPriority.low;
      default:
        return ReminderPriority.medium;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Goal Roadmap'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                          Icon(
                            Icons.flag_rounded,
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            _goalName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          // Execution plan summary
                          if (_targetDeadline != null || _hoursPerDay != null || _totalEstimatedHours != null)
                            Container(
                              padding: const EdgeInsets.all(AppTheme.spacingMD),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                              child: Column(
                                children: [
                                  if (_targetDeadline != null)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Deadline: ${_targetDeadline!.toString().split(' ')[0]}',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (_hoursPerDay != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Capacity: $_hoursPerDay hours/day',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_totalEstimatedHours != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.timer_rounded, size: 16, color: AppTheme.primaryColor),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Total: ~$_totalEstimatedHours hours',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
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
                            '${_tasks.length} tasks • ${_weeklyGoals.length} weekly goals',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Weekly Goals
                  if (_weeklyGoals.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingLG),
                    Text(
                      'Weekly Goals',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    ..._weeklyGoals.map((goal) => Card(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        side: BorderSide(color: AppTheme.borderColor, width: 1),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flag_rounded,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          goal,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )),
                  ],

                  // Risk Alerts
                  if (_riskAlerts.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingLG),
                    Text(
                      'Risk Alerts',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    ..._riskAlerts.map((alert) => Card(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        side: BorderSide(color: Colors.orange.withOpacity(0.5), width: 1),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.warning_rounded,
                          color: Colors.orange,
                          size: 24,
                        ),
                        title: Text(
                          alert,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    )),
                  ],

                  const SizedBox(height: AppTheme.spacingLG),

                  // Tasks
                  Text(
                    'Tasks',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),

                  ..._tasks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final task = entry.value;
                    return _buildTaskCard(context, index + 1, task);
                  }),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                top: BorderSide(color: AppTheme.borderColor, width: 1),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createGoalAndSchedule,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                      child: _isCreating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create Goal & Schedule Tasks'),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  TextButton(
                    onPressed: _isCreating ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, int index, Task task) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: BorderSide(
          color: task.isMilestone ? AppTheme.primaryColor : AppTheme.borderColor,
          width: task.isMilestone ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: task.isMilestone
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: task.isMilestone
                        ? Icon(
                            Icons.flag_rounded,
                            color: Colors.white,
                            size: 18,
                          )
                        : Text(
                            '$index',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
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
                            ),
                      ),
                      if (task.isMilestone)
                        Text(
                          'Milestone',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              task.description,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            if (task.motivationAnchor != null) ...[
              const SizedBox(height: AppTheme.spacingSM),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.motivationAnchor!,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spacingSM),
            Wrap(
              spacing: AppTheme.spacingSM,
              runSpacing: AppTheme.spacingSM,
              children: [
                _buildChip('${task.frequency}ly', Icons.repeat_rounded),
                _buildChip(task.suggestedTime, Icons.access_time_rounded),
                _buildChip(task.priority, Icons.flag_rounded),
                if (task.estimatedHours != null)
                  _buildChip('${task.estimatedHours!.toStringAsFixed(1)}h', Icons.timer_rounded),
                if (task.dependencies.isNotEmpty)
                  _buildChip('${task.dependencies.length} deps', Icons.link_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSM,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

