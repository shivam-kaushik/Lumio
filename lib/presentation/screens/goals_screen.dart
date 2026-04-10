import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import 'animated_goal_creation_screen.dart';
import 'goal_details_screen.dart';
import 'recent_notifications_screen.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';

/// Stitch-style Goals Screen
/// Features: Search, filter tabs, goal cards with radial progress
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String _selectedFilter = 'All Goals';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _filters = ['All Goals', 'Active', 'Completed', 'Paused'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Goal> _filterGoals(List<Goal> goals, GrowthProvider provider) {
    // First filter out system goals
    var filtered = goals.where((g) =>
      g.name != 'Inbox' && !g.name.startsWith('Daily Plan')
    ).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((g) =>
        g.name.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'Active':
        filtered = filtered.where((g) {
          final tasks = provider.getTasksForGoal(g.id);
          final progress = _calculateProgress(tasks);
          return progress > 0 && progress < 1;
        }).toList();
        break;
      case 'Completed':
        filtered = filtered.where((g) {
          final tasks = provider.getTasksForGoal(g.id);
          final progress = _calculateProgress(tasks);
          return progress >= 1;
        }).toList();
        break;
      case 'Paused':
        // For now, no paused status - could add this to Goal model later
        filtered = [];
        break;
    }

    return filtered;
  }

  double _calculateProgress(List<GoalTask> tasks) {
    if (tasks.isEmpty) return 0;
    int total = 0;
    int completed = 0;

    void count(List<GoalTask> list) {
      for (var t in list) {
        total++;
        if (t.isCompleted) completed++;
        if (t.subtasks.isNotEmpty) count(t.subtasks);
      }
    }

    count(tasks);
    return total > 0 ? completed / total : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumioColors.background(context),
      body: Consumer<GrowthProvider>(
        builder: (context, provider, _) {
          final allGoals = provider.goals;
          final filteredGoals = _filterGoals(allGoals, provider);
          final activeCount = allGoals.where((g) {
            if (g.name == 'Inbox' || g.name.startsWith('Daily Plan')) return false;
            final tasks = provider.getTasksForGoal(g.id);
            final progress = _calculateProgress(tasks);
            return progress > 0 && progress < 1;
          }).length;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Sticky Header
              SliverToBoxAdapter(
                child: _buildHeader(context),
              ),

              // Search and Filters
              SliverToBoxAdapter(
                child: _buildSearchAndFilters(context),
              ),

              // Loading state
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (filteredGoals.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(context),
                )
              else ...[
                // Section header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      LumioSpacing.screenHorizontal,
                      LumioSpacing.md,
                      LumioSpacing.screenHorizontal,
                      LumioSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedFilter == 'All Goals' ? 'Active Goals' : _selectedFilter,
                          style: LumioTypography.titleMedium.copyWith(
                            color: LumioColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          '$activeCount in progress',
                          style: LumioTypography.bodyMedium.copyWith(
                            color: LumioColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Goal cards
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: LumioSpacing.screenHorizontal),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final goal = filteredGoals[index];
                        final tasks = provider.getTasksForGoal(goal.id);
                        final progress = _calculateProgress(tasks);

                        return Dismissible(
                          key: ValueKey('goal_${goal.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            margin: EdgeInsets.only(bottom: LumioSpacing.md),
                            decoration: BoxDecoration(
                              color: LumioColors.error,
                              borderRadius: LumioRadius.card,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
                                const SizedBox(height: 4),
                                Text(
                                  'Delete',
                                  style: LumioTypography.labelSmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (_) async {
                            HapticFeedback.mediumImpact();
                            return await showDialog<bool>(
                              context: context,
                              useRootNavigator: false,
                              builder: (ctx) => AlertDialog(
                                title: Text('Delete "${goal.name}"?'),
                                content: const Text('All tasks will be removed. This cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: LumioColors.error),
                                    child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            ) ?? false;
                          },
                          onDismissed: (_) => provider.deleteGoal(goal.id),
                          child: Padding(
                          padding: EdgeInsets.only(bottom: LumioSpacing.md),
                          child: _buildGoalCard(context, goal, tasks, progress, index == 0),
                          ),
                        );
                      },
                      childCount: filteredGoals.length,
                    ),
                  ),
                ),
              ],

              // Bottom padding
              SliverPadding(padding: EdgeInsets.only(bottom: 120)),
            ],
          );
        },
      ),
      floatingActionButton: _buildFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        LumioSpacing.screenHorizontal,
        MediaQuery.of(context).padding.top + LumioSpacing.md,
        LumioSpacing.screenHorizontal,
        LumioSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: LumioColors.background(context).withOpacity(0.95),
        border: Border(
          bottom: BorderSide(
            color: LumioColors.border(context),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Menu button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Scaffold.of(context).openDrawer();
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: LumioRadius.radiusFull,
              ),
              child: Icon(
                Icons.menu_rounded,
                color: LumioColors.textPrimary(context),
                size: 24,
              ),
            ),
          ),

          SizedBox(width: LumioSpacing.md),

          // Title
          Expanded(
            child: Text(
              'My Goals',
              style: LumioTypography.headlineSmall.copyWith(
                color: LumioColors.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          // Notifications
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const RecentNotificationsScreen(),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: LumioRadius.radiusFull,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    color: LumioColors.textPrimary(context),
                    size: 24,
                  ),
                  // Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: LumioColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(LumioSpacing.screenHorizontal),
      child: Column(
        children: [
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: LumioColors.surface(context),
              borderRadius: LumioRadius.searchBar,
              border: Border.all(
                color: LumioColors.border(context),
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: LumioTypography.bodyMedium.copyWith(
                color: LumioColors.textPrimary(context),
              ),
              decoration: InputDecoration(
                hintText: 'Search goals...',
                hintStyle: LumioTypography.bodyMedium.copyWith(
                  color: LumioColors.textTertiary(context),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: LumioColors.textSecondary(context),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: LumioSpacing.md,
                  vertical: LumioSpacing.md,
                ),
              ),
            ),
          ),

          SizedBox(height: LumioSpacing.md),

          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsets.only(right: LumioSpacing.sm),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.symmetric(
                        horizontal: LumioSpacing.lg,
                        vertical: LumioSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? LumioColors.textPrimary(context)
                            : LumioColors.surface(context),
                        borderRadius: LumioRadius.filterButton,
                        border: Border.all(
                          color: isSelected
                              ? LumioColors.textPrimary(context)
                              : LumioColors.border(context),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        filter,
                        style: LumioTypography.labelMedium.copyWith(
                          color: isSelected
                              ? LumioColors.surface(context)
                              : LumioColors.textSecondary(context),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, Goal goal, List<GoalTask> tasks, double progress, bool isLarge) {
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final totalTasks = tasks.length;
    final phaseText = _getPhaseText(progress, totalTasks);
    final phaseColor = _getPhaseColor(progress);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GoalDetailsScreen(goalId: goal.id),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(LumioSpacing.lg),
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.card,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: LumioColors.border(context),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left side: Phase badge and title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Phase badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: LumioSpacing.sm,
                          vertical: LumioSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: phaseColor.withOpacity(0.1),
                          borderRadius: LumioRadius.phaseBadge,
                        ),
                        child: Text(
                          phaseText,
                          style: LumioTypography.phaseIndicator.copyWith(
                            color: phaseColor,
                          ),
                        ),
                      ),

                      SizedBox(height: LumioSpacing.sm),

                      // Title
                      Text(
                        goal.name,
                        style: (isLarge ? LumioTypography.titleLarge : LumioTypography.titleMedium).copyWith(
                          color: LumioColors.textPrimary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Goal name is already displayed above
                      // Description field not available in Goal model
                    ],
                  ),
                ),

                SizedBox(width: LumioSpacing.md),

                // Radial progress
                _buildRadialProgress(
                  context,
                  progress,
                  phaseColor,
                  isLarge ? 56 : 48,
                ),
              ],
            ),

            if (isLarge) ...[
              SizedBox(height: LumioSpacing.md),

              // Progress bar
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: LumioColors.border(context),
                  borderRadius: LumioRadius.progressBar,
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: phaseColor,
                      borderRadius: LumioRadius.progressBar,
                    ),
                  ),
                ),
              ),
            ],

            SizedBox(height: LumioSpacing.md),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Due date
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: LumioColors.textSecondary(context),
                    ),
                    SizedBox(width: LumioSpacing.xs),
                    Text(
                      goal.targetDeadline != null
                          ? _formatDueDate(goal.targetDeadline!)
                          : 'No due date',
                      style: LumioTypography.bodySmall.copyWith(
                        color: LumioColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),

                // Task count or collaborators
                if (totalTasks > 0)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: LumioSpacing.sm,
                      vertical: LumioSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: LumioColors.border(context),
                      borderRadius: LumioRadius.phaseBadge,
                    ),
                    child: Text(
                      '$completedTasks/$totalTasks tasks',
                      style: LumioTypography.labelSmall.copyWith(
                        color: LumioColors.textSecondary(context),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadialProgress(BuildContext context, double progress, Color color, double size) {
    final percentage = (progress * 100).round();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          CustomPaint(
            size: Size(size, size),
            painter: _CircleProgressPainter(
              progress: 1.0,
              color: LumioColors.border(context),
              strokeWidth: size == 56 ? 4 : 3,
            ),
          ),
          // Progress circle
          CustomPaint(
            size: Size(size, size),
            painter: _CircleProgressPainter(
              progress: progress.clamp(0.0, 1.0),
              color: color,
              strokeWidth: size == 56 ? 4 : 3,
            ),
          ),
          // Percentage text
          Text(
            '$percentage%',
            style: (size == 56 ? LumioTypography.labelMedium : LumioTypography.labelSmall).copyWith(
              color: LumioColors.textPrimary(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(LumioSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: LumioColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.flag_rounded,
                color: LumioColors.primary,
                size: 40,
              ),
            ),
            SizedBox(height: LumioSpacing.xl),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No goals found'
                  : 'No goals yet',
              style: LumioTypography.headlineSmall.copyWith(
                color: LumioColors.textPrimary(context),
              ),
            ),
            SizedBox(height: LumioSpacing.sm),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try a different search term'
                  : 'Create your first goal to start\nturning ambition into action',
              textAlign: TextAlign.center,
              style: LumioTypography.bodyLarge.copyWith(
                color: LumioColors.textSecondary(context),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: 64 + bottomInset),
      child: FloatingActionButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AnimatedGoalCreationScreen(),
              fullscreenDialog: true,
            ),
          );
        },
        backgroundColor: LumioColors.primary,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  // Helper methods

  String _getPhaseText(double progress, int totalTasks) {
    if (totalTasks == 0) return 'Not Started';
    if (progress >= 1) return 'Completed';

    final phase = (progress * 4).ceil().clamp(1, 4);
    return 'Phase $phase of 4';
  }

  Color _getPhaseColor(double progress) {
    if (progress >= 0.9) return LumioColors.success;
    if (progress >= 0.5) return LumioColors.primary;
    if (progress >= 0.25) return LumioColors.info;
    return LumioColors.primary;
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) return 'Overdue';
    if (difference.inDays == 0) return 'Due Today';
    if (difference.inDays == 1) return 'Due Tomorrow';
    if (difference.inDays < 7) return 'Due in ${difference.inDays} days';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return 'Due ${months[date.month - 1]} ${date.day}';
  }
}

/// Custom painter for circular progress
class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircleProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw arc
    const startAngle = -math.pi / 2; // Start from top
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
