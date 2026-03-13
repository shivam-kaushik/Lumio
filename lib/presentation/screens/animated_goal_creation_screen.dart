import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import '../../data/models/goal.dart';
import 'goal_details_screen.dart';

/// Particle painter that renders animated particles without layout issues
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
    final random = math.Random(42); // Fixed seed for consistent positions

    for (int i = 0; i < 20; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = random.nextDouble() * size.height;
      final particleSize = 4 + (random.nextDouble() * 6);

      final progress = (animationValue + (i * 0.05)) % 1.0;
      final yOffset = -50 - (progress * size.height * 0.3);
      final opacity = (1.0 - progress).clamp(0.0, 0.3);

      final paint = Paint()
        ..color = Color.lerp(primaryColor, secondaryColor, random.nextDouble())!
            .withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

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

/// Beautiful 3D animated goal creation experience
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

    // Auto-focus after animation
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _focusNode.requestFocus();
      }
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

      // Generate image URL
      final encodedName = Uri.encodeComponent(goalName);
      final imageUrl = 'https://image.pollinations.ai/prompt/$encodedName?width=800&height=600&nologo=true';

      // Create goal
      final goalId = await growthProvider.createGoal(
        goalName,
        imageUrl: imageUrl,
      );

      if (mounted) {
        // Navigate to goal details screen with celebration animation
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 500));

        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                GoalDetailsScreen(goalId: goalId),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(
                position: animation.drive(tween),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
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
            backgroundColor: AppTheme.errorColor,
          ),
        );
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor.withValues(alpha: 0.1),
                  Colors.purple.withValues(alpha: 0.05),
                  Colors.blue.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),

          // Animated particles using CustomPainter (no layout issues)
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                painter: _ParticlePainter(
                  animationValue: _particleController.value,
                  primaryColor: AppTheme.primaryColor,
                  secondaryColor: Colors.purple,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                  // Close button
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 400.ms)
                      .scale(delay: 400.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // 3D Floating Icon
                  AnimatedBuilder(
                    animation: _floatingController,
                    builder: (context, child) {
                      final offset = math.sin(_floatingController.value * math.pi * 2) * 20;
                      return Transform.translate(
                        offset: Offset(0, offset),
                        child: Transform.rotate(
                          angle: math.sin(_floatingController.value * math.pi * 2) * 0.1,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.primaryColor,
                                  Colors.purple,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.flag_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(duration: 600.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 48),

                  // Animated title
                  Text(
                    'What\'s your goal?',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            Colors.purple,
                          ],
                        ).createShader(const Rect.fromLTWH(0.0, 0.0, 300.0, 70.0)),
                      letterSpacing: -1,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, delay: 200.ms, duration: 600.ms, curve: Curves.easeOutCubic),

                  const SizedBox(height: 16),

                  Text(
                    'Dream big, start now',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 600.ms),

                  const SizedBox(height: 48),

                  // Glassmorphic input field
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0.7),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _goalController,
                      focusNode: _focusNode,
                      enabled: !_isCreating,
                      decoration: InputDecoration(
                        hintText: 'e.g., Start a successful business',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 8),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            color: AppTheme.primaryColor,
                            size: 28,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      minLines: 1,
                      onSubmitted: (_) => _createGoal(),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0, delay: 600.ms, duration: 600.ms, curve: Curves.easeOutCubic)
                      .shimmer(delay: 1200.ms, duration: 2000.ms, color: AppTheme.primaryColor.withValues(alpha: 0.1)),

                  const SizedBox(height: 48),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createGoal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: 0,
                        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isCreating
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Text(
                                  'Creating your goal...',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.rocket_launch_rounded, size: 28),
                                SizedBox(width: 12),
                                Text(
                                  'Create Goal',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 800.ms, duration: 600.ms)
                      .slideY(begin: 0.2, end: 0, delay: 800.ms, duration: 600.ms, curve: Curves.easeOutCubic)
                      .shimmer(delay: 1400.ms, duration: 2000.ms, color: Colors.white.withValues(alpha: 0.3)),

                  const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
