import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_card.dart';
import '../widgets/smart_reminder_dialog.dart';
import '../theme/app_theme.dart';
import '../../data/models/reminder.dart';

/// Calendar view screen showing reminders organized by date
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Load reminders when calendar opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().loadReminders();
    });
  }

  @override
  Widget build(BuildContext context) {
    // No Scaffold - MainNavigator provides it
    return Column(
      children: [
        // Custom AppBar
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: AppTheme.spacingLG,
            right: AppTheme.spacingMD,
            bottom: AppTheme.spacingMD,
          ),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Calendar',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Body content
        Expanded(
          child: Consumer<ReminderProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              final reminders = provider.reminders.where((r) => r.enabled).toList();
              final remindersByDate = _groupRemindersByDate(reminders);

              return Column(
                children: [
                  // Calendar month view
                  _buildMonthView(context, _selectedDate, remindersByDate),
                  
                  const Divider(height: 1, color: AppTheme.dividerColor),
                  
                  // Selected date reminders
                  Expanded(
                    child: _buildRemindersList(
                      context,
                      _selectedDate,
                      remindersByDate[_formatDate(_selectedDate)] ?? [],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView(
    BuildContext context,
    DateTime selectedDate,
    Map<String, List<Reminder>> remindersByDate,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      color: AppTheme.surfaceColor,
      child: Column(
        children: [
          // Month header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month - 1,
                      _selectedDate.day,
                    );
                  });
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(selectedDate),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(
                      _selectedDate.year,
                      _selectedDate.month + 1,
                      _selectedDate.day,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          
          // Calendar grid
          _buildCalendarGrid(selectedDate, remindersByDate),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
    DateTime monthDate,
    Map<String, List<Reminder>> remindersByDate,
  ) {
    final firstDayOfMonth = DateTime(monthDate.year, monthDate.month, 1);
    final lastDayOfMonth = DateTime(monthDate.year, monthDate.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday;
    final daysInMonth = lastDayOfMonth.day;

    // Get reminder count for visualization
    int getReminderCount(DateTime date) {
      final dateStr = _formatDate(date);
      return remindersByDate[dateStr]?.length ?? 0;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: 7 + daysInMonth, // Weekday headers + days
      itemBuilder: (context, index) {
        // Weekday headers
        if (index < 7) {
          const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return Center(
            child: Text(
              weekdays[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          );
        }

        // Calendar days
        final dayIndex = index - 7;
        
        // Empty cells before first day
        if (dayIndex < firstDayWeekday - 1) {
          return const SizedBox.shrink();
        }

        final day = dayIndex - (firstDayWeekday - 1) + 1;
        if (day > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(monthDate.year, monthDate.month, day);
        final isSelected = _isSameDay(date, _selectedDate);
        final isToday = _isSameDay(date, DateTime.now());
        final reminderCount = getReminderCount(date);

        return GestureDetector(
          onTap: () {
            setState(() => _selectedDate = date);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isToday
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 1)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                if (reminderCount > 0) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRemindersList(
    BuildContext context,
    DateTime date,
    List<Reminder> reminders,
  ) {
    if (reminders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'No reminders',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              _formatDate(date),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        120, // keep above bottom nav bar
      ),
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacingMD),
          child: Text(
            _getDateHeader(date),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        
        // Reminders
        ...reminders.map((reminder) => ReminderCard(
          reminder: reminder,
          onTap: () async {
            final result = await showDialog<Reminder>(
              context: context,
              builder: (context) => SmartReminderDialog(
                reminder: reminder,
              ),
            );
            if (result != null && mounted) {
              context.read<ReminderProvider>().updateReminder(result);
            }
          },
          onToggle: (enabled) {
            context.read<ReminderProvider>().toggleReminder(
              reminder.id,
              enabled,
            );
          },
          onDelete: () {
            context.read<ReminderProvider>().deleteReminder(reminder.id);
          },
        )),
      ],
    );
  }

  Map<String, List<Reminder>> _groupRemindersByDate(List<Reminder> reminders) {
    final Map<String, List<Reminder>> grouped = {};

    for (var reminder in reminders) {
      if (reminder.timeAt == null) continue;
      
      final dateStr = _formatDate(reminder.timeAt!);
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(reminder);
    }

    // Sort reminders by time within each date
    for (var remindersList in grouped.values) {
      remindersList.sort((a, b) {
        final timeA = a.timeAt ?? DateTime.now();
        final timeB = b.timeAt ?? DateTime.now();
        return timeA.compareTo(timeB);
      });
    }

    return grouped;
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _getDateHeader(DateTime date) {
    final today = DateTime.now();
    if (_isSameDay(date, today)) {
      return 'Today, ${DateFormat('MMMM d').format(date)}';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (_isSameDay(date, tomorrow)) {
      return 'Tomorrow, ${DateFormat('MMMM d').format(date)}';
    }
    return DateFormat('EEEE, MMMM d').format(date);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

