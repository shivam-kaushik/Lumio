import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Placeholder screen while legacy skill tracking is being redesigned.
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Skills'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology_alt_rounded,
                size: 80,
                color: AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text(
                'Skills tracking is evolving',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                'We\'ve migrated growth tracking to goals, tasks, and phases. '
                'A refreshed skills experience will ship soon.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

