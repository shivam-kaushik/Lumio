import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../screens/home_screen.dart';
import '../screens/goals_screen.dart';
import '../screens/subtasks_calendar_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/add_reminder_screen.dart';
import '../theme/app_theme.dart';

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

  // Tab pages (MVP: Simplified navigation)
  final List<Widget> _pages = [
    const HomeScreen(), // Tasks list
    const GoalsScreen(), // Goals
    const SubtasksCalendarScreen(), // Calendar (showing subtasks)
    const SettingsScreen(), // Settings
  ];

  // Tab configurations (MVP: Simplified)
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
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
      badge: null,
    ),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddReminderScreen(),
      ),
    );
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
      floatingActionButton: _buildFloatingActionButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      extendBody: true,
    );
  }

  /// Build floating action button for quick actions with animations
  Widget _buildFloatingActionButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 75), // Position above navigation bar
      child: Material(
        elevation: 8,
        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
        shape: const CircleBorder(),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryLight,
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _onRecordButtonPressed,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 64,
                height: 64,
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ),
      )
        .animate()
        .scale(delay: 500.ms, duration: 600.ms, curve: Curves.elasticOut)
        .shimmer(delay: 1100.ms, duration: 2000.ms, color: Colors.white.withOpacity(0.4)),
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

  /// Build center record button (Strava-style) with animations
  Widget _buildCenterRecordButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXS),
      child: Material(
        elevation: 8,
        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
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
                AppTheme.primaryColor,
                AppTheme.primaryLight,
              ],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _onRecordButtonPressed,
              customBorder: const CircleBorder(),
              child: const Icon(
                Icons.fiber_manual_record_rounded,
                color: Colors.white,
                size: 28,
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
                          ? AppTheme.darkTextPrimary.withOpacity(0.85)
                          : AppTheme.textPrimary.withOpacity(0.65)),
                  size: 26,
                )
                  .animate(target: widget.isActive ? 1 : 0)
                  .scale(duration: 200.ms, curve: Curves.easeOutCubic)
                  .then()
                  .shimmer(
                    duration: 1000.ms,
                    color: AppTheme.primaryColor.withOpacity(0.3),
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
                          ? AppTheme.darkTextPrimary.withOpacity(0.7)
                          : AppTheme.textPrimary.withOpacity(0.7)),
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

