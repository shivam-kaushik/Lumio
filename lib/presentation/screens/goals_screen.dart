import 'package:flutter/material.dart';
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
import '../../data/models/goal.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../data/models/subtask.dart' show Task;

/// Goals screen showing all business goals
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Goals')
          .animate()
          .fadeIn(duration: 500.ms)
          .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _createGoal,
            tooltip: 'Create Goal',
          )
            .animate()
            .scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut)
            .shimmer(delay: 700.ms, duration: 1500.ms, color: AppTheme.primaryColor.withOpacity(0.3)),
        ],
      ),
      body: Consumer<GrowthProvider>(
        builder: (context, growthProvider, child) {
          if (growthProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final goals = growthProvider.goals;

          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      size: 80,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppTheme.spacingLG),
                    Text(
                      'No goals yet',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Create your first business goal to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: AppTheme.spacingXL),
                    ElevatedButton.icon(
                      onPressed: _createGoal,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create Goal'),
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
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                final tasks = growthProvider.getTasksForGoal(goal.id);
                final completedTasks = tasks.where((t) => t.isCompleted).length;

                return _buildGoalCard(context, goal, tasks.length, completedTasks, index);
              },
            ),
          );
        },
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
    
    final cardContent = ModernSmartCard(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      useGradient: true,
      elevationLevel: 2,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoalDetailsScreen(goalId: goal.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Goal title and progress
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (taskCount > 0) ...[
                      const SizedBox(height: AppTheme.spacingSM),
                      AnimatedProgressBar(
                        progress: progress,
                        height: 6,
                        showPercentage: false,
                        progressColor: AppTheme.getNeonAccent(type: 'blue'),
                      ),
                      const SizedBox(height: AppTheme.spacingXS),
                      Text(
                        '$completedTasks of $taskCount tasks completed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          // Deadline info if available
          if (goal.targetDeadline != null) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  'Deadline: ${DateFormat('MMM d, y').format(goal.targetDeadline!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    
    // Wrap with 3D card for enhanced visual effect
    return Card3D(
      front: cardContent,
      enableTilt: true,
      tiltAngle: 5.0,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GoalDetailsScreen(goalId: goal.id),
          ),
        );
      },
    )
      .animate()
      .fadeIn(duration: 600.ms, delay: (index * 80).ms)
      .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic)
      .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.0, 1.0), duration: 600.ms, curve: Curves.easeOutCubic);
  }
}

