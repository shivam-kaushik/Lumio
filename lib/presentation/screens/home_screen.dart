import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/reminder_provider.dart';
import '../providers/growth_provider.dart';
import '../widgets/context_group_card.dart';
import '../widgets/smart_reminder_dialog.dart';
import '../theme/app_theme.dart';
import 'add_reminder_screen.dart';
import 'ai_chat_screen.dart';
import '../../data/models/reminder.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/services/home_detection_service.dart';

/// Premium home screen with minimal, elegant design
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Position? _currentPosition;
  String? _currentActivity;
  bool _hideCompleted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderProvider>().loadReminders();
      context.read<GrowthProvider>().loadGrowthData();
      _updateContext();
    });
  }

  Future<void> _updateContext() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.whileInUse ||
          hasPermission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        setState(() {
          _currentPosition = position;
        });
      }

      final homeService = HomeDetectionService();
    } catch (e) {
      debugPrint('Error updating context: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // No Scaffold here - MainNavigator provides it
    return SafeArea(
      bottom: false, // MainNavigator handles bottom safe area
      child: Column(
        children: [
          // Premium header
          _buildPremiumHeader(context, isDark),
          
          // Main content
          Expanded(
            child: Consumer<ReminderProvider>(
                builder: (context, reminderProvider, child) {
                  if (reminderProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (reminderProvider.error != null) {
                    return _buildErrorState(context, reminderProvider);
                  }

                  if (reminderProvider.reminders.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final visibleReminders = reminderProvider.reminders;
                  
                  return Consumer<GrowthProvider>(
                    builder: (context, growthProvider, _) {
                      // Group tasks by goals
                      final groups = _groupTasksByGoals(
                        visibleReminders,
                        growthProvider,
                      );

                      if (groups.isEmpty) {
                        return _buildEmptyState(context);
                      }

                      return RefreshIndicator(
                        onRefresh: () async {
                          await reminderProvider.loadReminders();
                          await growthProvider.loadGrowthData();
                          await _updateContext();
                        },
                        child: CustomScrollView(
                          slivers: [
                            // Stats header (optional)
                            SliverToBoxAdapter(
                              child: _buildStatsHeader(context, reminderProvider),
                            ),
                            
                            // Task groups by goals
                            ...groups.entries.map((entry) {
                              return SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppTheme.spacingMD,
                                  0,
                                  AppTheme.spacingMD,
                                  AppTheme.spacingMD,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: ContextGroupCard(
                                    contextTitle: entry.key,
                                    reminders: entry.value,
                                    contextIcon: entry.key == 'General Tasks' ? null : '🎯',
                                    currentPosition: _currentPosition,
                                    onReminderTap: (reminder) async {
                                      final result = await showDialog<Reminder>(
                                        context: context,
                                        builder: (context) => SmartReminderDialog(
                                          reminder: reminder,
                                        ),
                                      );
                                      if (result != null && mounted) {
                                        reminderProvider.updateReminder(result);
                                      }
                                    },
                                    onToggle: (id, enabled) {
                                      reminderProvider.toggleReminder(id, enabled);
                                    },
                                    onDelete: (id) {
                                      reminderProvider.deleteReminder(id);
                                    },
                                  ),
                                ),
                              );
                            }),
                        
                            // Bottom padding above bottom navigation bar
                            const SliverPadding(
                              padding: EdgeInsets.only(bottom: 120),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
  }

  /// Group tasks by goals (via skill linkage)
  Map<String, List<Reminder>> _groupTasksByGoals(
    List<Reminder> reminders,
    GrowthProvider growthProvider,
  ) {
    final groups = <String, List<Reminder>>{};
    
    debugPrint('🔍 Categorizing ${reminders.length} reminders...');
    debugPrint('📊 Available skills: ${growthProvider.skills.length}');
    debugPrint('📊 Available goals: ${growthProvider.goals.length}');
    
    // Log all skills and their goalIds
    for (var skill in growthProvider.skills) {
      debugPrint('  Skill: ${skill.name} (id: ${skill.id}, goalId: ${skill.goalId})');
    }
    
    // Log all goals
    for (var goal in growthProvider.goals) {
      debugPrint('  Goal: ${goal.name} (id: ${goal.id})');
    }
    
    // Ensure we have skills and goals loaded
    if (growthProvider.skills.isEmpty && growthProvider.goals.isEmpty) {
      debugPrint('⚠️ No growth data available - putting all in General Tasks');
      // If no growth data, put everything in General Tasks
      for (var reminder in reminders) {
        groups.putIfAbsent('General Tasks', () => []).add(reminder);
      }
      return groups;
    }
    
    for (var reminder in reminders) {
      String groupName = 'General Tasks';
      
      debugPrint('🔍 Processing reminder: "${reminder.text}" (linkedGoalId: ${reminder.linkedGoalId}, linkedSkillId: ${reminder.linkedSkillId})');
      
      // Priority 1: Use linkedGoalId if available (direct link)
      if (reminder.linkedGoalId != null) {
        try {
          final matchingGoals = growthProvider.goals.where(
            (g) => g.id == reminder.linkedGoalId,
          );
          
          if (matchingGoals.isNotEmpty) {
            groupName = matchingGoals.first.name;
            debugPrint('  ✅ Task "${reminder.text}" categorized under goal (via linkedGoalId): $groupName');
          } else {
            debugPrint('  ⚠️ Goal not found for linkedGoalId: ${reminder.linkedGoalId}');
            debugPrint('  Available goal IDs: ${growthProvider.goals.map((g) => g.id).join(", ")}');
          }
        } catch (e) {
          debugPrint('  ❌ Error categorizing task via linkedGoalId: $e');
        }
      }
      // Priority 2: Fallback to skill-based lookup if no direct goal link
      else if (reminder.linkedSkillId != null) {
        try {
          // Find the skill
          final matchingSkills = growthProvider.skills.where(
            (s) => s.id == reminder.linkedSkillId,
          );
          
          if (matchingSkills.isNotEmpty) {
            final skill = matchingSkills.first;
            debugPrint('  ✅ Found skill: ${skill.name} (id: ${skill.id}, goalId: ${skill.goalId})');
            
            // Find the goal for this skill
            if (skill.goalId != null) {
              final matchingGoals = growthProvider.goals.where(
                (g) => g.id == skill.goalId,
              );
              
              if (matchingGoals.isNotEmpty) {
                groupName = matchingGoals.first.name;
                debugPrint('  ✅ Task "${reminder.text}" categorized under goal (via skill): $groupName');
              } else {
                debugPrint('  ⚠️ Goal not found for skill ${skill.id} (goalId: ${skill.goalId})');
                debugPrint('  Available goal IDs: ${growthProvider.goals.map((g) => g.id).join(", ")}');
              }
            } else {
              debugPrint('  ⚠️ Skill ${skill.id} has no goalId');
            }
          } else {
            debugPrint('  ⚠️ Skill not found: ${reminder.linkedSkillId}');
            debugPrint('  Available skill IDs: ${growthProvider.skills.map((s) => s.id).join(", ")}');
          }
        } catch (e) {
          debugPrint('  ❌ Error categorizing task via skill: $e');
        }
      } else {
        debugPrint('  ℹ️ Task "${reminder.text}" has no linkedGoalId or linkedSkillId - going to General Tasks');
      }
      
      groups.putIfAbsent(groupName, () => []).add(reminder);
    }
    
    debugPrint('📋 Final groups: ${groups.keys.join(", ")}');
    for (var entry in groups.entries) {
      debugPrint('  ${entry.key}: ${entry.value.length} tasks');
    }
    
    // Sort groups: Goals first (alphabetically), then "General Tasks" at the end
    final sortedGroups = <String, List<Reminder>>{};
    final goalNames = groups.keys.where((k) => k != 'General Tasks').toList()
      ..sort();
    for (var goalName in goalNames) {
      sortedGroups[goalName] = groups[goalName]!;
    }
    if (groups.containsKey('General Tasks')) {
      sortedGroups['General Tasks'] = groups['General Tasks']!;
    }
    
    return sortedGroups;
  }

  Widget _buildPremiumHeader(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
      ),
      child: Row(
        children: [
          // Logo/Icon with subtle gradient
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryLight,
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: AppTheme.getElevationShadow(2),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          
          const SizedBox(width: AppTheme.spacingMD),
          
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Awarely',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Never forget what matters',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          
          // AI Assistant button
          IconButton(
            icon: Icon(
              Icons.smart_toy_rounded,
              color: AppTheme.primaryColor,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AiChatScreen(),
                ),
              );
            },
            tooltip: 'AI Assistant',
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context, ReminderProvider provider) {
    final stats = provider.statistics;
    if (stats == null) return const SizedBox.shrink();
    
    final total = stats['total'] ?? 0;
    final active = stats['active'] ?? 0;
    final completionRate = stats['completionRate'] ?? 0;
    
    if (total == 0) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacingMD,
        AppTheme.spacingSM,
        AppTheme.spacingMD,
        AppTheme.spacingMD,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: AppTheme.getElevationShadow(1),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(context, '$active', 'Active'),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.dividerColor,
          ),
          Expanded(
            child: _buildStatItem(
              context,
              '$completionRate%',
              'Completed',
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.dividerColor,
          ),
          Expanded(
            child: _buildStatItem(context, '$total', 'Total'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryColor,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_off_rounded,
                size: 64,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No tasks yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Create your first task\nto get started',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddReminderScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Create Task'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingXL,
                  vertical: AppTheme.spacingMD,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    ReminderProvider provider,
  ) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: AppTheme.errorColor.withOpacity(0.7),
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              'Something went wrong',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              provider.error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton(
              onPressed: () {
                provider.loadReminders();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

}
