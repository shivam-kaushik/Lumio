import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Animated progress bar with modern styling
/// Used for skill progress, task completion, goal progress
class AnimatedProgressBar extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final String? label;
  final Color? progressColor;
  final Color? backgroundColor;
  final double height;
  final bool showPercentage;
  final bool animate;

  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.label,
    this.progressColor,
    this.backgroundColor,
    this.height = 8.0,
    this.showPercentage = true,
    this.animate = true,
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    
    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != oldWidget.progress && widget.animate) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final progressColor = widget.progressColor ?? 
                         AppTheme.getNeonAccent(type: 'blue');
    final backgroundColor = widget.backgroundColor ??
                           (isDark
                             ? Colors.white.withOpacity(0.1)
                             : Colors.black.withOpacity(0.05));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null || widget.showPercentage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.label != null)
                Text(
                  widget.label!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (widget.showPercentage)
                Text(
                  '${(widget.progress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: progressColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSM),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(widget.height / 2),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final animatedProgress = widget.animate
                  ? widget.progress * _animation.value
                  : widget.progress;
              
              return LinearPercentIndicator(
                lineHeight: widget.height,
                percent: animatedProgress.clamp(0.0, 1.0),
                backgroundColor: backgroundColor,
                progressColor: progressColor,
                barRadius: Radius.circular(widget.height / 2),
                animation: false, // We handle animation ourselves
                animateFromLastPercent: false,
              );
            },
          ),
        )
          .animate()
          .fadeIn(duration: 500.ms)
          .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
          .scale(begin: const Offset(0.95, 1.0), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}

