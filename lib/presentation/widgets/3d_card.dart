import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

/// 3D card with rotation and flip animations
/// Used for skill details, milestone cards, etc.
class Card3D extends StatefulWidget {
  final Widget front;
  final Widget? back;
  final VoidCallback? onTap;
  final double tiltAngle; // Degrees to tilt (e.g., 8.0)
  final bool enableFlip;
  final bool enableTilt;

  const Card3D({
    super.key,
    required this.front,
    this.back,
    this.onTap,
    this.tiltAngle = 8.0,
    this.enableFlip = false,
    this.enableTilt = true,
  });

  @override
  State<Card3D> createState() => _Card3DState();
}

class _Card3DState extends State<Card3D>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  bool _isFlipped = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.enableFlip && widget.back != null) {
      setState(() {
        _isFlipped = !_isFlipped;
      });
      if (_isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _handleTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: widget.enableTilt && _isPressed
            ? (() {
                final matrix = Matrix4.identity();
                matrix.setEntry(3, 2, 0.001);
                matrix.rotateX(-widget.tiltAngle * math.pi / 180);
                return matrix;
              })()
            : null,
        child: AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            final angle = _rotationAnimation.value * math.pi;
            final isFlipped = _isFlipped;

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(isFlipped ? angle : 0),
              child: isFlipped && widget.back != null
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(math.pi),
                      child: _buildCard(context, widget.back!, isDark),
                    )
                  : _buildCard(context, widget.front, isDark),
            );
          },
        ),
      )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutCubic),
    );
  }

  Widget _buildCard(BuildContext context, Widget content, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.getCardGradient(isDark: isDark),
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2A2A2C).withOpacity(0.5)
              : AppTheme.borderColor,
          width: 1,
        ),
        boxShadow: _isPressed
            ? []
            : AppTheme.getElevationShadow(2, isDark: isDark),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: content,
      ),
    );
  }
}

