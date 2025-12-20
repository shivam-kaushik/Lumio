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
import '../../core/services/permission_service.dart';
import '../../core/services/premium_service.dart';
import 'unified_goal_editor_screen.dart'; // Unified Editor
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart'; // Import GoalTask
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
                    color: isListening ? AppTheme.errorColor : null,
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
              leading: Icon(Icons.auto_awesome, color: AppTheme.warningColor),
              title: const Text('AI-Powered (Premium)'),
              subtitle: const Text('Let AI create tasks and roadmap'),
              trailing: Icon(Icons.star, color: AppTheme.warningColor, size: 20),
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
        title: Row(
          children: [
            Icon(Icons.star, color: AppTheme.warningColor),
            const SizedBox(width: 8),
            const Text('Premium Feature'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Premium upgrade coming soon! For now, you can create goals manually.'),
                ),
              );
              Navigator.pop(context, false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
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
        // Navigate to Unified Editor
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UnifiedGoalEditorScreen(
              isNew: false, // Created but now editing/filling
              existingGoal: Goal(
                  id: goalId, 
                  name: goalName, 
                  createdAt: DateTime.now(), 
                  targetDeadline: deadline, 
                  hoursPerDay: hoursPerDay,
                  totalEstimatedHours: 0
              ),
              initialTasks: [],
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
          
          // Navigate to Unified Editor with AI results
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UnifiedGoalEditorScreen(
                isNew: false, 
                existingGoal: Goal(
                  id: goalId,
                  name: goalName,
                  createdAt: DateTime.now(),
                  targetDeadline: deadline,
                  hoursPerDay: hoursPerDay,
                  totalEstimatedHours: roadmap['totalEstimatedHours'] as int?,
                ),
                initialTasks: () {
                    final rawTasks = roadmap['tasks'] as List;
                    final totalDays = deadline.difference(DateTime.now()).inDays;
                    final daysPerTask = (totalDays / (rawTasks.isEmpty ? 1 : rawTasks.length)).floor();
                    final now = DateTime.now();

                    return rawTasks.asMap().entries.map<GoalTask>((entry) {
                      final i = entry.key;
                      final s = entry.value as Map<String, dynamic>;
                      final t = Task.fromMap(s);
                      
                      // Calculate distributed date
                      final taskDeadline = now.add(Duration(days: (i + 1) * daysPerTask));

                      return GoalTask(
                        id: 0, // Temporary ID for new tasks
                        goalId: goalId,
                        title: t.title,
                        description: t.description,
                        estimatedHours: t.estimatedHours,
                        priority: t.priority,
                        frequency: t.frequency, 
                        suggestedTime: t.suggestedTime,
                        suggestedLocation: t.suggestedLocation,
                        isMilestone: t.isMilestone,
                        motivationAnchor: t.motivationAnchor,
                        scheduledDate: taskDeadline, // Assign calculated date
                        createdAt: DateTime.now(),
                      );
                    }).toList();
                }(),
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
                   Text(
                    'When do you want to complete this goal?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
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
                   Text(
                    'How many hours per day can you dedicate?',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Slider(
                    value: hoursPerDay,
                    min: 0.5,
                    max: 8.0,
                    divisions: 15,
                    label: '${hoursPerDay.toStringAsFixed(1)} hours/day',
                    activeColor: AppTheme.primaryColor,
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
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: AppTheme.primaryColor,
                  onPrimary: Colors.white,
                  surface: AppTheme.surfaceColor,
                  onSurface: AppTheme.textPrimary,
                ),
              ),
              child: child!,
            );
          },
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
          // Modern App Bar with large title
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0F0F0F) : AppTheme.backgroundColor,
            scrolledUnderElevation: 0,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'My Goals',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              )
                .animate()
                .fadeIn(duration: 500.ms)
                .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
              titlePadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD, vertical: AppTheme.spacingMD),
              centerTitle: false,
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacingMD),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _createGoal,
                    icon: const Icon(Icons.add_rounded, color: AppTheme.primaryColor),
                    tooltip: 'Add Goal',
                  ),
                )
                  .animate()
                  .scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
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
                    ),
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
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppTheme.spacingMD,
                    mainAxisSpacing: AppTheme.spacingMD,
                    childAspectRatio: 0.75, // Reduce height to minimize blank space
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = goals[index];
                      final tasks = growthProvider.getTasksForGoal(goal.id);
                      
                      int totalTasks = 0;
                      int completedCount = 0;
                      
                      void countRecursive(List<GoalTask> list) {
                          for (var t in list) {
                              totalTasks++;
                              if (t.isCompleted) completedCount++;
                              if (t.subtasks.isNotEmpty) countRecursive(t.subtasks);
                          }
                      }
                      countRecursive(tasks);

                      // Staggered animation for grid items
                      return _buildGoalCard(
                        context,
                        goal,
                        totalTasks,
                        completedCount,
                        index,
                        tasks,
                      )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (50 * index).ms)
                        .scale(begin: const Offset(0.9, 0.9), delay: (50 * index).ms, duration: 400.ms, curve: Curves.easeOutCubic);
                    },
                    childCount: goals.length,
                  ),
                ),
              );
            },
          ),
          // Bottom padding
          const SliverPadding(
            padding: EdgeInsets.only(bottom: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
                color: isDark ? AppTheme.darkSurfaceElevated : AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.flag_rounded,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            )
              .animate()
              .scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut)
              .shimmer(delay: 800.ms, duration: 2000.ms, color: AppTheme.primaryColor.withOpacity(0.3)),
            const SizedBox(height: AppTheme.spacingXL),
            Text(
              'No goals, just dreams',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              'Create your first goal to start turning\nyour dreams into reality',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton.icon(
              onPressed: _createGoal,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Start New Goal'),
              style: ElevatedButton.styleFrom(
                elevation: 4,
                shadowColor: AppTheme.primaryColor.withOpacity(0.4),
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

  void _showDeleteConfirmation(BuildContext context, Goal goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Goal?'),
        content: Text('Are you sure you want to delete "${goal.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GrowthProvider>().deleteGoal(goal.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    BuildContext context,
    Goal goal,
    int taskCount,
    int completedTasks,
    int index,
    List<GoalTask> tasks,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = taskCount > 0 ? completedTasks / taskCount : 0.0;
    final status = _getGoalStatus(goal, taskCount, completedTasks);
    final statusColor = _getStatusColor(status);
    final daysRemaining = _getDaysRemaining(goal.targetDeadline);
    
    // Get preview tasks (fill space - top 4)
    final previewTasks = tasks.where((t) => !t.isCompleted).take(4).toList();
    if (previewTasks.isEmpty && tasks.isNotEmpty) {
      previewTasks.addAll(tasks.take(4));
    }

    return ModernSmartCard(
      onTap: () {
        // Navigate to Unified Editor
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UnifiedGoalEditorScreen(
              isNew: false,
              existingGoal: goal,
              initialTasks: tasks, // Pass actual tasks
            ),
          ),
        );
      },
      padding: EdgeInsets.zero, // We handle padding inside
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Delete
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        goal.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Dustbin (Delete) Icon
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _showDeleteConfirmation(context, goal),
                        child: Container(
                          padding: const EdgeInsets.all(4), 
                          alignment: Alignment.topRight,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Content Preview (Mini Task List)
                Expanded(
                  child: previewTasks.isEmpty
                      ? Text(
                          "No tasks yet",
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                            fontSize: 12,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...previewTasks.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    t.isCompleted ? Icons.check_circle_outline : Icons.circle_outlined,
                                    size: 10,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white70 : Colors.black87,
                                        decoration: t.isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            if (tasks.length > 4)
                              Text(
                                "+ ${tasks.length - 4} more",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                ),
                
                const SizedBox(height: 12),
                
                // Footer: Progress
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (daysRemaining.isNotEmpty)
                          Text(
                            daysRemaining.split(' ').first + (daysRemaining.contains('left') ? ' days' : ''), // Shorten text
                            style: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    AnimatedProgressBar(
                      progress: progress,
                      height: 4,
                      backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                      progressColor: statusColor,
                      showPercentage: false, // Disable duplicate percentage
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
