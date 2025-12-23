import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/reminder_provider.dart';
import '../providers/growth_provider.dart';
import '../widgets/context_group_card.dart';
import '../widgets/smart_reminder_dialog.dart';
import '../widgets/modern_smart_card.dart';
import '../theme/app_theme.dart';
import 'add_reminder_screen.dart';
import '../../data/models/reminder.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/services/home_detection_service.dart';

// Day Architect Imports
import 'day_planner_screen.dart';
import 'chat_screen.dart';
import '../widgets/execution_card.dart';
import '../widgets/day_planner_widgets.dart';
import '../../data/models/goal_task.dart';

/// Premium home screen with minimal, elegant design
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  String? _currentActivity;
  bool _hideCompleted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().loadReminders();
      context.read<GrowthProvider>().loadGrowthData();
      _updateContext();
    });
  }

  Future<void> _updateContext() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.whileInUse ||
          hasPermission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
        });
      }

      final homeService = HomeDetectionService();
    } catch (e) {
      debugPrint('Error updating context: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // No Scaffold here - MainNavigator provides it
    return SafeArea(
      bottom: false, // MainNavigator handles bottom safe area
      child: Column(
        children: [
          // Premium header
          _buildPremiumHeader(context, isDark),
          
          // Main content
          Expanded(
            child: Consumer<ReminderProvider>(
                builder: (context, reminderProvider, child) {
                  if (reminderProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (reminderProvider.error != null) {
                    return _buildErrorState(context, reminderProvider);
                  }

                  if (reminderProvider.reminders.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final visibleReminders = reminderProvider.reminders;
                  
                  return Consumer<GrowthProvider>(
                    builder: (context, growthProvider, _) {
                      // Find active task (Day Architect)
                      GoalTask? activeTask;
                      for (var list in growthProvider.tasksByGoal.values) {
                        for (var t in list) {
                          if (t.startedAt != null) {
                            activeTask = t;
                            break;
                          }
                        }
                        if (activeTask != null) break;
                      }

                      // Group tasks? No, user wants a flat list.
                      final allReminders = _getAllReminders(
                        visibleReminders,
                        growthProvider,
                      );

                      return RefreshIndicator(
                        onRefresh: () async {
                          await reminderProvider.loadReminders();
                          await growthProvider.loadGrowthData();
                          await _updateContext();
                        },
                        child: CustomScrollView(
                          slivers: [
                            // Stats header
                            SliverToBoxAdapter(
                              child: _buildStatsHeader(context, reminderProvider),
                            ),
                            
                            // Day Architect: Dynamic Hero Section
                            Builder(
                              builder: (context) {
                                // 1. Check for Active Plan
                                final today = DateTime.now();
                                final dateStr = "${today.year}-${today.month}-${today.day}";
                                final goalName = "Daily Plan - $dateStr";
                                int? dayGoalId;
                                try {
                                  final goal = growthProvider.goals.firstWhere((g) => g.name == goalName);
                                  dayGoalId = goal.id;
                                } catch (_) {}
                                
                                final hasPlan = dayGoalId != null && growthProvider.getTasksForGoal(dayGoalId).isNotEmpty;
                                
                                // State 2: Active Execution (Priority)
                                if (activeTask != null) {
                                  return SliverPadding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: 8),
                                    sliver: SliverToBoxAdapter(
                                      child: ExecutionCard(task: activeTask!),
                                    ),
                                  );
                                }

                                // State 3: Plan Exists, Idle -> Daily Summary
                                if (hasPlan) {
                                  final tasks = growthProvider.getTasksForGoal(dayGoalId!);
                                  final completed = tasks.where((t) => t.isCompleted).length;
                                  
                                  return SliverPadding(
                                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: 8),
                                    sliver: SliverToBoxAdapter(
                                      child: DailySummaryCard(
                                        completedTasks: completed,
                                        totalTasks: tasks.length,
                                        onTap: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (_) => const DayPlannerScreen()));
                                        },
                                      ),
                                    ),
                                  );
                                }

                                // State 1: No Plan -> Morning Hero
                                return SliverPadding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: 8),
                                  sliver: SliverToBoxAdapter(
                                    child: MorningHeroCard(
                                      userName: "Shivam", // TODO: Get from profile
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => const DayPlannerScreen()));
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),

                            if (allReminders.isEmpty)
                               SliverFillRemaining(child: _buildEmptyState(context)),

                            // Unified Task List
                            if (allReminders.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppTheme.spacingMD,
                                  0,
                                  AppTheme.spacingMD,
                                  AppTheme.spacingMD,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: ContextGroupCard(
                                    contextTitle: 'All Tasks', // Flattened title
                                    reminders: allReminders, // Flattened list
                                    contextIcon: '📝',
                                    currentPosition: _currentPosition,
                                    onReminderTap: (reminder) async {
                                      if (reminder.id.startsWith('task_')) {
                                          // TODO: Navigate to Task Edit
                                          ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Editing tasks from Home is coming soon!"))
                                          );
                                          return;
                                      }

                                      final result = await showDialog<Reminder>(
                                        context: context,
                                        builder: (context) => SmartReminderDialog(
                                          reminder: reminder,
                                        ),
                                      );
                                      if (result != null && mounted) {
                                        reminderProvider.updateReminder(result);
                                      }
                                    },
                                    onToggle: (id, enabled) {
                                      if (id.startsWith('task_')) {
                                          final taskId = int.tryParse(id.substring(5)); // Remove 'task_' check
                                          if (taskId != null) {
                                              if (enabled) {
                                                  // Enabled = Active = Uncompleted
                                                  growthProvider.uncompleteTask(taskId);
                                              } else {
                                                  // Disabled = Inactive = Completed
                                                  growthProvider.completeTask(taskId);
                                              }
                                          }
                                      } else {
                                          reminderProvider.toggleReminder(id, enabled);
                                      }
                                    },
                                    onDelete: (id) {
                                      if (id.startsWith('task_')) {
                                          final taskId = int.tryParse(id.substring(5));
                                          if (taskId != null) {
                                              growthProvider.deleteTask(taskId);
                                          }
                                      } else {
                                          reminderProvider.deleteReminder(id);
                                      }
                                    },
                                  ),
                                ),
                              ),


                            // Bottom padding above bottom navigation bar
                            const SliverPadding(
                              padding: EdgeInsets.only(bottom: 120),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  /// Get ALL tasks flattened into one list, filtered for Inbox/Daily Plan
  List<Reminder> _getAllReminders(
    List<Reminder> reminders,
    GrowthProvider growthProvider,
  ) {
    final allReminders = [...reminders];

    // Identify allowed Goal IDs (Inbox and Daily Plans)
    final allowedGoalIds = <int>{};
    for (var goal in growthProvider.goals) {
      if (goal.name == 'Inbox' || goal.name.startsWith('Daily Plan')) {
        allowedGoalIds.add(goal.id);
      }
    }

    // Inject GoalTasks from allowed goals only
    if (growthProvider.tasksByGoal.isNotEmpty) {
      final allTasks = growthProvider.tasksByGoal.values.expand((list) => list).toList();

       for (var task in allTasks) {
          // Filter: Must be in an allowed goal (Main Screen tasks)
          if (!allowedGoalIds.contains(task.goalId)) {
            continue; 
          }
          
          allReminders.add(Reminder(
              id: "task_${task.id}", // Prefix to avoid collisions
              text: task.title,
              timeAt: task.scheduledDate ?? task.createdAt, // Fallback to created
              priority: _mapPriority(task.priority),
              category: ReminderCategory.work, // Default or parse tags
              linkedGoalId: task.goalId,
              enabled: !task.isCompleted, // Map completion status to enabled status
          ));
       }
    }
    
    // Sort logic
    allReminders.sort((a, b) {
        // 1. Incomplete before Complete
        if (a.enabled != b.enabled) {
            return a.enabled ? -1 : 1;
        }
        // 2. Scheduled Time (if available)
        if (a.timeAt != null && b.timeAt != null) {
            return a.timeAt!.compareTo(b.timeAt!);
        }
        return 0;
    });

    return allReminders;
  }

  ReminderPriority _mapPriority(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return ReminderPriority.high;
      case 'low': return ReminderPriority.low;
      case 'critical': return ReminderPriority.critical;
      case 'medium': 
      default: return ReminderPriority.medium;
    }
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
      ),
      child: Row(
        children: [
          // Logo/Icon with subtle gradient and 3D effect
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryLight,
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: AppTheme.getElevationShadow(2, isDark: isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              child: Image.asset(
                'assets/icons/Lumio_logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          )
            .animate()
            .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
            .shimmer(delay: 800.ms, duration: 2000.ms, color: Colors.white.withOpacity(0.4)),
          
          const SizedBox(width: AppTheme.spacingMD),
          
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lumio',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 100.ms)
                  .slideX(begin: -0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 2),
                Text(
                  'Turning goals into actions',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                )
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 200.ms)
                  .slideX(begin: -0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
              ],
            ),
          ),
          
          // Hands-free / Chatbot Action
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
                width: 1,
              ),
              boxShadow: AppTheme.getElevationShadow(1, isDark: isDark),
            ),
            child: IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(),
                  ),
                );
              },
              icon: Icon(
                Icons.smart_toy_outlined,
                color: isDark ? AppTheme.primaryLight : AppTheme.primaryColor,
                size: 24,
              ),
              tooltip: 'AI Assistant',
            ),
          )
            .animate()
            .scale(delay: 400.ms, duration: 500.ms, curve: Curves.elasticOut),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, ReminderProvider provider) {
    final stats = provider.statistics;
    if (stats == null) return const SizedBox.shrink();
    
    final total = stats['total'] ?? 0;
    final active = stats['active'] ?? 0;
    final completionRate = stats['completionRate'] ?? 0;
    
    if (total == 0) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ModernSmartCard(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingSM,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
      ),
      useGradient: true,
      elevationLevel: 2,
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(context, '$active', 'Active', isDark),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.dividerColor,
          ),
          Expanded(
            child: _buildStatItem(
              context,
              '$completionRate%',
              'Completed',
              isDark,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: isDark 
                ? const Color(0xFF1E1E20)
                : AppTheme.dividerColor,
          ),
          Expanded(
            child: _buildStatItem(context, '$total', 'Total', isDark),
          ),
        ],
      ),
    )
      .animate()
      .fadeIn(duration: 600.ms, delay: 100.ms)
      .slideY(begin: -0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic)
      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildStatItem(BuildContext context, String value, String label, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 64,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No tasks yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Create your first task\nto get started',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddReminderScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create Task'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingMD,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ReminderProvider provider,
  ) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.errorColor.withOpacity(0.7),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              provider.error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton(
              onPressed: () {
                provider.loadReminders();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

}
