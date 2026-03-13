import 'package:flutter/material.dart';
import '../theme/theme.dart';

/// Legacy screen retained for navigation compatibility.
/// Rep logging has been removed now that skills are deprecated.
class AddRepScreen extends StatelessWidget {
  const AddRepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Rep Logging Removed'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 64,
                color: Colors.orange,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text(
                'Skill-based rep logging is no longer available.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                'Focus on creating clear tasks inside each goal and mark them as '
                'completed from the planner or calendar views.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingXL),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

