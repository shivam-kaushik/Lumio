import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/models/reminder.dart';
import '../../data/models/reminder_occurrence.dart';
import '../../data/repositories/firestore_reminder_repository.dart';
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
  late bool _isCompleted;
  
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
    _initializeState();
  }

  @override
  void didUpdateWidget(ReminderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reminder.enabled != widget.reminder.enabled || 
        oldWidget.reminder.isRecurring != widget.reminder.isRecurring) {
      _initializeState();
    }
  }

  void _initializeState() {
    _isCompleted = widget.reminder.isRecurring
        ? false // recurrings calculate async, keep default
        : !widget.reminder.enabled;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.mediumImpact();
    
    // OPTIMISTIC LOCAL UPDATE
    setState(() {
      _isCompleted = !_isCompleted;
    });

    if (widget.onToggle != null) {
      // If we are now "completed" (true), pass false (enabled=false)
      // If we are now "uncompleted" (false), pass true (enabled=true)
      // Conveniently, we can just pass !_isCompleted as the new 'enabled' state
      widget.onToggle!(!_isCompleted);
      return;
    }
    
    // Fallback for providers if onToggle not used (legacy)
    final provider = Provider.of<ReminderProvider>(context, listen: false);
    if (!_isCompleted) { 
       // State is already flipped locally to "uncompleted", so we want to uncomplete remotely? 
       // Check logic: 
       // We tapped. 
       // Old state: Completed (true) -> New local state: Uncompleted (false).
       // Action: Uncomplete.
       provider.uncompleteReminder(widget.reminder.id);
    } else {
       // Old state: Uncompleted (false) -> New local state: Completed (true).
       // Action: Complete.
       provider.completeReminder(widget.reminder.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Use local state for visual properties
    final isDone = _isCompleted;
    final isEnabled = !isDone;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: ModernSmartCard(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        elevationLevel: isEnabled ? 1 : 0,
        borderColor: isEnabled 
            ? AppTheme.primaryColor.withOpacity(0.1)
            : null,
        onTap: widget.onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Complete checkbox - Leftmost
            isDone || !widget.reminder.isRecurring // Use local state for standard reminders
            ? GestureDetector(
                onTap: _handleTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? AppTheme.successColor
                          : AppTheme.borderColor,
                      width: 2,
                    ),
                    color: isDone
                        ? AppTheme.successColor
                        : Colors.transparent,
                  ),
                  child: isDone
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
              )
            // For recurring reminders, we might still need async check for specific occurrences if complex
            // But for now, let's keep the FutureBuilder mainly for the 'check' status if strictly needed.
            // Simplified for better perf:
            : Consumer<ReminderProvider>(
              builder: (context, provider, child) {
                  return FutureBuilder<List<ReminderOccurrence>>(
                    future: FirestoreReminderRepository().getCompletedOccurrences(widget.reminder.id),
                    builder: (context, snapshot) {
                      final hasCompletedOccurrences = snapshot.hasData && snapshot.data!.isNotEmpty;
                      // Update local if needed? No, separate logic for recurring.
                      // ... (existing recurring logic block if we want to keep it totally separate)
                      // Actually, let's unify.
                      // If it IS recurring, we rely on the future builder for the checked state source of truth?
                      // Or we can just use the toggle.
                      
                      // For now, return the widget as before for recurring special case
                      return GestureDetector(
                        onTap: () {
                           HapticFeedback.mediumImpact();
                           if (widget.onToggle != null) {
                             widget.onToggle!(!widget.reminder.enabled);
                             return;
                           }
                           if (!hasCompletedOccurrences) provider.completeReminder(widget.reminder.id);
                           else provider.uncompleteReminder(widget.reminder.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                           width: 20, height: 20,
                           decoration: BoxDecoration(
                             shape: BoxShape.circle,
                             border: Border.all(color: hasCompletedOccurrences ? AppTheme.successColor : AppTheme.borderColor, width: 2),
                             color: hasCompletedOccurrences ? AppTheme.successColor : Colors.transparent,
                           ),
                           child: hasCompletedOccurrences ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                        ),
                      );
                    },
                  );
              },
            ),
            
            const SizedBox(width: 10),

            // Reminder text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.reminder.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      fontSize: 14,
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: isDone
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
                  
                  // Metadata Row (Priority, Category)
                  if (true) // Always show row if we have priority (which is always) or category
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          _buildMetadataChip(
                              context,
                              label: widget.reminder.priority.displayName,
                              color: _getPriorityColor(widget.reminder.priority),
                              icon: Icons.flag_rounded,
                            ),
                          
                          if (widget.reminder.category != ReminderCategory.other)
                             const SizedBox(width: 6),

                          if (widget.reminder.category != ReminderCategory.other)
                             _buildMetadataChip(
                              context,
                              label: widget.reminder.category.displayName,
                              color: _getCategoryColor(widget.reminder.category),
                              icon: _getCategoryIcon(widget.reminder.category),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(width: 10),
            
            // Date and time
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
      final repository = FirestoreReminderRepository();
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

  Widget _buildMetadataChip(BuildContext context, {required String label, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.high:
      case ReminderPriority.critical:
        return AppTheme.errorColor;
      case ReminderPriority.low:
        return Colors.blue; 
      default:
        return Colors.orange;
    }
  }

  Color _getCategoryColor(ReminderCategory category) {
    switch (category) {
      case ReminderCategory.work: return Colors.blue;
      case ReminderCategory.personal: return Colors.purple;
      case ReminderCategory.shopping: return Colors.green;
      case ReminderCategory.health: return Colors.redAccent;
      case ReminderCategory.family: return Colors.orange;
      case ReminderCategory.study: return Colors.indigo;
      case ReminderCategory.other: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(ReminderCategory category) {
     switch (category) {
      case ReminderCategory.work: return Icons.work_outline_rounded;
      case ReminderCategory.personal: return Icons.person_outline_rounded;
      case ReminderCategory.shopping: return Icons.shopping_cart_outlined;
      case ReminderCategory.health: return Icons.favorite_border_rounded;
      case ReminderCategory.family: return Icons.family_restroom_rounded;
      case ReminderCategory.study: return Icons.school_outlined;
      case ReminderCategory.other: return Icons.turned_in_not_rounded;
    }
  }

}
