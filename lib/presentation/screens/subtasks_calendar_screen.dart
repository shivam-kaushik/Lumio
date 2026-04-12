import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal.dart';
import 'goal_details_screen.dart';
import '../widgets/lumio_main_tab_header.dart';

/// Lumio-themed Calendar screen showing all tasks with deadlines across all goals
class SubtasksCalendarScreen extends StatefulWidget {
  const SubtasksCalendarScreen({super.key});

  @override
  State<SubtasksCalendarScreen> createState() => _SubtasksCalendarScreenState();
}

class _SubtasksCalendarScreenState extends State<SubtasksCalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  List<GoalTask> _getTasksForDay(GrowthProvider provider, DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    final result = <GoalTask>[];
    for (final goal in provider.goals) {
      if (goal.name == 'Inbox' || goal.name.startsWith('Daily Plan')) continue;
      for (final task in provider.getTasksForGoal(goal.id)) {
        if (task.scheduledDate != null) {
          final d = task.scheduledDate!;
          if (DateTime(d.year, d.month, d.day) == dateKey) {
            result.add(task);
          }
        }
      }
    }
    return result;
  }

  bool _dayHasTasks(GrowthProvider provider, DateTime day) {
    return _getTasksForDay(provider, day).isNotEmpty;
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: Consumer<GrowthProvider>(
        builder: (context, provider, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildCalendar(context, provider)),
              SliverToBoxAdapter(child: _buildDayLabel(context)),
              SliverToBoxAdapter(child: _buildTasksForSelectedDay(context, provider)),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 100,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: lumioMainTabHeaderPadding(context),
      decoration: lumioMainTabHeaderDecoration(context),
      child: Row(
        children: [
          Text(
            'Calendar',
            style: lumioMainTabTitleTextStyle(context),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedDay = DateTime.now();
                _focusedMonth = DateTime.now();
              });
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: LumioSpacing.md,
                vertical: LumioSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: LumioColors.primary.withValues(alpha: 0.12),
                borderRadius: LumioRadius.filterButton,
              ),
              child: Text(
                'Today',
                style: LumioTypography.labelMedium.copyWith(
                  color: LumioColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: LumioSpacing.sm),
          const LumioHeaderNotificationButton(),
        ],
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, GrowthProvider provider) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: LumioSpacing.screenHorizontal),
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.card,
        border: Border.all(color: LumioColors.border(context)),
        boxShadow: LumioShadows.getSoft(context),
      ),
      child: Column(
        children: [
          // Month navigation
          Padding(
            padding: EdgeInsets.fromLTRB(
              LumioSpacing.md,
              LumioSpacing.md,
              LumioSpacing.md,
              LumioSpacing.sm,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _prevMonth();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: LumioColors.background(context),
                      borderRadius: LumioRadius.radiusMD,
                      border: Border.all(color: LumioColors.border(context)),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: LumioColors.textSecondary(context),
                      size: 20,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_focusedMonth),
                      style: LumioTypography.titleMedium.copyWith(
                        color: LumioColors.textPrimary(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _nextMonth();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: LumioColors.background(context),
                      borderRadius: LumioRadius.radiusMD,
                      border: Border.all(color: LumioColors.border(context)),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: LumioColors.textSecondary(context),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Weekday headers
          Padding(
            padding: EdgeInsets.symmetric(horizontal: LumioSpacing.sm),
            child: Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: LumioTypography.labelSmall.copyWith(
                              color: LumioColors.textTertiary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          SizedBox(height: LumioSpacing.xs),

          // Calendar grid
          Padding(
            padding: EdgeInsets.fromLTRB(
              LumioSpacing.sm,
              0,
              LumioSpacing.sm,
              LumioSpacing.md,
            ),
            child: _buildCalendarGrid(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, GrowthProvider provider) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    // Monday-first offset
    final startOffset = (firstDay.weekday - 1) % 7;

    final weeks = <List<DateTime?>>[];
    var currentWeek = <DateTime?>[...List.filled(startOffset, null)];

    for (var d = 1; d <= lastDay.day; d++) {
      currentWeek.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }
    while (currentWeek.isNotEmpty && currentWeek.length < 7) {
      currentWeek.add(null);
    }
    if (currentWeek.isNotEmpty) weeks.add(currentWeek);

    return Column(
      children: weeks.map((week) => _buildWeekRow(context, provider, week)).toList(),
    );
  }

  Widget _buildWeekRow(
    BuildContext context,
    GrowthProvider provider,
    List<DateTime?> week,
  ) {
    return Row(
      children: week.map((day) {
        if (day == null) {
          return const Expanded(child: SizedBox(height: 44));
        }

        final now = DateTime.now();
        final isSelected = day.year == _selectedDay.year &&
            day.month == _selectedDay.month &&
            day.day == _selectedDay.day;
        final isToday = day.year == now.year &&
            day.month == now.month &&
            day.day == now.day;
        final hasTasks = _dayHasTasks(provider, day);

        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedDay = day);
            },
            child: Container(
              height: 44,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? LumioColors.primary
                    : isToday
                        ? LumioColors.primaryLight
                        : Colors.transparent,
                borderRadius: LumioRadius.radiusMD,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: LumioTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? LumioColors.primary
                              : LumioColors.textPrimary(context),
                      fontWeight: isSelected || isToday
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                  if (hasTasks)
                    Container(
                      width: 4,
                      height: 4,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.8)
                            : LumioColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayLabel(BuildContext context) {
    final now = DateTime.now();
    final isToday = _selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        LumioSpacing.screenHorizontal,
        LumioSpacing.lg,
        LumioSpacing.screenHorizontal,
        LumioSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            isToday
                ? 'Today'
                : DateFormat('EEEE, MMM d').format(_selectedDay),
            style: LumioTypography.titleMedium.copyWith(
              color: LumioColors.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksForSelectedDay(BuildContext context, GrowthProvider provider) {
    final tasks = _getTasksForDay(provider, _selectedDay);

    if (tasks.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: LumioSpacing.screenHorizontal,
          vertical: LumioSpacing.xl,
        ),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: LumioColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  color: LumioColors.primary,
                  size: 32,
                ),
              ),
              SizedBox(height: LumioSpacing.md),
              Text(
                'No tasks due',
                style: LumioTypography.titleSmall.copyWith(
                  color: LumioColors.textSecondary(context),
                ),
              ),
              SizedBox(height: LumioSpacing.xs),
              Text(
                'Nothing scheduled for this day',
                style: LumioTypography.bodySmall.copyWith(
                  color: LumioColors.textTertiary(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: LumioSpacing.screenHorizontal),
      child: Column(
        children: tasks
            .map((task) => _buildCalendarTaskCard(context, task, provider))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarTaskCard(
    BuildContext context,
    GoalTask task,
    GrowthProvider provider,
  ) {
    final goal = provider.goals.firstWhere(
      (g) => g.id == task.goalId,
      orElse: () => Goal(id: 0, name: 'Unknown', createdAt: DateTime.now()),
    );
    final isCompleted = task.isCompleted;

    return Padding(
      padding: EdgeInsets.only(bottom: LumioSpacing.sm),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GoalDetailsScreen(goalId: task.goalId),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(LumioSpacing.md),
          decoration: BoxDecoration(
            color: LumioColors.surface(context),
            borderRadius: LumioRadius.card,
            border: Border.all(
              color: isCompleted
                  ? LumioColors.primary.withOpacity(0.2)
                  : LumioColors.border(context),
            ),
            boxShadow: LumioShadows.getSoft(context),
          ),
          child: Row(
            children: [
              // Completion checkbox
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  if (isCompleted) {
                    await provider.uncompleteTask(task.id);
                  } else {
                    await provider.completeTask(task.id);
                  }
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isCompleted ? LumioColors.primary : Colors.transparent,
                    borderRadius: LumioRadius.radiusXS,
                    border: isCompleted
                        ? null
                        : Border.all(color: LumioColors.border(context), width: 2),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                      : null,
                ),
              ),

              SizedBox(width: LumioSpacing.md),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: LumioTypography.bodyMedium.copyWith(
                        color: isCompleted
                            ? LumioColors.textSecondary(context)
                            : LumioColors.textPrimary(context),
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: LumioSpacing.xs),
                    // Goal name
                    Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 12,
                          color: LumioColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            goal.name,
                            style: LumioTypography.labelSmall.copyWith(
                              color: LumioColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (task.subtasks.isNotEmpty) ...[
                          SizedBox(width: LumioSpacing.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: LumioColors.border(context),
                              borderRadius: LumioRadius.phaseBadge,
                            ),
                            child: Text(
                              '${task.subtasks.where((s) => s.isCompleted).length}/${task.subtasks.length} subtasks',
                              style: LumioTypography.labelSmall.copyWith(
                                color: LumioColors.textSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(width: LumioSpacing.sm),

              // Priority dot + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _priorityColor(task.priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: LumioColors.textTertiary(context),
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return LumioColors.error;
      case 'medium':
        return LumioColors.warning;
      default:
        return LumioColors.success;
    }
  }
}
