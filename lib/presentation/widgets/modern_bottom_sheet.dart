import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// Modern bottom sheet with smooth animations and glassmorphism
class ModernBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool enableDrag = true,
    double? height,
    bool useGlassmorphism = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return showMaterialModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: height ?? MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          gradient: useGlassmorphism
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          const Color(0xFF1A1A1C),
                          const Color(0xFF161618),
                        ]
                      : [
                          Colors.white,
                          const Color(0xFFFAFBFC),
                        ],
                ),
          color: useGlassmorphism ? null : Colors.transparent,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXL),
          ),
        ),
        child: useGlassmorphism
            ? ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusXL),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: _buildContent(context, title, child, isDark),
                ),
              )
            : _buildContent(context, title, child, isDark),
      )
        .animate()
        .slideY(
          begin: 1,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        )
        .fadeIn(duration: 300.ms),
    );
  }

  static Widget _buildContent(
    BuildContext context,
    String? title,
    Widget child,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.only(top: AppTheme.spacingSM),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Divider(height: 1),
        ],
        Flexible(child: child),
      ],
    );
  }
}

