import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// Lumio-themed animated loading dialog for AI operations
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
  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2D2418) : const Color(0xFFF5F0EB);
    final textColor = isDark ? Colors.white : const Color(0xFF1B150D);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: LumioColors.primary.withValues(alpha: 0.25),
              blurRadius: 50,
              spreadRadius: 8,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: LumioColors.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lumio amber ring animation
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer rotating amber arc
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, _) => Transform.rotate(
                      angle: _rotationController.value * 2 * math.pi,
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              LumioColors.primary,
                              LumioColors.primaryHover,
                              LumioColors.primary.withValues(alpha: 0.1),
                              LumioColors.primary,
                            ],
                            stops: const [0.0, 0.3, 0.7, 1.0],
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bgColor,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Counter-rotating inner ring
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, _) => Transform.rotate(
                      angle: -_rotationController.value * 2 * math.pi * 0.6,
                      child: Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: LumioColors.primary.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Pulsing center orb
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, _) {
                      final scale = 0.88 + (_pulseController.value * 0.14);
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                LumioColors.primary,
                                LumioColors.primaryPressed,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: LumioColors.primary.withValues(alpha: 0.45),
                                blurRadius: 18,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      );
                    },
                  ),

                  // Orbiting warm dots
                  ...List.generate(5, (i) {
                    final angle = (i * math.pi * 2) / 5;
                    return AnimatedBuilder(
                      animation: _orbController,
                      builder: (context, _) {
                        final progress = (_orbController.value + (i * 0.22)) % 1.0;
                        final radius = 48.0 + (progress * 12);
                        final opacity = (1.0 - progress).clamp(0.0, 1.0);
                        final size = 5.0 + progress * 2;
                        return Positioned(
                          left: 55 + math.cos(angle + _orbController.value * math.pi * 2) * radius - size / 2,
                          top: 55 + math.sin(angle + _orbController.value * math.pi * 2) * radius - size / 2,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i.isEven
                                    ? LumioColors.primary
                                    : LumioColors.primaryHover,
                                boxShadow: [
                                  BoxShadow(
                                    color: LumioColors.primary.withValues(alpha: 0.4),
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

            const SizedBox(height: 28),

            // Message with fade loop
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            )
                .animate(onPlay: (c) => c.repeat())
                .fadeIn(duration: 700.ms)
                .then(delay: 600.ms)
                .fadeOut(duration: 500.ms),

            const SizedBox(height: 16),

            // Lumio amber pulsing dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: LumioColors.primary,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat())
                    .scaleXY(
                      begin: 0.6,
                      end: 1.0,
                      delay: (i * 160).ms,
                      duration: 480.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .scaleXY(begin: 1.0, end: 0.6, duration: 480.ms, curve: Curves.easeInOut);
              }),
            ),
          ],
        ),
      ),
    );
  }
}
