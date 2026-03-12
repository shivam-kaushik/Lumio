import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// A selectable persona card for onboarding
/// Based on Stitch AI welcome screen mockup
class PersonaCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const PersonaCard({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: LumioSpacing.paddingMD,
        decoration: BoxDecoration(
          color: LumioColors.surface(context),
          borderRadius: LumioRadius.radiusLG,
          border: Border.all(
            color: isSelected ? LumioColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: LumioColors.primary.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : LumioShadows.getSoft(context),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Selection indicator dot
            if (isSelected)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: LumioColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),

            // Icon container
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? LumioColors.primary
                    : LumioColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? Colors.white : LumioColors.primary,
              ),
            ),

            LumioSpacing.verticalGap12,

            // Label
            Text(
              label,
              style: LumioTypography.titleSmall.copyWith(
                color: LumioColors.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
