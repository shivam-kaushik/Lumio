import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../navigation/main_navigator.dart';
import '../providers/auth_provider.dart';
import '../theme/theme.dart';
import '../../core/services/permission_service.dart';

/// Splash screen shown on app launch
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    // After the first frame, ensure notification permission is requested and
    // show a prompt to open settings if the permission was denied.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final permissionService = PermissionService();
      
      // Request notification permission first
      await permissionService.ensureNotificationPermission(
        context,
        rationale: 'Notifications are required to deliver reminders. Please enable notifications in app settings.',
      );
      
      // Wait a bit before showing the next permission dialog to avoid overwhelming the user
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Then request exact alarm permission (Android only, but safe to call on iOS)
      await permissionService.ensureExactAlarmPermission(
        context,
        rationale: 'Exact alarms are needed for precise reminder delivery. Please enable "Alarms & reminders" in the app settings.',
      );
    });

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    
    // Wait for auth state to be determined
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Check authentication state
    if (authProvider.isAuthenticated) {
      // User is logged in, go to main app
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const MainNavigator(),
        ),
      );
    } else {
      // User is not logged in, check if this is first launch
      final prefs = await SharedPreferences.getInstance();
      final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

      if (!mounted) return;

      final nextScreen = onboardingComplete
          ? const LoginScreen()
          : const WelcomeScreen();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => nextScreen,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          'assets/icons/Lumio_logo.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback to icon if image not found
                            return const Icon(
                              Icons.notifications_active_rounded,
                              size: 64,
                              color: LumioColors.primary,
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // App Name
                    Text(
                      'Lumio',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Turning goals into actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
