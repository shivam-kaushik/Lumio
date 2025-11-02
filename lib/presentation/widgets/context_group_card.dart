import 'package:flutter/material.dart';

import '../../data/models/reminder.dart';
import '../../core/utils/date_time_utils.dart';
import '../theme/app_theme.dart';
import 'reminder_card.dart';

/// Premium context group card with elegant section header
class ContextGroupCard extends StatelessWidget {
  final String contextTitle;
  final List<Reminder> reminders;
  final String? contextIcon;
  final Function(Reminder)? onReminderTap;
  final Function(String, bool)? onToggle;
  final Function(String)? onDelete;

  const ContextGroupCard({
    super.key,
    required this.contextTitle,
    required this.reminders,
    this.contextIcon,
    this.onReminderTap,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final icon = contextIcon ?? ReminderUtils.getContextIcon(contextTitle);
    final description = ReminderUtils.getContextDescription(
      contextTitle,
      reminders,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium section header
        Padding(
          padding: const EdgeInsets.only(
            left: AppTheme.spacingSM,
            bottom: AppTheme.spacingMD,
          ),
          child: Row(
            children: [
              // Icon badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _getContextColor(contextTitle).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSM),
              // Title and count
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contextTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (description.isNotEmpty)
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSM,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusRound),
                ),
                child: Text(
                  '${reminders.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Reminders list
        ...reminders.map((reminder) {
          return ReminderCard(
            reminder: reminder,
            onTap: onReminderTap != null
                ? () => onReminderTap!(reminder)
                : null,
            onToggle: onToggle != null
                ? (enabled) => onToggle!(reminder.id, enabled)
                : null,
            onDelete: onDelete != null ? () => onDelete!(reminder.id) : null,
          );
        }),
      ],
    );
  }

  Color _getContextColor(String contextTitle) {
    switch (contextTitle.toLowerCase()) {
      case 'relevant now':
        return AppTheme.primaryColor;
      case 'time-based':
        return AppTheme.timeColor;
      case 'location-based':
        return AppTheme.locationColor;
      case 'recurring':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.textSecondary;
    }
  }
}
