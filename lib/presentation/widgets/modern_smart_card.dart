import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Modern smart card with neumorphic/glassmorphism effects
/// Used for roadmaps, skills, tasks, stats
class ModernSmartCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final bool useGradient;
  final bool useGlassmorphism;
  final int elevationLevel;
  final Color? borderColor;
  final double? borderRadius;

  const ModernSmartCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.useGradient = true,
    this.useGlassmorphism = false,
    this.elevationLevel = 2,
    this.borderColor,
    this.borderRadius,
  });

  @override
  State<ModernSmartCard> createState() => _ModernSmartCardState();
}

class _ModernSmartCardState extends State<ModernSmartCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: widget.onTap != null ? (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      } : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        padding: widget.padding ?? const EdgeInsets.all(AppTheme.spacingMD),
        margin: widget.margin ?? const EdgeInsets.only(bottom: AppTheme.spacingMD),
        decoration: BoxDecoration(
          gradient: widget.useGradient ? AppTheme.getCardGradient(isDark: isDark) : null,
          color: widget.useGradient ? null : (isDark ? const Color(0xFF0F0F0F) : Colors.white),
          borderRadius: BorderRadius.circular(
            widget.borderRadius ?? AppTheme.radiusLG,
          ),
          border: Border.all(
            color: widget.borderColor ?? 
                   (isDark 
                     ? const Color(0xFF2A2A2A).withOpacity(0.6)
                     : AppTheme.borderColor),
            width: 1,
          ),
          boxShadow: _isPressed
              ? [] // No shadow when pressed
              : AppTheme.getElevationShadow(
                  widget.elevationLevel,
                  isDark: isDark,
                ),
        ),
        child: widget.useGlassmorphism
            ? ClipRRect(
                borderRadius: BorderRadius.circular(
                  widget.borderRadius ?? AppTheme.radiusLG,
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: widget.child,
                ),
              )
            : widget.child,
      )
        .animate()
        .fadeIn(duration: 500.ms, curve: Curves.easeOut)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.0, 1.0), duration: 500.ms, curve: Curves.easeOutCubic),
    );
  }
}

