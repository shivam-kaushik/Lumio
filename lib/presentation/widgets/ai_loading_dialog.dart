import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Modern, animated loading dialog for AI operations
class AILoadingDialog extends StatefulWidget {
  final String message;

  const AILoadingDialog({
    super.key,
    this.message = 'Generating with AI...',
  });

  @override
  State<AILoadingDialog> createState() => _AILoadingDialogState();
}

class _AILoadingDialogState extends State<AILoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.95),
              Colors.white.withOpacity(0.9),
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3D Animated Loader
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer rotating ring
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                AppTheme.primaryColor,
                                Colors.purple,
                                AppTheme.primaryColor,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Pulsing center
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      final scale = 0.5 + (_pulseController.value * 0.3);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppTheme.primaryColor,
                                AppTheme.primaryColor.withOpacity(0.6),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),

                  // Floating particles
                  ...List.generate(6, (index) {
                    final angle = (index * math.pi * 2) / 6;
                    return AnimatedBuilder(
                      animation: _particleController,
                      builder: (context, child) {
                        final progress = (_particleController.value + (index * 0.2)) % 1.0;
                        final radius = 40 + (progress * 30);
                        final opacity = 1.0 - progress;
                        return Positioned(
                          left: 60 + (math.cos(angle) * radius) - 3,
                          top: 60 + (math.sin(angle) * radius) - 3,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.purple,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.purple.withOpacity(0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Animated text
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            )
                .animate(onPlay: (controller) => controller.repeat())
                .fadeIn(duration: 600.ms)
                .then(delay: 400.ms)
                .fadeOut(duration: 600.ms),

            const SizedBox(height: 16),

            // Shimmer dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor,
                    ),
                  )
                      .animate(onPlay: (controller) => controller.repeat())
                      .fadeOut(delay: (index * 200).ms, duration: 600.ms)
                      .then()
                      .fadeIn(duration: 600.ms),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
