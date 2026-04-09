import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import 'goal_details_screen.dart';

/// Particle painter using Lumio amber tones
class _ParticlePainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;

  _ParticlePainter({
    required this.animationValue,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);

    for (int i = 0; i < 18; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final particleSize = 3.0 + (random.nextDouble() * 5);

      final progress = (animationValue + (i * 0.055)) % 1.0;
      final yOffset = -40 - (progress * size.height * 0.25);
      final opacity = ((1.0 - progress) * 0.25).clamp(0.0, 0.25);

      final paint = Paint()
        ..color = Color.lerp(primaryColor, secondaryColor, random.nextDouble())!
            .withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawCircle(
        Offset(startX, startY + yOffset),
        particleSize / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Goal creation screen — Lumio-themed
class AnimatedGoalCreationScreen extends StatefulWidget {
  const AnimatedGoalCreationScreen({super.key});

  @override
  State<AnimatedGoalCreationScreen> createState() => _AnimatedGoalCreationScreenState();
}

class _AnimatedGoalCreationScreenState extends State<AnimatedGoalCreationScreen>
    with TickerProviderStateMixin {
  final TextEditingController _goalController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _floatingController;
  late AnimationController _particleController;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _goalController.dispose();
    _focusNode.dispose();
    _floatingController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _createGoal() async {
    if (_goalController.text.trim().isEmpty) return;

    setState(() => _isCreating = true);

    try {
      HapticFeedback.mediumImpact();

      final growthProvider = context.read<GrowthProvider>();
      final goalName = _goalController.text.trim();

      final encodedName = Uri.encodeComponent(goalName);
      final imageUrl =
          'https://image.pollinations.ai/prompt/$encodedName?width=800&height=600&nologo=true';

      final goalId = await growthProvider.createGoal(goalName, imageUrl: imageUrl);

      if (mounted) {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 400));

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                GoalDetailsScreen(goalId: goalId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;
              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating goal: $e'),
            backgroundColor: LumioColors.error,
          ),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = LumioColors.background(context);
    final textPrimary = LumioColors.textPrimary(context);
    final textSecondary = LumioColors.textSecondary(context);
    final surfaceColor = LumioColors.surface(context);
    final borderColor = LumioColors.border(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle warm background tint
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  LumioColors.primary.withValues(alpha: isDark ? 0.06 : 0.04),
                  bgColor,
                  LumioColors.primary.withValues(alpha: isDark ? 0.03 : 0.02),
                ],
              ),
            ),
          ),

          // Ambient particles in Lumio amber
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              painter: _ParticlePainter(
                animationValue: _particleController.value,
                primaryColor: LumioColors.primary,
                secondaryColor: LumioColors.primaryHover,
              ),
              size: Size.infinite,
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(height: 8),

                        // Close button
                        Align(
                          alignment: Alignment.topRight,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor, width: 1),
                                boxShadow: LumioShadows.getSoft(context),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: textSecondary,
                                size: 18,
                              ),
                            ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 400.ms)
                            .scale(delay: 300.ms, duration: 400.ms),

                        const SizedBox(height: 32),

                        // Floating Lumio icon orb
                        AnimatedBuilder(
                          animation: _floatingController,
                          builder: (context, _) {
                            final offset =
                                math.sin(_floatingController.value * math.pi * 2) * 14;
                            return Transform.translate(
                              offset: Offset(0, offset),
                              child: Container(
                                width: 108,
                                height: 108,
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
                                      color: LumioColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 40,
                                      spreadRadius: 8,
                                      offset: const Offset(0, 16),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.flag_rounded,
                                  size: 52,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        )
                            .animate()
                            .fadeIn(duration: 600.ms)
                            .scale(duration: 600.ms, curve: Curves.elasticOut),

                        const SizedBox(height: 40),

                        // Title
                        Text(
                          "What's your goal?",
                          style: LumioTypography.headlineLarge.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                          textAlign: TextAlign.center,
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 600.ms)
                            .slideY(
                              begin: 0.3,
                              end: 0,
                              delay: 200.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutCubic,
                            ),

                        const SizedBox(height: 10),

                        Text(
                          'Dream big, start now',
                          style: LumioTypography.bodyLarge.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        )
                            .animate()
                            .fadeIn(delay: 350.ms, duration: 600.ms)
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 350.ms,
                              duration: 600.ms,
                            ),

                        const SizedBox(height: 40),

                        // Input field
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: LumioColors.primary.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: LumioColors.primary.withValues(alpha: 0.08),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                              ...LumioShadows.getSoft(context),
                            ],
                          ),
                          child: TextField(
                            controller: _goalController,
                            focusNode: _focusNode,
                            enabled: !_isCreating,
                            decoration: InputDecoration(
                              hintText: 'e.g., Start a successful business',
                              hintStyle: LumioTypography.bodyLarge.copyWith(
                                color: LumioColors.textTertiary(context),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 22,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(left: 16, right: 10),
                                child: Icon(
                                  Icons.emoji_events_rounded,
                                  color: LumioColors.primary,
                                  size: 26,
                                ),
                              ),
                            ),
                            style: LumioTypography.bodyLarge.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            maxLines: 2,
                            minLines: 1,
                            onSubmitted: (_) => _createGoal(),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 500.ms, duration: 600.ms)
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 500.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutCubic,
                            ),

                        const SizedBox(height: 40),

                        // Create button
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _isCreating ? null : _createGoal,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LumioColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  LumioColors.primary.withValues(alpha: 0.35),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: _isCreating
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        'Creating your goal...',
                                        style: LumioTypography.labelLarge.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.rocket_launch_rounded,
                                        size: 24,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Create Goal',
                                        style: LumioTypography.labelLarge.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 650.ms, duration: 600.ms)
                            .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 650.ms,
                              duration: 600.ms,
                              curve: Curves.easeOutCubic,
                            ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
