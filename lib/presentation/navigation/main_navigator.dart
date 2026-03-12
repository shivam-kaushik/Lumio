import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/subtasks_calendar_screen.dart';
import '../screens/profile_screen.dart';

import '../screens/goal_planning_screen.dart';
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import '../screens/chat_screen.dart';
import '../providers/reminder_provider.dart';
import '../screens/day_planner_screen.dart';
import '../../data/models/goal.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/models/goal_task.dart';
import '../widgets/quick_task_input_sheet.dart';
import '../../data/models/reminder.dart';
import '../widgets/avatar_widget.dart';

/// Main navigation wrapper with bottom tab bar
/// Provides smooth transitions and consistent navigation structure
/// Features a floating action button (FAB) similar to Daylio app design
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => MainNavigatorState();
  
  static MainNavigatorState of(BuildContext context) {
    return context.findAncestorStateOfType<MainNavigatorState>()!;
  }
}

class MainNavigatorState extends State<MainNavigator>
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
    const ProfileScreen(), // Profile (Stitch style)
    const DayPlannerScreen(), // Day Planner
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize navigator keys for each tab
    _navigatorKeys = List.generate(
      5, // 5 pages total
      (index) => GlobalKey<NavigatorState>(),
    );
    
    // Initialize fade controllers for smooth transitions
    _fadeControllers = List.generate(
      5, // 4 tabs + 1 extra page (Day Planner)
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

  void switchToDayPlanner() {
      // Public method to switch to Day Planner tab
      if (_currentIndex != 4) {
          setState(() {
            _fadeControllers[_currentIndex].reverse();
            _currentIndex = 4; // Index of DayPlannerScreen
            _fadeControllers[_currentIndex].forward();
          });
      }
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
          setState(() {
            _fadeControllers[_currentIndex].reverse();
            _currentIndex = 4; // Index of DayPlannerScreen
            _fadeControllers[_currentIndex].forward();
          });
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
      backgroundColor: LumioColors.background(context),
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
                      backgroundColor: LumioColors.primary,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.bottomNav,
        boxShadow: LumioShadows.getNav(context),
        border: Border(
          top: BorderSide(
            color: LumioColors.border(context).withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: LumioSpacing.md,
            right: LumioSpacing.md,
            top: LumioSpacing.sm,
            bottom: LumioSpacing.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // First 2 tabs
              Expanded(child: _buildNavItem(context, 0)),
              Expanded(child: _buildNavItem(context, 1)),

              // Center FAB (elevated above nav bar)
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

  /// Build center FAB button (Stitch style - elevated above nav bar)
  Widget _buildCenterRecordButton(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -16), // Elevate above nav bar
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: LumioColors.primary,
          border: Border.all(
            color: LumioColors.background(context),
            width: 4,
          ),
          boxShadow: LumioShadows.fab,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              // Switch to Day Planner Mode directly
              setState(() {
                _fadeControllers[_currentIndex].reverse();
                _currentIndex = 4; // Index of DayPlannerScreen
                _fadeControllers[_currentIndex].forward();
              });
            },
            customBorder: const CircleBorder(),
            child: const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      )
          .animate()
          .scale(delay: 300.ms, duration: 600.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    final tab = _tabs[index];
    final isActive = _currentIndex == index;
    
    // Check for Avatar override on Account tab (index 3)
    Widget? overrideChild;
    if (index == 3) {
      final provider = Provider.of<GrowthProvider>(context);
      if (provider.showAvatarInProfile) {
        overrideChild = AvatarWidget(
          config: provider.avatarConfig,
          size: 26,
        );
      }
    }

    return _InteractiveTabButton(
      onTap: () => _onTabTapped(index),
      isActive: isActive,
      icon: isActive ? tab.activeIcon : tab.icon,
      label: tab.label,
      child: overrideChild,
    );
  }
}

/// Interactive tab button with scale animation on tap
class _InteractiveTabButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isActive;
  final IconData icon;
  final String label;
  final Widget? child; // NEW

  const _InteractiveTabButton({
    required this.onTap,
    required this.isActive,
    required this.icon,
    required this.label,
    this.child,
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
          padding: EdgeInsets.symmetric(vertical: LumioSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Active indicator background (Stitch style)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                width: 48,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? LumioColors.primaryLight
                      : Colors.transparent,
                  borderRadius: LumioRadius.radiusFull,
                ),
                child: Center(
                  child: widget.child ??
                      Icon(
                        widget.icon,
                        color: widget.isActive
                            ? LumioColors.primary
                            : LumioColors.textSecondary(context),
                        size: 24,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: (widget.isActive
                        ? LumioTypography.navLabelActive
                        : LumioTypography.navLabel)
                    .copyWith(
                  color: widget.isActive
                      ? LumioColors.primary
                      : LumioColors.textSecondary(context),
                ),
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
    return Container(
      decoration: BoxDecoration(
        color: LumioColors.surface(context),
        borderRadius: LumioRadius.bottomSheet,
      ),
      child: SafeArea(
        child: Padding(
          padding: LumioSpacing.paddingLG,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: LumioSpacing.lg),
                  decoration: BoxDecoration(
                    color: LumioColors.border(context),
                    borderRadius: LumioRadius.radiusFull,
                  ),
                ),
              ),
              Text(
                'Create New',
                style: LumioTypography.headlineSmall.copyWith(
                  color: LumioColors.textPrimary(context),
                ),
              ),
              SizedBox(height: LumioSpacing.md),
              _CreateOptionTile(
                icon: Icons.task_rounded,
                title: 'Create Task',
                subtitle: 'Add a new reminder or task',
                color: LumioColors.primary,
                onTap: onCreateTask,
              ),
              SizedBox(height: LumioSpacing.sm),
              _CreateOptionTile(
                icon: Icons.flag_rounded,
                title: 'Create Goal',
                subtitle: 'Set a new long-term goal',
                color: LumioColors.categoryBusiness,
                onTap: onCreateGoal,
              ),
              SizedBox(height: LumioSpacing.sm),
              _CreateOptionTile(
                icon: Icons.wb_sunny_rounded,
                title: 'Plan Task for the Day',
                subtitle: 'Structure your day with AI',
                color: LumioColors.warning,
                onTap: onPlanDay,
              ),
              SizedBox(height: LumioSpacing.sm),
              _CreateOptionTile(
                icon: Icons.mic_rounded,
                title: 'Hands-Free Mode',
                subtitle: 'Voice-guided goal planning',
                color: LumioColors.categoryPersonal,
                onTap: onStartHandsFree,
              ),
              SizedBox(height: LumioSpacing.md),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: LumioRadius.radiusMD,
        child: Container(
          padding: LumioSpacing.paddingMD,
          decoration: BoxDecoration(
            color: LumioColors.background(context),
            borderRadius: LumioRadius.radiusMD,
            border: Border.all(
              color: LumioColors.border(context),
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
                  borderRadius: LumioRadius.radiusMD,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              SizedBox(width: LumioSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: LumioTypography.titleSmall.copyWith(
                        color: LumioColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: LumioTypography.bodySmall.copyWith(
                        color: LumioColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: LumioColors.textTertiary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
