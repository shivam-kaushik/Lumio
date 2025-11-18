import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:intl/intl.dart';
import '../providers/growth_provider.dart';
import '../theme/app_theme.dart';
import '../../core/services/permission_service.dart';
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
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
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
          result,
          targetDeadline: deadline,
          hoursPerDay: hoursPerDay,
        );
        
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          
          if (roadmap != null && roadmap['tasks'] != null) {
            // Create goal with deadline and capacity
            final goalId = await context.read<GrowthProvider>().createGoal(
              result,
              targetDeadline: deadline,
              hoursPerDay: hoursPerDay,
              totalEstimatedHours: roadmap['totalEstimatedHours'] as int?,
            );
            
            // Navigate to planning screen with roadmap data
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => GoalPlanningScreen(
                  goalId: goalId,
                  goalName: result,
                  initialTasks: (roadmap['tasks'] as List)
                      .map((s) => Task.fromMap(s as Map<String, dynamic>))
                      .toList(),
                  timeline: timeline,
                ),
              ),
            );
          } else {
            // Fallback: create goal without roadmap
            final goalId = await context.read<GrowthProvider>().createGoal(result);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Goal created! You can add subtasks manually.')),
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Goals'),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _createGoal,
            tooltip: 'Create Goal',
          ),
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

                return _buildGoalCard(context, goal, tasks.length, completedTasks);
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
              builder: (context) => GoalDetailsScreen(goalId: goal.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              // Goal icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  Icons.flag_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              // Goal info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.track_changes_rounded, size: 16, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '$taskCount tasks',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            if (completedTasks > 0) ...[
                              const SizedBox(width: AppTheme.spacingMD),
                              Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                '$completedTasks completed',
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (goal.targetDeadline != null || goal.hoursPerDay != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (goal.targetDeadline != null) ...[
                                Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  'Due: ${DateFormat('MMM d').format(goal.targetDeadline!)}',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              if (goal.hoursPerDay != null) ...[
                                if (goal.targetDeadline != null) const SizedBox(width: AppTheme.spacingMD),
                                Icon(Icons.access_time_rounded, size: 14, color: AppTheme.primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  '${goal.hoursPerDay}hrs/day',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
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
}

