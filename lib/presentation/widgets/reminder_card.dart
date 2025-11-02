import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/reminder.dart';
import '../theme/app_theme.dart';
import '../../core/utils/date_time_utils.dart';

/// Premium reminder card widget with minimal, elegant design
class ReminderCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: reminder.enabled 
              ? AppTheme.primaryColor.withOpacity(0.1)
              : AppTheme.borderColor,
          width: 1,
        ),
        boxShadow: reminder.enabled 
            ? AppTheme.getElevationShadow(1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Status indicator + Context badges + Actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status indicator (subtle left accent)
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: reminder.enabled
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    const SizedBox(width: AppTheme.spacingMD),
                    
                    // Main content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Context badges row
                          if (reminder.getContextIcons().isNotEmpty)
                            Wrap(
                              spacing: AppTheme.spacingSM,
                              runSpacing: AppTheme.spacingSM,
                              children: reminder.getContextIcons().map((icon) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppTheme.spacingSM,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getContextColor(icon)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusSM,
                                    ),
                                  ),
                                  child: Text(
                                    icon,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                            ),
                          
                          if (reminder.getContextIcons().isNotEmpty)
                            const SizedBox(height: AppTheme.spacingSM),
                          
                          // Reminder text
                          Text(
                            reminder.text,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              decoration: reminder.enabled
                                  ? TextDecoration.none
                                  : TextDecoration.lineThrough,
                              color: reminder.enabled
                                  ? theme.textTheme.titleMedium?.color
                                  : theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                          
                          const SizedBox(height: AppTheme.spacingSM),
                          
                          // Context metadata
                          _buildMetadata(context, reminder),
                        ],
                      ),
                    ),
                    
                    // Quick actions
                    Column(
                      children: [
                        // Toggle switch
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: reminder.enabled,
                            onChanged: onToggle,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacingXS),
                        
                        // Delete button (subtle)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark
                                ? AppTheme.textTertiary
                                : AppTheme.textSecondary,
                          ),
                          onPressed: onDelete,
                          tooltip: 'Delete',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, Reminder reminder) {
    final theme = Theme.of(context);
    final metadata = <Widget>[];
    
    // Priority badge
    if (reminder.priority != ReminderPriority.medium) {
      metadata.add(_buildMetadataChip(
        context,
        reminder.priority.emoji,
        reminder.priority.displayName,
        _getPriorityColor(reminder.priority),
      ));
    }
    
    // Category badge
    if (reminder.category != ReminderCategory.other) {
      metadata.add(_buildMetadataChip(
        context,
        reminder.category.emoji,
        reminder.category.displayName,
        AppTheme.textSecondary,
      ));
    }
    
    // Time metadata
    if (reminder.timeAt != null) {
      final timeStr = DateTimeUtils.formatTime(reminder.timeAt!);
      final isToday = DateTimeUtils.isToday(reminder.timeAt!);
      metadata.add(
        Text(
          isToday ? 'Today at $timeStr' : timeStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      );
    }
    
    // Next occurrence for recurring
    if (reminder.isRecurring && reminder.timeAt != null) {
      metadata.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 12,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              _formatNextOccurrence(reminder),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    
    if (metadata.isEmpty) return const SizedBox.shrink();
    
    return Wrap(
      spacing: AppTheme.spacingSM,
      runSpacing: AppTheme.spacingSM,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: metadata,
    );
  }

  Widget _buildMetadataChip(
    BuildContext context,
    String emoji,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSM,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Color _getContextColor(String icon) {
    if (icon.contains('⏰')) return AppTheme.timeColor;
    if (icon.contains('📍')) return AppTheme.locationColor;
    if (icon.contains('📶')) return AppTheme.wifiColor;
    if (icon.contains('🚪') || icon.contains('🏠')) {
      return AppTheme.locationColor;
    }
    return AppTheme.primaryColor;
  }

  Color _getPriorityColor(ReminderPriority priority) {
    switch (priority) {
      case ReminderPriority.low:
        return AppTheme.successColor;
      case ReminderPriority.medium:
        return AppTheme.textSecondary;
      case ReminderPriority.high:
        return AppTheme.warningColor;
      case ReminderPriority.critical:
        return AppTheme.errorColor;
    }
  }

  String _formatNextOccurrence(Reminder reminder) {
    if (reminder.timeAt == null) return 'Unknown';
    
    final now = DateTime.now();
    final next = reminder.timeAt!;
    
    if (DateTimeUtils.isToday(next)) {
      final timeStr = DateTimeUtils.formatTime(next);
      return 'Today $timeStr';
    }
    
    final tomorrow = now.add(const Duration(days: 1));
    if (next.year == tomorrow.year &&
        next.month == tomorrow.month &&
        next.day == tomorrow.day) {
      final timeStr = DateTimeUtils.formatTime(next);
      return 'Tomorrow $timeStr';
    }
    
    return DateTimeUtils.formatDate(next);
  }
}
