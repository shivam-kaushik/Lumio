import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/subtasks_calendar_screen.dart';
import '../screens/account_screen.dart';

import '../screens/goal_planning_screen.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../screens/chat_screen.dart';
import '../providers/reminder_provider.dart';
import '../screens/day_planner_screen.dart'; // Added
import '../../data/models/goal.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/models/goal_task.dart';
import '../widgets/quick_task_input_sheet.dart';
import '../../data/models/reminder.dart';

/// Main navigation wrapper with bottom tab bar
/// Provides smooth transitions and consistent navigation structure
/// Features a floating action button (FAB) similar to Daylio app design
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;
  late final List<AnimationController> _fadeControllers;

  // Tab configurations
  final List<NavigationTab> _tabs = [
    NavigationTab(
      icon: Icons.list_outlined,
      activeIcon: Icons.list_rounded,
      label: 'Tasks',
      badge: null,
    ),
    NavigationTab(
      icon: Icons.flag_outlined,
      activeIcon: Icons.flag_rounded,
      label: 'Goals',
      badge: null,
    ),
    NavigationTab(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Calendar',
      badge: null,
    ),
    NavigationTab(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Account',
      badge: null,
    ),
  ];

  // Tab pages
  final List<Widget> _pages = [
    const HomeScreen(), // Tasks list
    const GoalsScreen(), // Goals
    const SubtasksCalendarScreen(), // Calendar (showing subtasks)
    const AccountScreen(), // Account
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize navigator keys for each tab
    _navigatorKeys = List.generate(
      _tabs.length,
      (index) => GlobalKey<NavigatorState>(),
    );
    
    // Initialize fade controllers for smooth transitions
    _fadeControllers = List.generate(
      _tabs.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );
    
    // Start initial page fade in
    _fadeControllers[0].forward();
  }

  @override
  void dispose() {
    for (var controller in _fadeControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) {
      // If tapping the same tab, scroll to top (if applicable)
      final navigator = _navigatorKeys[index].currentState;
      navigator?.popUntil((route) => route.isFirst);
      return;
    }

    setState(() {
      // Fade out current tab
      _fadeControllers[_currentIndex].reverse();
      _currentIndex = index;
      // Fade in new tab
      _fadeControllers[_currentIndex].forward();
    });
  }

  void _onRecordButtonPressed() {
    HapticFeedback.mediumImpact();
    _showCreateOptionsBottomSheet(context);
  }

  void _showCreateOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CreateOptionsBottomSheet(
        onCreateTask: () {
          Navigator.pop(context);
          // Show Quick Task Sheet
          _showQuickTaskSheet(context);
        },
        onCreateGoal: () {
          Navigator.pop(context);
          _createGoal(context);
        },
        onPlanDay: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const DayPlannerScreen(),
            ),
          );
        },
        onStartHandsFree: () {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ChatScreen(), // Navigate to ChatScreen
            ),
          );
        },
      ),
    );
  }

  Future<void> _createGoal(BuildContext context) async {
    // Switch to Goals tab
    setState(() {
      _currentIndex = 1; // Goals tab
    });
    
    // Wait for the tab to switch, then trigger goal creation
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _currentIndex == 0 
        ? Consumer<ReminderProvider>(
            builder: (context, reminderProvider, _) {
              return Consumer<GrowthProvider>(
                builder: (context, growthProvider, _) {
                  // Calculate visible tasks (logic must match HomeScreen)
                  bool hasTasks = false;
                  
                  // 1. Classic Reminders (Enabled only)
                  if (reminderProvider.reminders.where((r) => r.enabled).isNotEmpty) {
                      hasTasks = true;
                  }
                  
                  // 2. Growth Tasks (Inbox or Today)
                  if (!hasTasks && growthProvider.tasksByGoal.isNotEmpty) {
                      // Find Inbox
                      int? inboxId;
                      try {
                          inboxId = growthProvider.goals.firstWhere((g) => g.name == 'Inbox').id;
                      } catch (_) {}
                      
                      final allTasks = growthProvider.tasksByGoal.values.expand((l) => l);
                      // debugPrint('Searching Tasks...'); 
                      for (var t in allTasks) {
                          if (t.isCompleted) continue; // Skip completed

                          // Inbox Task?
                          if (inboxId != null && t.goalId == inboxId) {
                              hasTasks = true;
                              break;
                          }
                          // Today Task?
                          if (t.scheduledDate != null && DateTimeUtils.isToday(t.scheduledDate!.toLocal())) {
                              hasTasks = true;
                              break;
                          }
                      }
                  }

                  if (!hasTasks) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 50.0), // Adjust to be above navbar
                    child: FloatingActionButton(
                      onPressed: () => _showQuickTaskSheet(context),
                      backgroundColor: AppTheme.primaryColor,
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  );
                },
              );
            },
          )
        : null,
    );
  }

  void _showQuickTaskSheet(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => QuickTaskInputSheet(
        onSubmit: (title, date, priority, tags, repeat, location) async {
          // Close the sheet first
          Navigator.pop(sheetContext);
          
          if (title.isEmpty) return;

          try {
            // Use parentContext which is still valid
            final provider = parentContext.read<GrowthProvider>();
            
            // Find or Create 'Inbox' Goal
            Goal? inboxGoal;
            
            // Check if goals are loaded, otherwise load them
            if (provider.goals.isEmpty) {
                await provider.loadGrowthData();
            }
            
            try {
              inboxGoal = provider.goals.firstWhere((g) => g.name == 'Inbox', orElse: () => Goal(id: -1, name: 'temp', createdAt: DateTime.now()));
            } catch (_) { }

            int goalId;
            if (inboxGoal == null || inboxGoal.id == -1) {
              debugPrint('📥 Creating new Inbox goal...');
              goalId = await provider.createGoal('Inbox');
            } else {
              goalId = inboxGoal.id;
            }
            
            debugPrint('📥 Using Inbox Goal ID: $goalId for new task');

            // Create Task
            final newTask = GoalTask(
              id: 0, // Placeholder
              goalId: goalId,
              title: title,
              description: tags.join(' '), 
              createdAt: DateTime.now(),
              scheduledDate: date,
              priority: priority,
              frequency: repeat ?? 'one-time', 
              suggestedLocation: location ?? 'any', 
              isCompleted: false,
              estimatedHours: 0.5, 
              order: 0,
              indentLevel: 0,
              subtasks: [],
            );

            await provider.createTask(newTask);

            // Use parentWidget's context for checking mounted property if possible, 
            // but since we are in a closure, we can't easily check parentContext.mounted 
            // without linter warnings in older Flutter. 
            // However, ScaffoldMessenger needs a valid context.
            if (parentContext.mounted) {
              ScaffoldMessenger.of(parentContext).showSnackBar(
                SnackBar(
                  content: Text('Task added to Inbox 📥'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                         // TODO: Undo logic
                    },
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('Error creating task: $e');
            if (parentContext.mounted) {
               ScaffoldMessenger.of(parentContext).showSnackBar(
                 SnackBar(content: Text('Error adding task: $e')),
               );
            }
          }
        },
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0F0F0F).withOpacity(0.98),
                  Colors.black.withOpacity(0.98),
                ],
              )
            : null,
        color: isDark ? null : Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : AppTheme.shadowColor,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF2A2A2A).withOpacity(0.6)
                : AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSM,
            vertical: AppTheme.spacingSM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // First 2 tabs
              Expanded(child: _buildNavItem(context, 0)),
              Expanded(child: _buildNavItem(context, 1)),
              
              // Center record button (Strava-style)
              _buildCenterRecordButton(context),
              
              // Last 2 tabs
              Expanded(child: _buildNavItem(context, 2)),
              Expanded(child: _buildNavItem(context, 3)),
            ],
          ),
        ),
      ),
    );
  }

  /// Build center "Plan Day" button with animations
  Widget _buildCenterRecordButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
      child: Material(
        elevation: 8,
        shadowColor: Colors.amber.withOpacity(0.4),
        shape: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.amber, // Sunny color for Day Planning
                Colors.orangeAccent,
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                 HapticFeedback.mediumImpact();
                 Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DayPlannerScreen(),
                    ),
                 );
              },
              customBorder: const CircleBorder(),
              child: const Icon(
                Icons.wb_sunny_rounded,
                color: Colors.white,
                size: 28, // Slightly smaller icon inside circle
              ),
            ),
          ),
        ),
      )
        .animate()
        .scale(delay: 300.ms, duration: 600.ms, curve: Curves.elasticOut)
        .shimmer(delay: 900.ms, duration: 1500.ms, color: Colors.white.withOpacity(0.3)),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final tab = _tabs[index];
    final isActive = _currentIndex == index;
    
    return _InteractiveTabButton(
      onTap: () => _onTabTapped(index),
      isActive: isActive,
      icon: isActive ? tab.activeIcon : tab.icon,
      label: tab.label,
    );
  }
}

/// Interactive tab button with scale animation on tap
class _InteractiveTabButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;
  final IconData icon;
  final String label;

  const _InteractiveTabButton({
    required this.onTap,
    required this.isActive,
    required this.icon,
    required this.label,
  });

  @override
  State<_InteractiveTabButton> createState() => _InteractiveTabButtonState();
}

class _InteractiveTabButtonState extends State<_InteractiveTabButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSM),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                padding: const EdgeInsets.all(AppTheme.spacingXS),
                decoration: BoxDecoration(
                  gradient: widget.isActive
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.15),
                            AppTheme.primaryLight.withOpacity(0.1),
                          ],
                        )
                      : null,
                  color: widget.isActive
                      ? null
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  widget.icon,
                  color: widget.isActive
                      ? AppTheme.primaryColor
                      : (Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary),
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: widget.isActive ? 12 : 11,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isActive
                      ? AppTheme.primaryColor
                      : (Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkTextPrimary
                          : AppTheme.textPrimary),
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Navigation tab configuration
class NavigationTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;

  NavigationTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
}

/// Bottom sheet widget for create options
class _CreateOptionsBottomSheet extends StatelessWidget {
  final VoidCallback onCreateTask;
  final VoidCallback onCreateGoal;
  final VoidCallback onPlanDay;
  final VoidCallback onStartHandsFree;

  const _CreateOptionsBottomSheet({
    required this.onCreateTask,
    required this.onCreateGoal,
    required this.onPlanDay,
    required this.onStartHandsFree,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingLG),
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Create New',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              _CreateOptionTile(
                icon: Icons.task_rounded,
                title: 'Create Task',
                subtitle: 'Add a new reminder or task',
                color: AppTheme.primaryColor,
                onTap: onCreateTask,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              _CreateOptionTile(
                icon: Icons.flag_rounded,
                title: 'Create Goal',
                subtitle: 'Set a new long-term goal',
                color: AppTheme.primaryLight,
                onTap: onCreateGoal,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              _CreateOptionTile(
                icon: Icons.wb_sunny_rounded,
                title: 'Plan Task for the Day',
                subtitle: 'Structure your day with AI',
                color: Colors.amber,
                onTap: onPlanDay,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              _CreateOptionTile(
                icon: Icons.mic_rounded,
                title: 'Hands-Free Mode',
                subtitle: 'Voice-guided goal planning',
                color: Colors.purpleAccent,
                onTap: onStartHandsFree,
              ),
              const SizedBox(height: AppTheme.spacingMD),
            ],
          ),
        ),
      ),
    )
    .animate()
    .slideY(
      begin: 1,
      end: 0,
      duration: 300.ms,
      curve: Curves.easeOutCubic,
    )
    .fadeIn(duration: 300.ms);
  }
}

/// Individual option tile in the bottom sheet
class _CreateOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CreateOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkSurfaceElevated
                : AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppTheme.darkTextTertiary
                    : AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
