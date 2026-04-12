import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/reminder_provider.dart';
import '../providers/growth_provider.dart';
import '../providers/auth_provider.dart';
import '../theme/theme.dart';

import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import 'animated_goal_creation_screen.dart';
import '../widgets/lumio_main_tab_header.dart';
import '../widgets/quick_task_input_sheet.dart';

/// Stitch-style Home Screen
/// Features: Profile header, week calendar, active goals, today's actions, activity chart
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().loadReminders();
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  String _getUserName() {
    try {
      final authProvider = context.read<AuthProvider>();
      final name = authProvider.user?.displayName ?? 'there';
      return name.split(' ').first;
    } catch (_) {
      return 'there';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: SafeArea(
        bottom: false,
        child: Consumer2<GrowthProvider, ReminderProvider>(
          builder: (context, growthProvider, reminderProvider, _) {
            final stats = growthProvider.userStats;
            final streak = stats?.streak ?? 0;
            final level = stats?.level ?? 1;
            // Filter out system goals (Inbox and Daily Plan)
            final goals = growthProvider.goals.where((g) =>
              g.name != 'Inbox' && !g.name.startsWith('Daily Plan')
            ).toList();

            // Get tasks for selected date
            final selectedDateTasks = _getTasksForDate(growthProvider, _selectedDate);
            final hasGoals = goals.isNotEmpty;

            return RefreshIndicator(
              onRefresh: () async {
                await growthProvider.loadGrowthData();
                await reminderProvider.loadReminders();
              },
              color: LumioColors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: _buildHeader(context, streak, level),
                  ),

                  // Week Calendar
                  SliverToBoxAdapter(
                    child: _buildWeekCalendar(context),
                  ),

                  // Today's Actions (for selected date)
                  SliverToBoxAdapter(
                    child: _buildTodayActionsSection(context, selectedDateTasks, growthProvider),
                  ),

                  // Active Goals
                  SliverToBoxAdapter(
                    child: _buildActiveGoalsSection(context, goals, growthProvider, hasGoals),
                  ),

                  // Weekly Activity Chart
                  SliverToBoxAdapter(
                    child: _buildWeeklyActivityChart(context, growthProvider),
                  ),

                  // Bottom padding for nav bar
                  SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int streak, int level) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        LumioSpacing.screenHorizontal,
        LumioSpacing.lg,
        LumioSpacing.screenHorizontal,
        LumioSpacing.md,
      ),
      child: Row(
        children: [
          // Profile Avatar with status dot
          Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: LumioColors.surface(context),
                    width: 2,
                  ),
                  boxShadow: LumioShadows.getSoft(context),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/Lumio_logo.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: LumioColors.primaryLight,
                      child: Icon(
                        Icons.person_rounded,
                        color: LumioColors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              // Online status dot
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: LumioColors.online,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: LumioColors.surface(context),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(width: LumioSpacing.md),

          // Greeting and streak
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Hi, ${_getUserName()} ',
                      style: LumioTypography.greeting.copyWith(
                        color: LumioColors.textPrimary(context),
                      ),
                    ),
                    const Text('👋', style: TextStyle(fontSize: 20)),
                  ],
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: LumioColors.streak,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$streak Day Streak',
                      style: LumioTypography.streakCounter.copyWith(
                        color: LumioColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Level badge (tappable)
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showLevelProgressSheet(context, level);
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: LumioColors.surface(context),
                borderRadius: LumioRadius.radiusFull,
                boxShadow: LumioShadows.getSoft(context),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    color: LumioColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Lvl $level',
                    style: LumioTypography.levelBadge.copyWith(
                      color: LumioColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: LumioSpacing.sm),

          const LumioHeaderNotificationButton(),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar(BuildContext context) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekDays = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: LumioSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: LumioSpacing.md),
          // Month header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(now),
                style: LumioTypography.titleMedium.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = DateTime.now();
                  });
                },
                child: Text(
                  'Today',
                  style: LumioTypography.labelLarge.copyWith(
                    color: LumioColors.primary,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: LumioSpacing.md),

          // Week days
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = weekDays[index];
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, now);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedDate = date;
                  });
                },
                child: Column(
                  children: [
                    Text(
                      dayLabels[index],
                      style: LumioTypography.calendarDayLabel.copyWith(
                        color: isSelected
                            ? LumioColors.primary
                            : LumioColors.textSecondary(context),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: LumioSpacing.sm),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? LumioColors.primary
                            : LumioColors.surface(context),
                        shape: BoxShape.circle,
                        border: isToday && !isSelected
                            ? Border.all(
                                color: LumioColors.primary.withValues(alpha: 0.45),
                                width: 2,
                              )
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: LumioColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : LumioShadows.getSoft(context),
                      ),
                      child: Center(
                        child: Text(
                          '${date.day}',
                          style: LumioTypography.calendarDate.copyWith(
                            color: isSelected
                                ? Colors.white
                                : LumioColors.textPrimary(context),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          SizedBox(height: LumioSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildActiveGoalsSection(BuildContext context, List<Goal> goals, GrowthProvider provider, bool hasGoals) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: LumioSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Goals',
                style: LumioTypography.titleMedium.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const AnimatedGoalCreationScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: LumioColors.primary,
                    borderRadius: LumioRadius.radiusFull,
                    boxShadow: [
                      BoxShadow(
                        color: LumioColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Add Goal',
                        style: LumioTypography.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: LumioSpacing.md),

          // Goals or empty state
          if (!hasGoals)
            _buildEmptyGoalsState(context)
          else
            Column(
              children: goals.take(3).map((goal) {
                final tasks = provider.getTasksForGoal(goal.id);
                final completedTasks = tasks.where((t) => t.isCompleted).length;
                final totalTasks = tasks.length;
                final progress = totalTasks > 0 ? (completedTasks / totalTasks * 100).round() : 0;

                return Padding(
                  padding: EdgeInsets.only(bottom: LumioSpacing.md),
                  child: _buildGoalCard(context, goal, progress, provider),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyGoalsState(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(LumioSpacing.xl),
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.card,
        border: Border.all(
          color: LumioColors.border(context),
          width: 1,
          style: BorderStyle.solid,
        ),
        boxShadow: LumioShadows.getSoft(context),
      ),
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
              Icons.flag_rounded,
              color: LumioColors.primary,
              size: 32,
            ),
          ),
          SizedBox(height: LumioSpacing.lg),
          Text(
            'Start by adding your first goal',
            style: LumioTypography.titleMedium.copyWith(
              color: LumioColors.textPrimary(context),
            ),
          ),
          SizedBox(height: LumioSpacing.sm),
          Text(
            'Your journey begins with a single step. Tap the add button to get started.',
            textAlign: TextAlign.center,
            style: LumioTypography.bodyMedium.copyWith(
              color: LumioColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, Goal goal, int progress, GrowthProvider provider) {
    // Get category color based on goal - using default since Goal model doesn't have category
    final category = 'work'; // Default category
    final categoryColors = _getCategoryColor(category);
    final tasks = provider.getTasksForGoal(goal.id);
    final currentPhase = _getCurrentPhase(tasks);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Navigate to goal details
      },
      child: Container(
        padding: EdgeInsets.all(LumioSpacing.lg),
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.card,
          boxShadow: LumioShadows.getSoft(context),
        ),
        child: Stack(
          children: [
            // Left color indicator
            Positioned(
              left: 0,
              top: LumioSpacing.md,
              bottom: LumioSpacing.md,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: categoryColors['primary'],
                  borderRadius: LumioRadius.indicatorBar,
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.only(left: LumioSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category badge and icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryColors['light'],
                          borderRadius: LumioRadius.categoryBadge,
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: LumioTypography.categoryBadge.copyWith(
                            color: categoryColors['primary'],
                          ),
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: LumioColors.background(context),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getCategoryIcon(category),
                          color: LumioColors.textTertiary(context),
                          size: 16,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: LumioSpacing.sm),

                  // Goal title
                  Text(
                    goal.name,
                    style: LumioTypography.titleMedium.copyWith(
                      color: LumioColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: LumioSpacing.md),

                  // Phase and progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        currentPhase,
                        style: LumioTypography.bodySmall.copyWith(
                          color: LumioColors.textSecondary(context),
                        ),
                      ),
                      Text(
                        '$progress%',
                        style: LumioTypography.progressPercent.copyWith(
                          color: LumioColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: LumioSpacing.sm),

                  // Progress bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: LumioColors.background(context),
                      borderRadius: LumioRadius.progressBar,
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress / 100,
                      child: Container(
                        decoration: BoxDecoration(
                          color: categoryColors['primary'],
                          borderRadius: LumioRadius.progressBar,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickTaskSheetForSelectedDate(BuildContext context) {
    final sheetDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => QuickTaskInputSheet(
        initialDate: sheetDate,
        onSubmit: (title, date, priority, tags, repeat) async {
          Navigator.pop(sheetContext);
          if (title.isEmpty) return;

          try {
            final growth = context.read<GrowthProvider>();
            if (growth.goals.isEmpty) {
              await growth.loadGrowthData();
            }

            Goal? inboxGoal;
            try {
              inboxGoal = growth.goals.firstWhere(
                (g) => g.name == 'Inbox',
                orElse: () => Goal(id: -1, name: 'temp', createdAt: DateTime.now()),
              );
            } catch (_) {}

            final int goalId;
            if (inboxGoal == null || inboxGoal.id == -1) {
              goalId = await growth.createGoal('Inbox');
            } else {
              goalId = inboxGoal.id;
            }

            final scheduledDate = date ?? sheetDate;
            final newTask = GoalTask(
              id: 0,
              goalId: goalId,
              title: title,
              description: tags.join(' '),
              createdAt: DateTime.now(),
              scheduledDate: scheduledDate,
              priority: priority,
              frequency: repeat ?? 'one-time',
              isCompleted: false,
              estimatedHours: 0.5,
              order: 0,
              indentLevel: 0,
              subtasks: [],
            );

            await growth.createTask(newTask);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task added to Inbox 📥')),
              );
            }
          } catch (e) {
            debugPrint('Error adding task from home: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not add task: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildTodayActionsSection(BuildContext context, List<GoalTask> tasks, GrowthProvider provider) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final sectionTitle = isToday
        ? "Today's Actions"
        : DateFormat('EEEE, MMM d').format(_selectedDate);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: LumioSpacing.screenHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  sectionTitle,
                  style: LumioTypography.titleMedium.copyWith(
                    color: LumioColors.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tasks.isNotEmpty) ...[
                SizedBox(width: LumioSpacing.sm),
                Text(
                  '${tasks.where((t) => t.isCompleted).length}/${tasks.length} done',
                  style: LumioTypography.bodySmall.copyWith(
                    color: LumioColors.textSecondary(context),
                  ),
                ),
              ],
              SizedBox(width: LumioSpacing.sm),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showQuickTaskSheetForSelectedDate(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: LumioColors.primary,
                    borderRadius: LumioRadius.radiusFull,
                    boxShadow: [
                      BoxShadow(
                        color: LumioColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Add Task',
                        style: LumioTypography.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: LumioSpacing.md),

          if (tasks.isEmpty)
            _buildEmptyActionsState(context)
          else
            ...tasks.take(5).map((task) => Padding(
              padding: EdgeInsets.only(bottom: LumioSpacing.sm),
              child: _buildTaskItem(context, task, provider),
            )),

          SizedBox(height: LumioSpacing.md),
        ],
      ),
    );
  }

  Widget _buildEmptyActionsState(BuildContext context) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: EdgeInsets.all(LumioSpacing.lg),
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.card,
        border: Border.all(
          color: LumioColors.border(context),
          width: 1,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: LumioColors.primaryLight,
              borderRadius: LumioRadius.radiusMD,
            ),
            child: Icon(
              Icons.event_available_rounded,
              color: LumioColors.primary,
              size: 24,
            ),
          ),
          SizedBox(width: LumioSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'No tasks for today' : 'No tasks scheduled',
                  style: LumioTypography.titleSmall.copyWith(
                    color: LumioColors.textPrimary(context),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  isToday
                      ? 'Tap + to add tasks or plan your day'
                      : 'Select a different date or add tasks',
                  style: LumioTypography.bodySmall.copyWith(
                    color: LumioColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, GoalTask task, GrowthProvider provider) {
    final goal = provider.goals.firstWhere(
      (g) => g.id == task.goalId,
      orElse: () => Goal(id: -1, name: 'Unknown', createdAt: DateTime.now()),
    );
    final isCompleted = task.isCompleted;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Toggle task or show details
      },
      child: Container(
        padding: EdgeInsets.all(LumioSpacing.md),
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.taskItem,
          boxShadow: LumioShadows.getSoft(context),
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                if (isCompleted) {
                  provider.uncompleteTask(task.id);
                } else {
                  provider.completeTask(task.id);
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
                      : Border.all(
                          color: LumioColors.border(context),
                          width: 2,
                        ),
                ),
                child: isCompleted
                    ? Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            ),

            SizedBox(width: LumioSpacing.md),

            // Task content
            Expanded(
              child: Opacity(
                opacity: isCompleted ? 0.5 : 1.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: LumioTypography.titleSmall.copyWith(
                        color: LumioColors.textPrimary(context),
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      goal.name,
                      style: LumioTypography.bodySmall.copyWith(
                        color: LumioColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Time badge or done badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? LumioColors.successLight
                    : LumioColors.primaryLight,
                borderRadius: LumioRadius.categoryBadge,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle_rounded : Icons.schedule_rounded,
                    color: isCompleted ? LumioColors.success : LumioColors.textSecondary(context),
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    isCompleted
                        ? 'Done'
                        : '${((task.estimatedHours ?? 0) * 60).round()}m',
                    style: LumioTypography.duration.copyWith(
                      color: isCompleted ? LumioColors.success : LumioColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyActivityChart(BuildContext context, GrowthProvider provider) {
    // Generate sample activity data based on completed tasks
    final now = DateTime.now();
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    // Calculate activity for each day (simplified)
    final activities = List.generate(7, (index) {
      // For now, generate some placeholder data (wire to completed tasks later).
      if (index == now.weekday - 1) return 1.0; // Today - full
      return (index * 0.15 + 0.2).clamp(0.1, 0.8);
    });

    return Padding(
      padding: EdgeInsets.all(LumioSpacing.screenHorizontal),
      child: Container(
        padding: EdgeInsets.all(LumioSpacing.lg),
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.card,
          boxShadow: LumioShadows.getSoft(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Activity',
                  style: LumioTypography.titleMedium.copyWith(
                    color: LumioColors.textPrimary(context),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: LumioColors.background(context),
                    borderRadius: LumioRadius.categoryBadge,
                  ),
                  child: Text(
                    'Last 7 Days',
                    style: LumioTypography.bodySmall.copyWith(
                      color: LumioColors.textSecondary(context),
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: LumioSpacing.xl),

            // Bar chart
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  final isToday = index == now.weekday - 1;
                  final height = (activities[index] * 100).clamp(0.0, 95.0);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 8,
                        height: height,
                        decoration: BoxDecoration(
                          color: isToday
                              ? LumioColors.primary
                              : LumioColors.background(context),
                          borderRadius: LumioRadius.activityBar,
                          boxShadow: isToday
                              ? [BoxShadow(
                                  color: LumioColors.primary.withOpacity(0.3),
                                  blurRadius: 4,
                                )]
                              : null,
                        ),
                      ),
                      SizedBox(height: LumioSpacing.sm),
                      Text(
                        dayLabels[index],
                        style: LumioTypography.labelSmall.copyWith(
                          color: isToday
                              ? LumioColors.primary
                              : LumioColors.textSecondary(context),
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<GoalTask> _getTasksForDate(GrowthProvider provider, DateTime date) {
    final allTasks = <GoalTask>[];

    for (var tasks in provider.tasksByGoal.values) {
      for (var task in tasks) {
        if (task.scheduledDate != null && _isSameDay(task.scheduledDate!, date)) {
          allTasks.add(task);
        }
      }
    }

    // Sort: incomplete first, then by scheduled time
    allTasks.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return (a.scheduledDate ?? DateTime.now()).compareTo(b.scheduledDate ?? DateTime.now());
    });

    return allTasks;
  }

  Map<String, Color> _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'business':
        return {'primary': LumioColors.primary, 'light': LumioColors.primaryLight};
      case 'health':
        return {'primary': LumioColors.categoryHealth, 'light': LumioColors.categoryHealthLight};
      case 'personal':
        return {'primary': LumioColors.categoryPersonal, 'light': LumioColors.categoryPersonalLight};
      case 'finance':
        return {'primary': LumioColors.categoryFinance, 'light': LumioColors.categoryFinanceLight};
      case 'learning':
        return {'primary': LumioColors.categoryLearning, 'light': LumioColors.categoryLearningLight};
      default:
        return {'primary': LumioColors.primary, 'light': LumioColors.primaryLight};
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'business':
        return Icons.rocket_launch_rounded;
      case 'health':
        return Icons.directions_run_rounded;
      case 'personal':
        return Icons.person_rounded;
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      case 'learning':
        return Icons.school_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  String _getCurrentPhase(List<GoalTask> tasks) {
    if (tasks.isEmpty) return 'No tasks yet';

    final completedCount = tasks.where((t) => t.isCompleted).length;
    final totalCount = tasks.length;

    if (completedCount == 0) return 'Phase 1: Getting Started';
    if (completedCount == totalCount) return 'Completed!';

    final phaseNum = (completedCount / totalCount * 4).ceil();
    final phases = ['Getting Started', 'In Progress', 'Almost There', 'Final Push'];
    return 'Phase $phaseNum: ${phases[phaseNum - 1]}';
  }

  void _showLevelProgressSheet(BuildContext context, int level) {
    final growthProvider = context.read<GrowthProvider>();
    final stats = growthProvider.userStats;
    final xp = stats?.xp ?? 0;
    final xpProgress = xp % 250;
    final progressPercent = (xpProgress / 250).clamp(0.0, 1.0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(LumioSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: LumioSpacing.lg),
                  decoration: BoxDecoration(
                    color: LumioColors.border(context),
                    borderRadius: LumioRadius.radiusFull,
                  ),
                ),

                // Header
                Text(
                  'LEVEL & PROGRESS',
                  style: LumioTypography.labelMedium.copyWith(
                    color: LumioColors.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),

                SizedBox(height: LumioSpacing.lg),

                // Level badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  decoration: BoxDecoration(
                    color: LumioColors.primary,
                    borderRadius: LumioRadius.radiusFull,
                    boxShadow: [
                      BoxShadow(
                        color: LumioColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Level $level',
                    style: LumioTypography.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                SizedBox(height: LumioSpacing.xl),

                // XP Progress
                Container(
                  padding: EdgeInsets.all(LumioSpacing.lg),
                  decoration: BoxDecoration(
                    color: LumioColors.background(context),
                    borderRadius: LumioRadius.card,
                    border: Border.all(
                      color: LumioColors.border(context),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'XP to Level ${level + 1}',
                            style: LumioTypography.titleSmall.copyWith(
                              color: LumioColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            '$xpProgress / 250 XP',
                            style: LumioTypography.labelMedium.copyWith(
                              color: LumioColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: LumioSpacing.md),
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: LumioColors.primaryLight,
                          borderRadius: LumioRadius.progressBar,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: progressPercent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: LumioColors.primary,
                              borderRadius: LumioRadius.progressBar,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: LumioSpacing.md),
                      Text(
                        'Keep it up! You\'re only ${250 - xpProgress} XP away from Level ${level + 1}.',
                        style: LumioTypography.bodySmall.copyWith(
                          color: LumioColors.textSecondary(context),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: LumioSpacing.xl),

                // Achievements header
                Row(
                  children: [
                    Icon(
                      Icons.military_tech_rounded,
                      color: LumioColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: LumioSpacing.sm),
                    Text(
                      'Recent Achievements',
                      style: LumioTypography.titleSmall.copyWith(
                        color: LumioColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: LumioSpacing.md),

                // Achievement badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAchievementBadge(context, Icons.local_fire_department_rounded, '7-Day\nStreak'),
                    _buildAchievementBadge(context, Icons.psychology_rounded, 'Deep Work\nMaster'),
                    _buildAchievementBadge(context, Icons.ads_click_rounded, 'Goal\nSetter'),
                  ],
                ),

                SizedBox(height: LumioSpacing.xl),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LumioColors.textPrimary(context),
                      foregroundColor: LumioColors.surface(context),
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: LumioRadius.radiusFull,
                      ),
                    ),
                    child: Text(
                      'Continue Journey',
                      style: LumioTypography.labelLarge.copyWith(
                        color: LumioColors.surface(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: LumioSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementBadge(BuildContext context, IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LumioColors.primary, LumioColors.primary.withOpacity(0.6)],
            ),
          ),
          padding: EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LumioColors.surface(context),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              icon,
              color: LumioColors.primary,
              size: 28,
            ),
          ),
        ),
        SizedBox(height: LumioSpacing.sm),
        Text(
          label,
          style: LumioTypography.labelSmall.copyWith(
            color: LumioColors.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
