import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/reminder.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/utils/reminder_context_status.dart';
import '../theme/app_theme.dart';
import 'reminder_card.dart';

/// Premium context group card with elegant section header and live status
class ContextGroupCard extends StatelessWidget {
  final String contextTitle;
  final List<Reminder> reminders;
  final String? contextIcon;
  final Function(Reminder)? onReminderTap;
  final Function(String, bool)? onToggle;
  final Function(String)? onDelete;
  final Position? currentPosition;
  final String? currentActivity;

  const ContextGroupCard({
    super.key,
    required this.contextTitle,
    required this.reminders,
    this.contextIcon,
    this.onReminderTap,
    this.onToggle,
    this.onDelete,
    this.currentPosition,
    this.currentActivity,
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

    return FutureBuilder<List<ReminderContextStatus>>(
      future: ReminderStatusCalculator.calculateStatuses(
        reminders,
        currentPosition: currentPosition,
        currentActivity: currentActivity,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, theme, icon, description),
              ...reminders.map((reminder) => ReminderCard(
                    reminder: reminder,
                    onTap: onReminderTap != null
                        ? () => onReminderTap!(reminder)
                        : null,
                    onToggle: onToggle != null
                        ? (enabled) => onToggle!(reminder.id, enabled)
                        : null,
                    onDelete: onDelete != null
                        ? () => onDelete!(reminder.id)
                        : null,
                  )),
            ],
          );
        }

        final statuses = snapshot.data!;
        final readyCount = statuses.where((s) => s.isReady).length;
        final locationBased = contextTitle == 'Location-Based' ||
            contextTitle == 'Relevant Now';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium section header with live status
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spacingSM,
                bottom: AppTheme.spacingMD,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  // Live status indicators
                  if (locationBased && statuses.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacingXS),
                    _buildStatusIndicators(context, theme, statuses, readyCount),
                  ],
                ],
              ),
            ),

            // Reminders list
            ...reminders.map((reminder) {
              final status = statuses.firstWhere(
                (s) => s.reminder.id == reminder.id,
                orElse: () => ReminderContextStatus(
                  reminder: reminder,
                  isReady: false,
                  statusText: 'Unknown',
                ),
              );
              return ReminderCard(
                reminder: reminder,
                onTap: onReminderTap != null
                    ? () => onReminderTap!(reminder)
                    : null,
                onToggle: onToggle != null
                    ? (enabled) => onToggle!(reminder.id, enabled)
                    : null,
                onDelete: onDelete != null
                    ? () => onDelete!(reminder.id)
                    : null,
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    String icon,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacingSM,
        bottom: AppTheme.spacingMD,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getContextColor(contextTitle).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSM),
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
    );
  }

  Widget _buildStatusIndicators(
    BuildContext context,
    ThemeData theme,
    List<ReminderContextStatus> statuses,
    int readyCount,
  ) {
    // Group by status
    final readyStatuses = statuses.where((s) => s.isReady).toList();
    final waitingStatuses = statuses.where((s) => !s.isReady).toList();

    return Wrap(
      spacing: AppTheme.spacingSM,
      runSpacing: AppTheme.spacingXS,
      children: [
        if (readyStatuses.isNotEmpty)
          _buildStatusChip(
            context,
            theme,
            '✅ ${readyStatuses.length} Ready',
            AppTheme.successColor,
          ),
        ...waitingStatuses.take(3).map((status) {
          final text = status.distance != null
              ? '⏳ ${status.getFormattedDistance()}'
              : '⏳ ${status.statusText}';
          return _buildStatusChip(
            context,
            theme,
            text,
            AppTheme.warningColor,
          );
        }),
        if (waitingStatuses.length > 3)
          _buildStatusChip(
            context,
            theme,
            '+${waitingStatuses.length - 3} more',
            AppTheme.textSecondary,
          ),
      ],
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    ThemeData theme,
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSM,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusRound),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
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
