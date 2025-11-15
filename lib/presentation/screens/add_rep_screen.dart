import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/skill_selector_dropdown.dart';

/// Screen for manually logging a skill rep
class AddRepScreen extends StatefulWidget {
  const AddRepScreen({super.key});

  @override
  State<AddRepScreen> createState() => _AddRepScreenState();
}

class _AddRepScreenState extends State<AddRepScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _durationController = TextEditingController();
  int? _selectedSkillId;
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _saveRep() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSkillId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a skill')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final durationMinutes = _durationController.text.isNotEmpty
          ? int.tryParse(_durationController.text)
          : null;

      await context.read<GrowthProvider>().addRep(
            _selectedSkillId!,
            _notesController.text,
            durationMinutes: durationMinutes,
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rep logged!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Log Rep'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spacingMD),
              
              // Skill selector
              SkillSelectorDropdown(
                selectedSkillId: _selectedSkillId,
                onChanged: (skillId) {
                  setState(() => _selectedSkillId = skillId);
                },
                required: true,
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // Notes field
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'What did you do? *',
                  hintText: 'Describe what you practiced or worked on',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe what you did';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppTheme.spacingLG),

              // Duration field (optional)
              TextFormField(
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: 'Duration (minutes)',
                  hintText: 'Optional',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final duration = int.tryParse(value);
                    if (duration == null || duration < 0) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppTheme.spacingXL),

              // Save button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveRep,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Log Rep'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

