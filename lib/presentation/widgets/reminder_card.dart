import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/models/reminder.dart';
import '../../data/models/reminder_occurrence.dart';
import '../../data/repositories/reminder_repository.dart';
import '../theme/app_theme.dart';
import '../../core/utils/date_time_utils.dart';
import '../providers/reminder_provider.dart';
import 'modern_smart_card.dart';

/// Premium reminder card widget with minimal, elegant design
/// Includes smooth animations and interactive feedback
class ReminderCard extends StatefulWidget {
  final Reminder reminder;
  final VoidCallback? onTap;
  final Function(bool)? onToggle;
  final VoidCallback? onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    this.onTap,
    this.onToggle,
    this.onDelete,
  });

  @override
  State<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<ReminderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ScaleTransition(
      scale: _scaleAnimation,
      child: ModernSmartCard(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        elevationLevel: widget.reminder.enabled ? 1 : 0,
        borderColor: widget.reminder.enabled 
            ? AppTheme.primaryColor.withOpacity(0.1)
            : null,
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Complete checkbox - Leftmost
            Consumer<ReminderProvider>(
              builder: (context, provider, child) {
                // For one-time reminders, completion is based on enabled flag
                // For recurring reminders, check if there are completed occurrences
                final isCompleted = widget.reminder.isRecurring
                    ? false // Will be determined by FutureBuilder below
                    : !widget.reminder.enabled;
                
                if (widget.reminder.isRecurring) {
                  // For recurring reminders, check if there are completed occurrences
                  return FutureBuilder<List<ReminderOccurrence>>(
                    future: ReminderRepository().getCompletedOccurrences(widget.reminder.id),
                    builder: (context, snapshot) {
                      final hasCompletedOccurrences = snapshot.hasData && snapshot.data!.isNotEmpty;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (!hasCompletedOccurrences) {
                            provider.completeReminder(widget.reminder.id);
                          } else {
                            provider.uncompleteReminder(widget.reminder.id);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasCompletedOccurrences
                                  ? AppTheme.successColor
                                  : AppTheme.borderColor,
                              width: 2,
                            ),
                            color: hasCompletedOccurrences
                                ? AppTheme.successColor
                                : Colors.transparent,
                          ),
                          child: hasCompletedOccurrences
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 14,
                                )
                              : null,
                        ),
                      );
                    },
                  );
                }
                
                // For one-time reminders
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    if (!isCompleted) {
                      provider.completeReminder(widget.reminder.id);
                    } else {
                      provider.uncompleteReminder(widget.reminder.id);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20, // Reduced from 24
                    height: 20, // Reduced from 24
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCompleted
                            ? AppTheme.successColor
                            : AppTheme.borderColor,
                        width: 2,
                      ),
                      color: isCompleted
                          ? AppTheme.successColor
                          : Colors.transparent,
                    ),
                    child: isCompleted
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14, // Reduced from 16
                          )
                        : null,
                  ),
                );
              },
            ),
            
            const SizedBox(width: 10), // Reduced from spacingMD
            
            // Reminder text - Center (expanded)
            Expanded(
              child: Text(
                widget.reminder.text,
                style: theme.textTheme.bodyMedium?.copyWith( // Changed from bodyLarge
                  fontWeight: FontWeight.w500,
                  height: 1.3, // Reduced from 1.4
                  fontSize: 14, // Explicit smaller font
                  decoration: !widget.reminder.enabled
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  color: !widget.reminder.enabled
                      ? (theme.brightness == Brightness.dark
                          ? AppTheme.darkTextTertiary
                          : AppTheme.textTertiary)
                      : (theme.brightness == Brightness.dark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            const SizedBox(width: 10), // Reduced from spacingMD
            
            // Date and time - Rightmost
            _buildDateTime(context, widget.reminder),
          ],
        ),
      )
        .animate()
        .fadeIn(duration: 500.ms, delay: 50.ms)
        .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.98, 0.98), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutCubic),
    );
  }

  /// Build date and time display for the right side
  Widget _buildDateTime(BuildContext context, Reminder reminder) {
    final theme = Theme.of(context);
    
    // For recurring reminders, show next pending occurrence
    if (reminder.isRecurring) {
      return FutureBuilder<DateTime?>(
        future: _getNextOccurrence(reminder),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              width: 60,
              height: 20,
              child: Center(
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          
          final nextOccurrence = snapshot.data;
          
          if (nextOccurrence == null) {
            // No pending occurrence, show recurring indicator only
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
              Text(
                  'Recurring',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                  fontSize: 11, // Reduced from 12
                  fontWeight: FontWeight.w500,
                ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 2),
                    Icon(
                  Icons.repeat_rounded,
                  size: 12,
                  color: theme.brightness == Brightness.dark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.textTertiary,
                ),
              ],
            );
          }
          
          final now = DateTime.now();
          final isToday = DateTimeUtils.isToday(nextOccurrence);
          
          // Check if tomorrow
          final tomorrow = now.add(const Duration(days: 1));
          final isTomorrow = nextOccurrence.year == tomorrow.year &&
              nextOccurrence.month == tomorrow.month &&
              nextOccurrence.day == tomorrow.day;
          
          String dateText;
          if (isToday) {
            dateText = DateTimeUtils.formatTime(nextOccurrence);
          } else if (isTomorrow) {
            dateText = 'Tomorrow\n${DateTimeUtils.formatTime(nextOccurrence)}';
          } else {
            dateText = DateTimeUtils.formatDate(nextOccurrence);
            final timeStr = DateTimeUtils.formatTime(nextOccurrence);
            dateText = '$dateText\n$timeStr';
          }
          
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                dateText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 2),
              Icon(
                Icons.repeat_rounded,
                size: 12,
                color: theme.brightness == Brightness.dark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.textTertiary,
              ),
            ],
          );
        },
      );
    }
    
    // For one-time reminders, show timeAt
    if (reminder.timeAt == null) {
      return const SizedBox.shrink();
    }
    
    final timeAt = reminder.timeAt!;
    final now = DateTime.now();
    final isToday = DateTimeUtils.isToday(timeAt);
    
    // Check if tomorrow
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = timeAt.year == tomorrow.year &&
        timeAt.month == tomorrow.month &&
        timeAt.day == tomorrow.day;
    
    String dateText;
    if (isToday) {
      dateText = DateTimeUtils.formatTime(timeAt);
    } else if (isTomorrow) {
      dateText = 'Tomorrow\n${DateTimeUtils.formatTime(timeAt)}';
    } else {
      dateText = DateTimeUtils.formatDate(timeAt);
      final timeStr = DateTimeUtils.formatTime(timeAt);
      dateText = '$dateText\n$timeStr';
    }
    
    return Text(
      dateText,
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      textAlign: TextAlign.right,
    );
  }

  /// Get next pending occurrence for a recurring reminder
  Future<DateTime?> _getNextOccurrence(Reminder reminder) async {
    try {
      final repository = ReminderRepository();
      final pending = await repository.getPendingOccurrences(reminder.id);
      
      if (pending.isNotEmpty) {
        // Return the first pending occurrence time
        return pending.first.scheduledTime;
      }
      
      // No pending occurrences - calculate next one based on reminder pattern
      if (reminder.timeAt != null) {
        // If there's a timeAt, use it
        return reminder.timeAt;
      }
      
      // Calculate next occurrence from now
      final now = DateTime.now();
      Duration interval;
      
      if (reminder.repeatInterval != null && reminder.repeatUnit != null) {
        switch (reminder.repeatUnit) {
          case 'minutes':
            interval = Duration(minutes: reminder.repeatInterval!);
            break;
          case 'hours':
            interval = Duration(hours: reminder.repeatInterval!);
            break;
          case 'days':
            interval = Duration(days: reminder.repeatInterval!);
            break;
          case 'weeks':
            interval = Duration(days: reminder.repeatInterval! * 7);
            break;
          default:
            interval = Duration(minutes: reminder.repeatInterval!);
        }
        return now.add(interval);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting next occurrence: $e');
      return null;
    }
  }

}
