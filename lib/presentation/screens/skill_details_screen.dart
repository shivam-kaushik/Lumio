import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../../data/models/skill.dart';
import '../../data/models/rep.dart';

/// Skill details screen showing rep history and progress
class SkillDetailsScreen extends StatefulWidget {
  final int skillId;

  const SkillDetailsScreen({super.key, required this.skillId});

  @override
  State<SkillDetailsScreen> createState() => _SkillDetailsScreenState();
}

class _SkillDetailsScreenState extends State<SkillDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  Future<void> _deleteSkill() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Skill?'),
        content: const Text('This will delete the skill and all its reps. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<GrowthProvider>().deleteSkill(widget.skillId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Skill deleted')),
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
        title: const Text('Skill Details'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _deleteSkill,
            tooltip: 'Delete Skill',
          ),
        ],
      ),
      body: Consumer<GrowthProvider>(
        builder: (context, growthProvider, child) {
          final skill = growthProvider.skills.firstWhere(
            (s) => s.id == widget.skillId,
            orElse: () => throw Exception('Skill not found'),
          );
          final reps = growthProvider.getRepsForSkill(widget.skillId);
          final streak = _calculateStreak(reps);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Skill header
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    side: BorderSide(color: AppTheme.borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingLG),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.track_changes_rounded,
                            color: AppTheme.primaryColor,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingMD),
                        Text(
                          skill.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spacingLG),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Total Reps',
                        '${reps.length}',
                        Icons.repeat_rounded,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        'Current Streak',
                        '$streak days',
                        Icons.local_fire_department_rounded,
                        color: streak > 0 ? Colors.orange : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacingLG),

                // Rep history
                Text(
                  'Rep History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppTheme.spacingMD),

                if (reps.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingXL),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 48,
                            color: AppTheme.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            'No reps yet',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: AppTheme.spacingSM),
                          Text(
                            'Complete reminders linked to this skill to log reps automatically',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...reps.map((rep) => _buildRepCard(context, rep)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        child: Column(
          children: [
            Icon(icon, color: color ?? AppTheme.primaryColor, size: 24),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepCard(BuildContext context, Rep rep) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: BorderSide(color: AppTheme.borderColor, width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(rep.notes),
        subtitle: Text(dateFormat.format(rep.timestamp)),
        trailing: rep.durationMinutes != null
            ? Text(
                '${rep.durationMinutes} min',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              )
            : null,
      ),
    );
  }

  int _calculateStreak(List<Rep> reps) {
    if (reps.isEmpty) return 0;
    
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    final repDates = reps.map((r) {
      return DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day);
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

