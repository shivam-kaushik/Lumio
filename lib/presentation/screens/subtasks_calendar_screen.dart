import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../../data/models/goal_subtask.dart';
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

  List<GoalSubtask> _getSubtasksForDay(DateTime day) {
    final growthProvider = context.read<GrowthProvider>();
    final dateKey = DateTime(day.year, day.month, day.day);
    
    // Get all subtasks from all goals
    final allSubtasks = <GoalSubtask>[];
    for (var goal in growthProvider.goals) {
      final subtasks = growthProvider.getSubtasksForGoal(goal.id);
      for (var subtask in subtasks) {
        if (subtask.scheduledDate != null) {
          final scheduledKey = DateTime(
            subtask.scheduledDate!.year,
            subtask.scheduledDate!.month,
            subtask.scheduledDate!.day,
          );
          if (scheduledKey == dateKey && !subtask.isCompleted) {
            allSubtasks.add(subtask);
          }
        }
      }
    }
    return allSubtasks;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: AppTheme.surfaceColor,
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
              ),
              // Calendar grid
              _buildCalendarGrid(),
              const Divider(),
              // Selected day's subtasks
              Expanded(
                child: _buildSubtasksList(),
              ),
            ],
          );
        },
      ),
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
                            color: AppTheme.textSecondary,
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
                  final hasSubtasks = _getSubtasksForDay(day).isNotEmpty;
                  
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
                                fontSize: 14,
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
      ),
    );
  }

  Widget _buildSubtasksList() {
    final subtasks = _getSubtasksForDay(_selectedDay);
    final growthProvider = context.read<GrowthProvider>();
    
    if (subtasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'No subtasks scheduled for ${DateFormat('MMM d, y').format(_selectedDay)}',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      itemCount: subtasks.length,
      itemBuilder: (context, index) {
        final subtask = subtasks[index];
        final goal = growthProvider.goals.firstWhere(
          (g) => g.id == subtask.goalId,
          orElse: () => Goal(
            id: 0,
            name: 'Unknown Goal',
            createdAt: DateTime.now(),
          ),
        );
        
        return Card(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
          child: ListTile(
            leading: subtask.isMilestone
                ? Icon(Icons.flag_rounded, color: AppTheme.primaryColor)
                : Icon(Icons.check_circle_outline_rounded),
            title: Text(
              subtask.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtask.description),
                const SizedBox(height: 4),
                Text(
                  'Goal: ${goal.name}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtask.estimatedHours != null)
                  Text(
                    'Estimated: ${subtask.estimatedHours!.toStringAsFixed(1)} hours',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(
                subtask.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: subtask.isCompleted ? Colors.green : AppTheme.textSecondary,
              ),
              onPressed: () async {
                if (!subtask.isCompleted) {
                  final message = await growthProvider.completeSubtask(subtask.id);
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
          ),
        );
      },
    );
  }
}

