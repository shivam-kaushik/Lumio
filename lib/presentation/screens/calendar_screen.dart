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
  bool _isExpanded = false; // Track if calendar is expanded to full month

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
                  // Calendar view - week or month based on expansion state
                  GestureDetector(
                    onVerticalDragEnd: (details) {
                      // Swipe down to expand, swipe up to collapse
                      if (details.primaryVelocity! > 500) {
                        // Swipe down
                        setState(() => _isExpanded = true);
                      } else if (details.primaryVelocity! < -500) {
                        // Swipe up
                        setState(() => _isExpanded = false);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: _isExpanded ? 325 : 125, // Week view: 120px, Month view: 320px
                      child: _buildMonthView(context, _selectedDate, remindersByDate),
                    ),
                  ),

                  // Expand/Collapse indicator
                  GestureDetector(
                    onTap: () {
                      setState(() => _isExpanded = !_isExpanded);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: AppTheme.surfaceColor,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isExpanded ? 'Show week' : 'Show full month',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1, color: AppTheme.dividerColor),

                  // Selected date reminders - more space
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: 4, // Further reduced vertical padding
      ),
      color: AppTheme.surfaceColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month header - compact
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
          const SizedBox(height: 2), // Further reduced spacing

          // Calendar grid - use Expanded when expanded, SizedBox when collapsed
          _isExpanded
              ? Expanded(
                  child: _buildCalendarGrid(selectedDate, remindersByDate),
                )
              : SizedBox(
                  height: 65, // Further reduced height for week view
                  child: _buildCalendarGrid(selectedDate, remindersByDate),
                ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
    DateTime monthDate,
    Map<String, List<Reminder>> remindersByDate,
  ) {
    // If collapsed, show only current week
    if (!_isExpanded) {
      return _buildWeekView(monthDate, remindersByDate);
    }

    // Otherwise show full month
    return _buildMonthGrid(monthDate, remindersByDate);
  }

  Widget _buildWeekView(
    DateTime monthDate,
    Map<String, List<Reminder>> remindersByDate,
  ) {
    // Show the week containing the selected date (Monday to Sunday)
    final selectedWeekday = _selectedDate.weekday;
    final startOfWeek = _selectedDate.subtract(Duration(days: selectedWeekday - 1));

    return Row(
      children: [
        // Weekday headers
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text(
                'Mon',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: _buildWeekDayCell(
                  startOfWeek,
                  remindersByDate,
                  _selectedDate,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text(
                'Tue',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: _buildWeekDayCell(
                  startOfWeek.add(const Duration(days: 1)),
                  remindersByDate,
                  _selectedDate,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text(
                'Wed',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: _buildWeekDayCell(
                  startOfWeek.add(const Duration(days: 2)),
                  remindersByDate,
                  _selectedDate,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text(
                'Thu',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: _buildWeekDayCell(
                  startOfWeek.add(const Duration(days: 3)),
                  remindersByDate,
                  _selectedDate,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text(
                'Fri',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: _buildWeekDayCell(
                  startOfWeek.add(const Duration(days: 4)),
                  remindersByDate,
                  _selectedDate,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text(
                'Sat',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: _buildWeekDayCell(
                  startOfWeek.add(const Duration(days: 5)),
                  remindersByDate,
                  _selectedDate,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 2),
              Text(
                'Sun',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: _buildWeekDayCell(
                  startOfWeek.add(const Duration(days: 6)),
                  remindersByDate,
                  _selectedDate,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDayCell(
    DateTime date,
    Map<String, List<Reminder>> remindersByDate,
    DateTime selectedDate,
  ) {
    final isSelected = _isSameDay(date, selectedDate);
    final isToday = _isSameDay(date, DateTime.now());
    final dateStr = _formatDate(date);
    final reminderCount = remindersByDate[dateStr]?.length ?? 0;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedDate = date);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : (isToday
                  ? AppTheme.primaryColor.withOpacity(0.08)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(6),
          border: isToday && !isSelected
              ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 1.5)
              : (isSelected
                  ? null
                  : Border.all(color: AppTheme.borderColor.withOpacity(0.3), width: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : (isToday ? FontWeight.w600 : FontWeight.w500),
                color: isSelected
                    ? Colors.white
                    : (isToday ? AppTheme.primaryColor : AppTheme.textPrimary),
              ),
            ),
            if (reminderCount > 0) ...[
              const SizedBox(height: 3),
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
  }

  Widget _buildMonthGrid(
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
      shrinkWrap: false, // Don't shrink wrap - let it fill available space
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.1, // Slightly wider cells to reduce height
        mainAxisSpacing: 1, // Reduced spacing
        crossAxisSpacing: 1, // Reduced spacing
      ),
      itemCount: 7 + daysInMonth, // Weekday headers + days
      itemBuilder: (context, index) {
        // Weekday headers - compact
        if (index < 7) {
          const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return Center(
            child: Text(
              weekdays[index],
              style: TextStyle(
                fontSize: 9, // Even smaller font
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.2,
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
            margin: const EdgeInsets.all(0.5), // Reduced margin
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isToday
                      ? AppTheme.primaryColor.withOpacity(0.08)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 1.5)
                  : (isSelected
                      ? null
                      : Border.all(color: AppTheme.borderColor.withOpacity(0.3), width: 0.5)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 11, // Even smaller font
                    fontWeight: isSelected ? FontWeight.w700 : (isToday ? FontWeight.w600 : FontWeight.w500),
                    color: isSelected
                        ? Colors.white
                        : (isToday ? AppTheme.primaryColor : AppTheme.textPrimary),
                  ),
                ),
                if (reminderCount > 0) ...[
                  const SizedBox(height: 0.5), // Minimal spacing
                  Container(
                    width: 3, // Even smaller dot
                    height: 3, // Even smaller dot
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
        12, // Reduced padding
        12, // Reduced padding
        12, // Reduced padding
        120, // keep above bottom nav bar
      ),
      children: [
        // Date header
        Padding(
          padding: const EdgeInsets.only(bottom: 8), // Reduced padding
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

