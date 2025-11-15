import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../providers/reminder_provider.dart';
import '../theme/app_theme.dart';
import '../../data/models/subtask.dart';
import '../../data/models/goal_subtask.dart';
import '../../data/models/reminder.dart' hide TimeOfDay;
import '../../core/services/privacy_gpt_service.dart';

/// Screen for planning and editing goal subtasks with calendar view
class GoalPlanningScreen extends StatefulWidget {
  final int goalId;
  final String goalName;
  final List<Subtask> initialSubtasks;
  final Map<String, dynamic> timeline;

  const GoalPlanningScreen({
    super.key,
    required this.goalId,
    required this.goalName,
    required this.initialSubtasks,
    required this.timeline,
  });

  @override
  State<GoalPlanningScreen> createState() => _GoalPlanningScreenState();
}

class _GoalPlanningScreenState extends State<GoalPlanningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Subtask> _subtasks = [];
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  late DateTime _deadline;
  Map<DateTime, List<GoalSubtask>> _scheduledSubtasks = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _subtasks = List.from(widget.initialSubtasks);
    _deadline = (widget.timeline['deadline'] as DateTime?) ??
        DateTime.now().add(const Duration(days: 30));
    
    // Schedule subtasks across timeline
    _scheduleSubtasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _scheduleSubtasks() {
    final daysUntilDeadline = _deadline.difference(DateTime.now()).inDays;
    final subtasksPerDay = (_subtasks.length / daysUntilDeadline).ceil();
    
    var currentDate = DateTime.now();
    var subtaskIndex = 0;
    
    _scheduledSubtasks.clear();
    
    for (var subtask in _subtasks) {
      if (subtaskIndex >= daysUntilDeadline) break;
      
      final date = currentDate.add(Duration(days: subtaskIndex ~/ subtasksPerDay));
      final dateKey = DateTime(date.year, date.month, date.day);
      
      if (!_scheduledSubtasks.containsKey(dateKey)) {
        _scheduledSubtasks[dateKey] = [];
      }
      
      // Convert Subtask to GoalSubtask for display
      // Use suggested time to set a specific time of day
      DateTime scheduledDateTime = dateKey;
      if (subtask.suggestedTime != 'any') {
        int hour = 9; // Default to 9 AM
        if (subtask.suggestedTime == 'morning') hour = 9;
        else if (subtask.suggestedTime == 'afternoon') hour = 14;
        else if (subtask.suggestedTime == 'evening') hour = 18;
        scheduledDateTime = DateTime(dateKey.year, dateKey.month, dateKey.day, hour);
      }
      
      final goalSubtask = GoalSubtask(
        id: 0,
        goalId: widget.goalId,
        title: subtask.title,
        description: subtask.description,
        estimatedHours: subtask.estimatedHours,
        priority: subtask.priority,
        frequency: subtask.frequency,
        suggestedTime: subtask.suggestedTime,
        suggestedLocation: subtask.suggestedLocation,
        isMilestone: subtask.isMilestone,
        motivationAnchor: subtask.motivationAnchor,
        scheduledDate: scheduledDateTime,
        createdAt: DateTime.now(),
      );
      
      _scheduledSubtasks[dateKey]!.add(goalSubtask);
      subtaskIndex++;
    }
    
    setState(() {});
  }

  List<GoalSubtask> _getSubtasksForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _scheduledSubtasks[dateKey] ?? [];
  }

  Future<void> _saveAndSchedule() async {
    try {
      final growthProvider = context.read<GrowthProvider>();
      final reminderProvider = context.read<ReminderProvider>();
      
      // Create a map to track skills by subtask title (to avoid duplicates)
      final skillMap = <String, int>{};
      
      // Save all subtasks to database and create/find skills
      for (var dateEntry in _scheduledSubtasks.entries) {
        for (var subtask in dateEntry.value) {
          // Save subtask to database
          await growthProvider.createSubtask(subtask);
          
          // Create or find skill for this subtask
          int? skillId = skillMap[subtask.title];
          if (skillId == null) {
            debugPrint('🔍 Looking for skill: "${subtask.title}" for goalId: ${widget.goalId}');
            
            // Ensure goalId is valid
            if (widget.goalId <= 0) {
              debugPrint('❌ Invalid goalId: ${widget.goalId}');
              throw Exception('Invalid goalId: ${widget.goalId}');
            }
            
            // Check if skill already exists for this goal
            final existingSkills = growthProvider.getSkillsForGoal(widget.goalId);
            debugPrint('  Found ${existingSkills.length} existing skills for this goal');
            
            final matchingSkills = existingSkills.where(
              (s) => s.name == subtask.title,
            );
            
            if (matchingSkills.isNotEmpty) {
              skillId = matchingSkills.first.id;
              debugPrint('  ✅ Found existing skill: ${matchingSkills.first.name} (id: $skillId)');
            } else {
              // Create new skill
              debugPrint('  ➕ Creating new skill: "${subtask.title}" for goalId: ${widget.goalId}');
              skillId = await growthProvider.createSkill(
                subtask.title,
                goalId: widget.goalId,
              );
              debugPrint('  ✅ Created skill with id: $skillId');
            }
            skillMap[subtask.title] = skillId;
          } else {
            debugPrint('  ♻️ Reusing skill from cache: "${subtask.title}" (id: $skillId)');
          }
          
          // Create reminder for subtask, linked to skill and goal
          final reminder = Reminder(
            text: subtask.description,
            timeAt: subtask.scheduledDate,
            priority: _getReminderPriority(subtask.priority),
            linkedSkillId: skillId,
            linkedGoalId: widget.goalId, // Direct link to goal for categorization
          );
          debugPrint('📝 Creating reminder: "${reminder.text}" with linkedSkillId: $skillId, linkedGoalId: ${widget.goalId}');
          await reminderProvider.createReminder(reminder);
          debugPrint('✅ Reminder created with ID: ${reminder.id}');
        }
      }
      
      // Reload growth data to refresh skills
      await growthProvider.loadGrowthData();
      // Also reload reminders to ensure they're up to date
      await reminderProvider.loadReminders();
      
      debugPrint('📊 Summary: Created ${skillMap.length} skills, ${_scheduledSubtasks.values.fold(0, (sum, list) => sum + list.length)} reminders');
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal planned! Subtasks scheduled.'),
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

  Future<void> _addNewSubtask() async {
    final result = await showDialog<Subtask>(
      context: context,
      builder: (context) => _EditSubtaskDialog(
        subtask: Subtask(
          title: '',
          description: '',
          priority: 'medium',
          frequency: 'one-time',
        ),
        isNew: true,
      ),
    );
    
    if (result != null && result.title.isNotEmpty) {
      setState(() {
        _subtasks.add(result);
        _scheduleSubtasks();
      });
    }
  }

  Future<void> _deleteSubtask(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${_subtasks[index].title}"?'),
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
      setState(() {
        _subtasks.removeAt(index);
        _scheduleSubtasks();
      });
    }
  }

  Future<void> _editSubtask(int index) async {
    final subtask = _subtasks[index];
    final result = await showDialog<Subtask>(
      context: context,
      builder: (context) => _EditSubtaskDialog(subtask: subtask),
    );
    
    if (result != null) {
      setState(() {
        _subtasks[index] = result;
        _scheduleSubtasks();
      });
    }
  }

  Future<void> _editSubtaskTime(int index) async {
    final subtask = _subtasks[index];
    
    // Find current scheduled date
    DateTime? currentDate;
    for (var entry in _scheduledSubtasks.entries) {
      final found = entry.value.firstWhere(
        (s) => s.title == subtask.title && s.description == subtask.description,
        orElse: () => GoalSubtask(
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
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: _deadline,
    );
    
    if (selectedDate != null) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(currentDate ?? DateTime.now()),
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
          // Update scheduled date in _scheduledSubtasks
          final dateKey = DateTime(newDateTime.year, newDateTime.month, newDateTime.day);
          
          // Remove from old date
          for (var entry in _scheduledSubtasks.entries) {
            entry.value.removeWhere(
              (s) => s.title == subtask.title && s.description == subtask.description,
            );
          }
          
          // Add to new date
          if (!_scheduledSubtasks.containsKey(dateKey)) {
            _scheduledSubtasks[dateKey] = [];
          }
          
          final goalSubtask = GoalSubtask(
            id: 0,
            goalId: widget.goalId,
            title: subtask.title,
            description: subtask.description,
            estimatedHours: subtask.estimatedHours,
            priority: subtask.priority,
            frequency: subtask.frequency,
            suggestedTime: subtask.suggestedTime,
            suggestedLocation: subtask.suggestedLocation,
            isMilestone: subtask.isMilestone,
            motivationAnchor: subtask.motivationAnchor,
            scheduledDate: newDateTime,
            createdAt: DateTime.now(),
          );
          
          _scheduledSubtasks[dateKey]!.add(goalSubtask);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.goalName),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _addNewSubtask,
            tooltip: 'Add Task',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Subtasks', icon: Icon(Icons.list_rounded)),
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_today_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubtasksTab(),
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

  Widget _buildSubtasksTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: _subtasks.length,
      itemBuilder: (context, index) {
        final subtask = _subtasks[index];
        // Find scheduled date for this subtask
        DateTime? scheduledDate;
        for (var entry in _scheduledSubtasks.entries) {
          final found = entry.value.firstWhere(
            (s) => s.title == subtask.title && s.description == subtask.description,
            orElse: () => GoalSubtask(
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
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Text(
                '${index + 1}',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
            title: Text(
              subtask.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtask.description),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(subtask.priority),
                      avatar: const Icon(Icons.flag_rounded, size: 16),
                    ),
                    if (subtask.estimatedHours != null)
                      Chip(
                        label: Text('${subtask.estimatedHours!.toStringAsFixed(1)}h'),
                        avatar: const Icon(Icons.timer_rounded, size: 16),
                      ),
                    if (scheduledDate != null)
                      Chip(
                        label: Text(
                          DateFormat('MMM d, y').format(scheduledDate),
                          style: const TextStyle(fontSize: 11),
                        ),
                        avatar: const Icon(Icons.calendar_today_rounded, size: 16),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.access_time_rounded, size: 20),
                  onPressed: () => _editSubtaskTime(index),
                  tooltip: 'Edit Time',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  onPressed: () => _editSubtask(index),
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_rounded, size: 20),
                  color: Colors.red,
                  onPressed: () => _deleteSubtask(index),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
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
            itemCount: _getSubtasksForDay(_selectedDay).length,
            itemBuilder: (context, index) {
              final subtask = _getSubtasksForDay(_selectedDay)[index];
              return Card(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: ListTile(
                  title: Text(subtask.title),
                  subtitle: Text(subtask.description),
                  trailing: subtask.isMilestone
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
                final hasSubtasks = _getSubtasksForDay(day).isNotEmpty;
                final dateKey = DateTime(day.year, day.month, day.day);
                
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : isToday
                                ? AppTheme.primaryColor.withOpacity(0.3)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (hasSubtasks)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.primaryColor,
                                shape: BoxShape.circle,
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

class _EditSubtaskDialog extends StatefulWidget {
  final Subtask subtask;
  final bool isNew;

  const _EditSubtaskDialog({
    required this.subtask,
    this.isNew = false,
  });

  @override
  State<_EditSubtaskDialog> createState() => _EditSubtaskDialogState();
}

class _EditSubtaskDialogState extends State<_EditSubtaskDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _hoursController;
  String _priority = 'medium';
  String _frequency = 'one-time';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.subtask.title);
    _descriptionController = TextEditingController(text: widget.subtask.description);
    _hoursController = TextEditingController(
      text: widget.subtask.estimatedHours?.toStringAsFixed(1) ?? '',
    );
    _priority = widget.subtask.priority;
    _frequency = widget.subtask.frequency;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hoursController.dispose();
    super.dispose();
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
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
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
            Navigator.pop(
              context,
              widget.subtask.copyWith(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                estimatedHours: double.tryParse(_hoursController.text),
                priority: _priority,
                frequency: _frequency,
              ),
            );
          },
          child: Text(widget.isNew ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}

