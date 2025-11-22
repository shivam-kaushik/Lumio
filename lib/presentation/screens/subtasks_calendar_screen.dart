import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal.dart';

/// Calendar screen showing all scheduled subtasks across all goals
class SubtasksCalendarScreen extends StatefulWidget {
  const SubtasksCalendarScreen({super.key});

  @override
  State<SubtasksCalendarScreen> createState() => _SubtasksCalendarScreenState();
}

class _SubtasksCalendarScreenState extends State<SubtasksCalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  List<GoalTask> _getTasksForDay(DateTime day) {
    final growthProvider = context.read<GrowthProvider>();
    final dateKey = DateTime(day.year, day.month, day.day);
    
    // Get all tasks from all goals
    final allTasks = <GoalTask>[];
    for (var goal in growthProvider.goals) {
      final tasks = growthProvider.getTasksForGoal(goal.id);
      for (var task in tasks) {
        if (task.scheduledDate != null) {
          final scheduledKey = DateTime(
            task.scheduledDate!.year,
            task.scheduledDate!.month,
            task.scheduledDate!.day,
          );
          if (scheduledKey == dateKey && !task.isCompleted) {
            allTasks.add(task);
          }
        }
      }
    }
    return allTasks;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<GrowthProvider>(
        builder: (context, growthProvider, child) {
          return Column(
            children: [
              // Calendar header with month navigation
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.chevron_left_rounded,
                        color: isDark 
                            ? AppTheme.darkTextPrimary 
                            : AppTheme.textPrimary,
                      ),
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDark 
                            ? AppTheme.darkTextPrimary 
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark 
                            ? AppTheme.darkTextPrimary 
                            : AppTheme.textPrimary,
                      ),
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
              ),
              // Calendar grid
              _buildCalendarGrid(),
              Divider(
                color: isDark 
                    ? AppTheme.darkDivider 
                    : AppTheme.dividerColor,
              ),
              // Selected day's tasks
              Expanded(
                child: _buildTasksList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
    
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
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
                            color: isDark 
                                ? AppTheme.darkTextSecondary 
                                : AppTheme.textSecondary,
                            fontSize: 12,
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
                                    : (isDark 
                                        ? AppTheme.darkTextPrimary 
                                        : AppTheme.textPrimary),
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            if (hasTasks)
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
      ),
    );
  }

  Widget _buildTasksList() {
    final tasks = _getTasksForDay(_selectedDay);
    final growthProvider = context.read<GrowthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 64,
              color: (isDark 
                  ? AppTheme.darkTextSecondary 
                  : AppTheme.textSecondary).withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'No tasks scheduled for ${DateFormat('MMM d, y').format(_selectedDay)}',
              style: TextStyle(
                color: isDark 
                    ? AppTheme.darkTextSecondary 
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        100, // Bottom padding above bottom navigation bar
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final goal = growthProvider.goals.firstWhere(
          (g) => g.id == task.goalId,
          orElse: () => Goal(
            id: 0,
            name: 'Unknown Goal',
            createdAt: DateTime.now(),
          ),
        );
        
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return Dismissible(
          key: Key('subtask_calendar_${task.id}_$index'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'Delete',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.delete_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Task'),
                content: Text('Are you sure you want to delete "${task.title}"?'),
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
            ) ?? false;
          },
          onDismissed: (direction) async {
            await growthProvider.deleteTask(task.id);
            growthProvider.loadGrowthData();
          },
          child: ModernSmartCard(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
            useGradient: true,
            elevationLevel: 1,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Checkbox/Icon
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: task.isCompleted
                            ? AppTheme.successColor
                            : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
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
                  // Title and content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark 
                                ? AppTheme.darkTextPrimary 
                                : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark 
                                ? AppTheme.darkTextSecondary 
                                : AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Goal: ${goal.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (task.estimatedHours != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Estimated: ${task.estimatedHours!.toStringAsFixed(1)} hours',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark 
                                  ? AppTheme.darkTextTertiary 
                                  : AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Complete button
                  IconButton(
                    icon: Icon(
                      task.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: task.isCompleted 
                          ? AppTheme.successColor 
                          : (isDark 
                              ? AppTheme.darkTextSecondary 
                              : AppTheme.textSecondary),
                    ),
                    onPressed: () async {
                      if (task.isCompleted) {
                        // Uncomplete the task
                        await growthProvider.uncompleteTask(task.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Task unmarked'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
                      } else {
                        // Complete the task
                        final message = await growthProvider.completeTask(task.id);
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
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

