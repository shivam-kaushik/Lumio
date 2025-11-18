import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Placeholder sheet since quick rep logging (skills) has been removed.
class QuickLogSheet extends StatelessWidget {
  const QuickLogSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLG),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppTheme.spacingLG),
                decoration: BoxDecoration(
                  color: AppTheme.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Icon(
                Icons.info_outline_rounded,
                size: 48,
                color: Colors.orange,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                'Quick Log Unavailable',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                'Skill tracking and rep logging have been removed from Lumio. '
                'You can still plan and complete goal tasks from the planner.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


