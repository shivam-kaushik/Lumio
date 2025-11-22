import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/modern_smart_card.dart';
import '../widgets/animated_progress_bar.dart';
import '../widgets/3d_card.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/premium_service.dart';
import 'goal_details_screen.dart';
import 'goal_planning_screen.dart';
import 'roadmap_management_screen.dart';
import '../../data/models/goal.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../data/models/subtask.dart' show Task;

/// Goals screen showing all business goals with modern, interactive UI
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GrowthProvider>().loadGrowthData();
    });
  }

  Future<void> _transcribeVoiceInput(
    TextEditingController controller,
    StateSetter setDialogState,
    VoidCallback onStopListening,
  ) async {
    final permissionService = PermissionService();
    final hasPermission = await permissionService.requestMicrophonePermission();
    
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      onStopListening();
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
      onStopListening();
      return;
    }

    bool isFinal = false;
    await _speech.listen(
      onResult: (result) {
        setDialogState(() {
          controller.text = result.recognizedWords;
          if (result.finalResult) {
            isFinal = true;
            _speech.stop();
            onStopListening();
          }
        });
      },
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );

    // Auto-stop after 5 seconds if no final result
    await Future.delayed(const Duration(seconds: 5));
    if (!isFinal) {
      await _speech.stop();
      onStopListening();
    }
  }

  Future<void> _createGoal() async {
    final controller = TextEditingController();
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          bool isListening = false;
          
          return AlertDialog(
            title: const Text('Create Goal'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Describe your goal (e.g., Launch my SaaS product)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: isListening ? Colors.red : null,
                  ),
                  onPressed: () async {
                    setDialogState(() => isListening = true);
                    await _transcribeVoiceInput(controller, setDialogState, () {
                      setDialogState(() => isListening = false);
                    });
                  },
                  tooltip: 'Voice input',
                ),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Next'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      // Show creation method selection
      final creationMethod = await _showCreationMethodDialog(context);
      
      if (creationMethod == null) return;
      
      if (creationMethod == 'manual') {
        // Manual creation - go directly to planning screen
        await _createManualGoal(result);
      } else if (creationMethod == 'ai') {
        // AI creation - check premium status
        final premiumService = PremiumService();
        final isPremium = await premiumService.isPremium();
        
        if (!isPremium) {
          // Show premium upgrade dialog
          final upgrade = await _showPremiumUpgradeDialog(context);
          if (upgrade != true) return;
        }
        
        // Proceed with AI creation
        await _createAIGoal(result);
      }
    }
  }

  Future<String?> _showCreationMethodDialog(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('How would you like to create your goal?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.primaryColor),
              title: const Text('Create Manually'),
              subtitle: const Text('Add tasks yourself'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Colors.amber),
              title: const Text('AI-Powered (Premium)'),
              subtitle: const Text('Let AI create tasks and roadmap'),
              trailing: const Icon(Icons.star, color: Colors.amber, size: 20),
              onTap: () => Navigator.pop(context, 'ai'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showPremiumUpgradeDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Premium Feature'),
          ],
        ),
        content: const Text(
          'AI-powered goal planning is a premium feature. Upgrade to unlock intelligent task generation and roadmaps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement premium upgrade flow
              // For now, just show a message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Premium upgrade coming soon! For now, you can create goals manually.'),
                ),
              );
              Navigator.pop(context, false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
            ),
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Future<void> _createManualGoal(String goalName) async {
    try {
      // Ask for timeline
      final timeline = await _showTimelineDialog(context);
      
      if (timeline == null) return;
      
      final deadline = timeline['deadline'] as DateTime;
      final hoursPerDay = (timeline['hoursPerDay'] as num?)?.toDouble() ?? 2.0;
      
      // Create goal
      final goalId = await context.read<GrowthProvider>().createGoal(
        goalName,
        targetDeadline: deadline,
        hoursPerDay: hoursPerDay,
      );
      
      if (mounted) {
        // Navigate to planning screen with empty tasks
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GoalPlanningScreen(
              goalId: goalId,
              goalName: goalName,
              initialTasks: [], // Empty tasks for manual creation
              timeline: timeline,
            ),
          ),
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

  Future<void> _createAIGoal(String goalName) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Generate roadmap using GPT (includes tasks)
      final gptService = PrivacyGptService();
      
      // Ask for timeline first (needed for generateDetailedRoadmap)
      final timeline = await _showTimelineDialog(context);
      
      if (timeline == null) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
        }
        return;
      }
      
      final deadline = timeline['deadline'] as DateTime;
      final hoursPerDay = (timeline['hoursPerDay'] as num?)?.toDouble() ?? 2.0;
      
      // Generate detailed roadmap with tasks
      final roadmap = await gptService.generateDetailedRoadmap(
        goalName,
        targetDeadline: deadline,
        hoursPerDay: hoursPerDay,
      );
      
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (roadmap != null && roadmap['tasks'] != null) {
          // Create goal with deadline and capacity
          final goalId = await context.read<GrowthProvider>().createGoal(
            goalName,
            targetDeadline: deadline,
            hoursPerDay: hoursPerDay,
            totalEstimatedHours: roadmap['totalEstimatedHours'] as int?,
          );
          
          // Navigate to planning screen with roadmap data
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GoalPlanningScreen(
                goalId: goalId,
                goalName: goalName,
                initialTasks: (roadmap['tasks'] as List)
                    .map((s) => Task.fromMap(s as Map<String, dynamic>))
                    .toList(),
                timeline: timeline,
              ),
            ),
          );
        } else {
          // Fallback: create goal without roadmap
          final goalId = await context.read<GrowthProvider>().createGoal(goalName);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Goal created! You can add tasks manually.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showTimelineDialog(BuildContext context) async {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        double hoursPerDay = 2.0;
        
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Goal Timeline'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'When do you want to complete this goal?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  _buildTimelineOption(dialogContext, setState, '1 day', 1, 'days', () => hoursPerDay),
                  _buildTimelineOption(dialogContext, setState, '1 week', 1, 'weeks', () => hoursPerDay),
                  _buildTimelineOption(dialogContext, setState, '2 weeks', 2, 'weeks', () => hoursPerDay),
                  _buildTimelineOption(dialogContext, setState, '1 month', 1, 'months', () => hoursPerDay),
                  _buildTimelineOption(dialogContext, setState, '2 months', 2, 'months', () => hoursPerDay),
                  _buildTimelineOption(dialogContext, setState, '3 months', 3, 'months', () => hoursPerDay),
                  _buildTimelineOption(dialogContext, setState, '6 months', 6, 'months', () => hoursPerDay),
                  _buildTimelineOption(dialogContext, setState, '1 year', 12, 'months', () => hoursPerDay),
                  const Divider(),
                  _buildCustomTimelineOption(dialogContext, setState, () => hoursPerDay),
                  const Divider(),
                  const SizedBox(height: AppTheme.spacingSM),
                  const Text(
                    'How many hours per day can you dedicate?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Slider(
                    value: hoursPerDay,
                    min: 0.5,
                    max: 8.0,
                    divisions: 15,
                    label: '${hoursPerDay.toStringAsFixed(1)} hours/day',
                    onChanged: (value) {
                      setState(() {
                        hoursPerDay = value;
                      });
                    },
                  ),
                  Text(
                    '${hoursPerDay.toStringAsFixed(1)} hours per day',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomTimelineOption(
    BuildContext dialogContext,
    StateSetter setState,
    double Function() getHoursPerDay,
  ) {
    return ListTile(
      leading: const Icon(Icons.calendar_today_rounded),
      title: const Text('Custom Date'),
      subtitle: const Text('Select your own deadline'),
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: dialogContext,
          initialDate: DateTime.now().add(const Duration(days: 30)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365 * 5)), // 5 years max
        );
        
        if (selectedDate != null) {
          // Close the timeline dialog and return the result
          Navigator.pop(dialogContext, {
            'deadline': selectedDate,
            'label': DateFormat('MMM d, y').format(selectedDate),
            'hoursPerDay': getHoursPerDay(),
          });
        }
      },
    );
  }

  Widget _buildTimelineOption(
    BuildContext context,
    StateSetter setState,
    String label,
    int amount,
    String unit,
    double Function() getHoursPerDay,
  ) {
    return ListTile(
      title: Text(label),
      onTap: () {
        final now = DateTime.now();
        DateTime deadline;
        if (unit == 'days') {
          deadline = now.add(Duration(days: amount));
        } else if (unit == 'weeks') {
          deadline = now.add(Duration(days: amount * 7));
        } else {
          deadline = DateTime(now.year, now.month + amount, now.day);
        }
        Navigator.pop(context, {
          'deadline': deadline,
          'label': label,
          'hoursPerDay': getHoursPerDay(),
        });
      },
    );
  }

  String _getGoalStatus(Goal goal, int totalTasks, int completedTasks) {
    if (totalTasks == 0) return 'Not Started';
    if (completedTasks == totalTasks) return 'Completed';
    final progress = completedTasks / totalTasks;
    if (progress >= 0.75) return 'Almost There';
    if (progress >= 0.5) return 'In Progress';
    if (progress >= 0.25) return 'Getting Started';
    return 'Just Started';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return AppTheme.successColor;
      case 'Almost There':
        return AppTheme.primaryColor;
      case 'In Progress':
        return AppTheme.primaryLight;
      case 'Getting Started':
        return AppTheme.secondaryColor;
      case 'Just Started':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textTertiary;
    }
  }

  String _getDaysRemaining(DateTime? deadline) {
    if (deadline == null) return '';
    final now = DateTime.now();
    final difference = deadline.difference(now);
    if (difference.inDays < 0) return 'Overdue';
    if (difference.inDays == 0) return 'Due Today';
    if (difference.inDays == 1) return '1 day left';
    if (difference.inDays < 7) return '${difference.inDays} days left';
    if (difference.inDays < 30) return '${(difference.inDays / 7).ceil()} weeks left';
    return '${(difference.inDays / 30).ceil()} months left';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Goals',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                ),
              )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacingMD),
                child: TextButton.icon(
                  onPressed: _createGoal,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text(
                    'Add Goal',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                )
                  .animate()
                  .scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut)
                  .shimmer(delay: 700.ms, duration: 1500.ms, color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
            ],
          ),
          
          // Content
          Consumer<GrowthProvider>(
            builder: (context, growthProvider, child) {
              if (growthProvider.isLoading) {
                return SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    )
                      .animate()
                      .scale(duration: 500.ms, curve: Curves.easeOutCubic),
                  ),
                );
              }

              final goals = growthProvider.goals;

              if (goals.isEmpty) {
                return SliverFillRemaining(
                  child: _buildEmptyState(context),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = goals[index];
                      final tasks = growthProvider.getTasksForGoal(goal.id);
                      final completedTasks = tasks.where((t) => t.isCompleted).length;
                      return _buildGoalCard(
                        context,
                        goal,
                        tasks.length,
                        completedTasks,
                        index,
                      );
                    },
                    childCount: goals.length,
                  ),
                ),
              );
            },
          ),
          // Bottom padding above bottom navigation bar
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.1),
                    AppTheme.primaryLight.withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(
                Icons.flag_rounded,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .shimmer(delay: 800.ms, duration: 2000.ms, color: AppTheme.primaryColor.withOpacity(0.3)),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No goals yet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Create your first goal to start turning\ndreams into reality',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            )
              .animate()
              .fadeIn(delay: 600.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: _createGoal,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Create Your First Goal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLG,
                  vertical: AppTheme.spacingMD,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                elevation: 4,
              ),
            )
              .animate()
              .fadeIn(delay: 800.ms, duration: 500.ms)
              .scale(delay: 800.ms, duration: 500.ms, curve: Curves.elasticOut),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    Goal goal,
    int taskCount,
    int completedTasks,
    int index,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = taskCount > 0 ? completedTasks / taskCount : 0.0;
    final status = _getGoalStatus(goal, taskCount, completedTasks);
    final statusColor = _getStatusColor(status);
    final daysRemaining = _getDaysRemaining(goal.targetDeadline);
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoalDetailsScreen(goalId: goal.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
        child: ModernSmartCard(
          useGradient: true,
          elevationLevel: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Goal Icon/Emoji
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.2),
                          AppTheme.primaryLight.withOpacity(0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Icon(
                      Icons.flag_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  )
                    .animate()
                    .scale(delay: (index * 50).ms, duration: 400.ms, curve: Curves.elasticOut),
                  
                  const SizedBox(width: AppTheme.spacingMD),
                  
                  // Goal Title and Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Row(
                          children: [
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingSM,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                border: Border.all(
                                  color: statusColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (daysRemaining.isNotEmpty) ...[
                              const SizedBox(width: AppTheme.spacingSM),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingSM,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: goal.targetDeadline != null &&
                                          goal.targetDeadline!.isBefore(DateTime.now())
                                      ? AppTheme.errorColor.withOpacity(0.15)
                                      : AppTheme.textSecondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      goal.targetDeadline != null &&
                                              goal.targetDeadline!.isBefore(DateTime.now())
                                          ? Icons.warning_rounded
                                          : Icons.schedule_rounded,
                                      size: 12,
                                      color: goal.targetDeadline != null &&
                                              goal.targetDeadline!.isBefore(DateTime.now())
                                          ? AppTheme.errorColor
                                          : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      daysRemaining,
                                      style: TextStyle(
                                        color: goal.targetDeadline != null &&
                                                goal.targetDeadline!.isBefore(DateTime.now())
                                            ? AppTheme.errorColor
                                            : AppTheme.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Chevron Icon
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                ],
              ),
              
              // Progress Section
              if (taskCount > 0) ...[
                const SizedBox(height: AppTheme.spacingMD),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$completedTasks / $taskCount tasks',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingSM),
                          AnimatedProgressBar(
                            progress: progress,
                            height: 8,
                            showPercentage: false,
                            progressColor: statusColor,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMD),
                    // Progress Percentage Circle
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.2),
                            statusColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                      .animate()
                      .scale(delay: (index * 50 + 200).ms, duration: 400.ms, curve: Curves.elasticOut),
                  ],
                ),
              ] else ...[
                const SizedBox(height: AppTheme.spacingMD),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(
                      color: AppTheme.borderColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_task_rounded,
                        size: 20,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text(
                        'No tasks yet - Add tasks to get started',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Deadline Info
              if (goal.targetDeadline != null) ...[
                const SizedBox(height: AppTheme.spacingMD),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingSM,
                    vertical: AppTheme.spacingXS,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: AppTheme.spacingXS),
                      Text(
                        DateFormat('MMM d, y').format(goal.targetDeadline!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        )
          .animate()
          .fadeIn(duration: 600.ms, delay: (index * 80).ms)
          .slideY(begin: 0.2, end: 0, duration: 600.ms, delay: (index * 80).ms, curve: Curves.easeOutCubic)
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            duration: 600.ms,
            delay: (index * 80).ms,
            curve: Curves.easeOutCubic,
          ),
      ),
    );
  }
}
