import 'package:flutter/material.dart';
import 'dart:async';

import '../screens/onboarding_screen.dart';
import '../navigation/main_navigator.dart';
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
      await PermissionService().ensureNotificationPermission(context);
    });

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if this is first launch (simplified - use SharedPreferences in production)
    const isFirstLaunch = true; // Replace with actual check

    // Import MainNavigator instead of HomeScreen directly
    final nextScreen = isFirstLaunch 
        ? const OnboardingScreen() 
        : const MainNavigator();
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => nextScreen,
      ),
    );
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
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        size: 64,
                        color: Color(0xFF6366F1),
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
                      'Never forget what matters',
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
