import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/growth_provider.dart';
import '../../data/models/skill.dart';
import '../theme/app_theme.dart';

/// Dropdown widget for selecting a skill to link to a reminder
class SkillSelectorDropdown extends StatelessWidget {
  final int? selectedSkillId;
  final Function(int?) onChanged;
  final bool required;

  const SkillSelectorDropdown({
    super.key,
    this.selectedSkillId,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<GrowthProvider>(
      builder: (context, growthProvider, child) {
        final skills = growthProvider.skills;

        if (skills.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: AppTheme.textSecondary),
                const SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    'No skills yet. Create one in the Skills tab.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return DropdownButtonFormField<int>(
          value: selectedSkillId,
          decoration: InputDecoration(
            labelText: required ? 'Skill *' : 'Link to Skill (Optional)',
            hintText: 'Select a skill',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            filled: true,
            fillColor: AppTheme.surfaceColor,
          ),
          items: [
            if (!required)
              DropdownMenuItem<int>(
                value: null,
                child: Text(
                  'None',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ...skills.map((skill) {
              return DropdownMenuItem<int>(
                value: skill.id,
                child: Text(skill.name),
              );
            }),
          ],
          onChanged: onChanged,
        );
      },
    );
  }
}

