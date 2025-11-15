import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import 'skill_details_screen.dart';
import '../../data/models/skill.dart';

/// Skills screen showing all business skills with progress
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  @override
  void initState() {
    super.initState();
    // Load skills on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  Future<void> _createSkill() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Skill'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Skill name (e.g., Marketing, Sales)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        await context.read<GrowthProvider>().createSkill(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Skill created!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Skills'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _createSkill,
            tooltip: 'Create Skill',
          ),
        ],
      ),
      body: Consumer<GrowthProvider>(
        builder: (context, growthProvider, child) {
          if (growthProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final skills = growthProvider.skills;

          if (skills.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.track_changes_rounded,
                      size: 80,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    Text(
                      'No skills yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Create your first skill to start tracking progress',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    ElevatedButton.icon(
                      onPressed: _createSkill,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Skill'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => growthProvider.loadGrowthData(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                final reps = growthProvider.getRepsForSkill(skill.id);
                final streak = _calculateStreak(reps);

                return _buildSkillCard(context, skill, reps.length, streak);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkillCard(
    BuildContext context,
    Skill skill,
    int repCount,
    int streak,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        side: BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SkillDetailsScreen(skillId: skill.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              // Skill icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              // Skill info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.repeat_rounded, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '$repCount reps',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        if (streak > 0) ...[
                          const SizedBox(width: AppTheme.spacingMD),
                          Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '$streak-day streak',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateStreak(List reps) {
    if (reps.isEmpty) return 0;
    
    // Simple streak calculation: consecutive days with at least one rep
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    final repDates = reps.map((r) {
      final timestamp = r.timestamp as DateTime;
      return DateTime(timestamp.year, timestamp.month, timestamp.day);
    }).toSet();
    
    int streak = 0;
    DateTime currentDate = todayDate;
    
    if (!repDates.contains(todayDate)) {
      currentDate = todayDate.subtract(const Duration(days: 1));
    }
    
    while (repDates.contains(currentDate)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }
    
    return streak;
  }
}

