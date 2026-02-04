import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/goal_task.dart';
import '../theme/app_theme.dart';

class TimelineTaskTile extends StatelessWidget {
  final GoalTask task;
  final bool isFirst;
  final bool isLast;
  final bool isPast;
  final VoidCallback onTap;
  final Function(bool?) onToggle;
  final VoidCallback onDelete;
  final VoidCallback onToggleTimer;

  const TimelineTaskTile({
    super.key,
    required this.task,
    this.isFirst = false,
    this.isLast = false,
    this.isPast = false,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    required this.onToggleTimer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white54 : Colors.black54;

    // Format time: "08:00 AM" or "Any Time"
    String timeStr = "Any Time";
    if (task.scheduledDate != null) {
      if (task.scheduledDate!.hour == 0 && task.scheduledDate!.minute == 0) {
        // Handle "Any Time" convention (midnight)
        if (task.suggestedTime == 'morning') timeStr = "Morning";
        else if (task.suggestedTime == 'afternoon') timeStr = "Afternoon";
        else if (task.suggestedTime == 'evening') timeStr = "Evening";
      } else {
        timeStr = DateFormat('hh:mm a').format(task.scheduledDate!);
      }
    }

    final isRunning = task.startedAt != null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Time Column
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                timeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: isPast ? subtleColor.withOpacity(0.3) : subtleColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          
          // 2. Timeline Line
          SizedBox(
            width: 40,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical Line
                if (!isLast)
                Positioned(
                  top: 24,
                  bottom: -24, // Connect to next
                  child: Container(
                    width: 2,
                    color: isPast ? subtleColor.withOpacity(0.1) : subtleColor.withOpacity(0.3),
                  ),
                ),
                // Timeline Dot/Icon
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: task.isCompleted 
                        ? AppTheme.primaryColor 
                        : (isRunning ? Colors.amber : theme.scaffoldBackgroundColor),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: task.isCompleted || isRunning ? Colors.transparent : subtleColor,
                      width: 2
                    ),
                  ),
                  child: task.isCompleted 
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),

          // 3. Task Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24.0, right: 16),
              child: Dismissible(
                key: Key('timeline_task_${task.id}'),
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
                      builder: (context) => AlertDialog(
                          title: const Text('Delete Task'),
                          content: Text('Delete "${task.title}"?'),
                          actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                      ),
                   ) ?? false;
                },
                onDismissed: (_) => onDelete(),
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isRunning 
                          ? (isDark ? AppTheme.darkSurfaceElevated : AppTheme.primaryColor.withOpacity(0.1))
                          : (isDark ? AppTheme.darkSurface : Colors.white),
                      borderRadius: BorderRadius.circular(12),
                      border: isRunning ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5)) : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  color: task.isCompleted ? subtleColor : textColor,
                                  decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                              // Checkbox Area
                              GestureDetector(
                                onTap: () => onToggle(!task.isCompleted),
                                child: Row(
                                  children: [
                                    Icon(
                                      task.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                      size: 16,
                                      color: task.isCompleted ? AppTheme.primaryColor : subtleColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      task.isCompleted ? "Completed" : "Mark Done",
                                      style: TextStyle(
                                        color: task.isCompleted ? AppTheme.primaryColor : subtleColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Timer Action
                              if (!task.isCompleted)
                              GestureDetector(
                                onTap: onToggleTimer,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isRunning ? Colors.amber.withOpacity(0.2) : AppTheme.primaryColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isRunning ? Icons.pause : Icons.play_arrow,
                                    size: 16,
                                    color: isRunning ? Colors.amber : AppTheme.primaryColor,
                                  ),
                                ),
                              )
                           ],
                         )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
