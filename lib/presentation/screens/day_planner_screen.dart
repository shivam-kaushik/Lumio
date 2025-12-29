import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../core/services/sound_service.dart';
import '../providers/growth_provider.dart';
import '../../data/models/goal_task.dart';
import '../theme/app_theme.dart';
import 'daily_report_screen.dart';
import 'day_planner_history_screen.dart'; 
import '../widgets/active_task_timer.dart';
import '../widgets/quick_task_input_sheet.dart';
import '../utils/analytics_helper.dart'; 

class DayPlannerScreen extends StatefulWidget {
  final DateTime? initialDate;

  const DayPlannerScreen({super.key, this.initialDate});

  @override
  State<DayPlannerScreen> createState() => _DayPlannerScreenState();
}

class _DayPlannerScreenState extends State<DayPlannerScreen> with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isConverting = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  List<Map<String, dynamic>>? _generatedPlan;
  Timer? _rolloverTimer;
  bool _isViewingToday = true;
  late DateTime _selectedDate; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    
    // Initialize date from constructor or default to now
    _selectedDate = widget.initialDate ?? DateTime.now();
    _isViewingToday = AnalyticsHelper.isSameDay(_selectedDate, DateTime.now());
    
    _initSpeech();
    _startRolloverCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rolloverTimer?.cancel();
    super.dispose();
  }

  void _startRolloverCheck() {
    // Check every minute for day change
    _rolloverTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkRollover());
  }

  void _checkRollover() {
    if (!mounted) return;
    
    final now = DateTime.now();
    
    // If we are supposed to be viewing "Today", but the date has drifted, update it.
    if (_isViewingToday && !AnalyticsHelper.isSameDay(_selectedDate, now)) {
       debugPrint("📅 Day Rollover Detected! Updating to $now");
       setState(() {
         _selectedDate = now;
       });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkRollover(); // Force check immediately on resume
    }
  }

  Future<void> _initSpeech() async {
    try {
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        await Permission.microphone.request();
      }
      _speechAvailable = await _speech.initialize(
        onError: (e) => setState(() => _isListening = false),
        onStatus: (s) => setState(() => _isListening = s == 'listening'),
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Speech init error: $e");
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) return;
    }

    if (_isListening) {
      await _speech.stop();
    } else {
      final previousText = _inputController.text;
      await _speech.listen(
        onResult: (result) {
          setState(() {
            final newWords = result.recognizedWords;
            if (previousText.isEmpty) {
               _inputController.text = newWords;
            } else {
               _inputController.text = "$previousText $newWords";
            }
          });
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 10),
        localeId: "en_US",
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      );
    }
  }

  Future<void> _generatePlan() async {
    if (_inputController.text.trim().isEmpty) return;

    if (_isListening) await _speech.stop();

    setState(() => _isConverting = true);
    
    // 1. Call AI
    final gpt = PrivacyGptService();
    final plan = await gpt.generateDailySchedule(_inputController.text);
    
    setState(() {
      _isConverting = false;
      _generatedPlan = plan;
    });
    
    SoundService().playMagic();
  }

  Future<void> _confirmAndSave() async {
    if (_generatedPlan == null) return;
    
    setState(() => _isConverting = true); // Reuse loading state

    try {
      final provider = context.read<GrowthProvider>();
      
      // 1. Ensure Daily Goal Exists for SELECTED DATE
      final goalId = await provider.ensureDailyGoal(_selectedDate);
      
      // 2. Create Tasks
      // Note: We create them sequentially to preserve order
      for (var item in _generatedPlan!) {
        final task = GoalTask(
          id: 0, // Temporary
          goalId: goalId,
          title: item['title'] ?? 'Untitled',
          description: item['description'] ?? '',
          estimatedMinutes: item['estimatedMinutes'],
          priority: item['priority'] ?? 'medium',
          suggestedTime: item['suggestedTime'] ?? 'any',
          createdAt: DateTime.now(),
          isCompleted: false,
          subtasks: [],
          // Set scheduledDate to today/selected date
          scheduledDate: _selectedDate,
        );
        
        await provider.createTask(task);
      }

      if (mounted) {
        // Clear state to switch to Dashboard Mode
        _inputController.clear();
        setState(() => _generatedPlan = null);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day Plan Created Successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  void _showQuickAdd(BuildContext context, GrowthProvider provider) {
      showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => QuickTaskInputSheet(
              onSubmit: (title, date, priority, tags, repeat, location) async {
                  // Add directly to day's plan
                  final goalId = await provider.ensureDailyGoal(_selectedDate);
                  final task = GoalTask(
                      id: 0,
                      goalId: goalId,
                      title: title,
                      description: '',
                      priority: priority,
                      createdAt: DateTime.now(),
                      scheduledDate: _selectedDate, // Use selected date
                      frequency: repeat ?? 'one-time',
                      suggestedLocation: location ?? 'any',
                  );
                  await provider.createTask(task);
                  if (mounted) Navigator.pop(context);
              },
              initialDate: _selectedDate, // Pass selected date to quick add
          ),
      );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        // If user manually picks a date, we respect their choice.
        // If they pick "Today", we resume auto-rollover.
        // If they pick "Yesterday", auto-rollover stops (so it doesn't jump back to Today).
        _isViewingToday = AnalyticsHelper.isSameDay(picked, DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white54 : Colors.black54;

    return Consumer<GrowthProvider>(
      builder: (context, provider, _) {
        // Check for existing plan
        final isToday = AnalyticsHelper.isSameDay(_selectedDate, DateTime.now());
        final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
        final goalName = "Daily Plan - $dateStr";
        
        // Find goals
        int? dayGoalId;
        try {
          dayGoalId = provider.goals.firstWhere((g) => g.name == goalName).id;
        } catch (_) {}
        
        // Collect tasks (Strictly Daily Plan only + Date Check)
        // Collect tasks (Daily Plan + Inbox for this date)
        List<GoalTask> tasks = [];
        
        // 1. Daily Plan Goal Tasks
        if (dayGoalId != null) {
            final goalTasks = provider.getTasksForGoal(dayGoalId);
            tasks.addAll(goalTasks.where((t) {
                final dateToCheck = t.scheduledDate ?? t.createdAt;
                return AnalyticsHelper.isSameDay(dateToCheck, _selectedDate);
            }));
        }

        // 2. Inbox Tasks (Scheduled for this date)
        try {
           final inboxGoal = provider.goals.firstWhere((g) => g.name == 'Inbox');
           final inboxTasks = provider.getTasksForGoal(inboxGoal.id);
           final inboxForDay = inboxTasks.where((t) {
               // Check Scheduled OR Created date for Inbox
               // This allows "Quick Capture" tasks (no date) to appear on the day they were created.
               final dateToCheck = t.scheduledDate ?? t.createdAt; 
               return AnalyticsHelper.isSameDay(dateToCheck, _selectedDate);
           });
           tasks.addAll(inboxForDay);
        } catch (_) {
           // No Inbox or errors
        }
        
        // Check tasks
        final hasPlan = tasks.isNotEmpty;
        
        if (hasPlan && _generatedPlan == null) {
          // MODE B: DASHBOARD (Plan Exists)
          
          // Find active task for Timer
          GoalTask? activeTask;
          try {
             activeTask = tasks.firstWhere((t) => t.startedAt != null);
          } catch (_) {}

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: InkWell(
                  onTap: _pickDate,
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Text(
                              isToday ? "Today's Plan" : AnalyticsHelper.formatDate(_selectedDate), 
                              style: TextStyle(color: textColor)
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_drop_down, color: textColor),
                      ],
                  ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              actions: [
                 IconButton(
                   icon: const Icon(Icons.history, color: Colors.grey),
                   onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => const DayPlannerHistoryScreen()));
                   },
                 ),
                 IconButton(
                   icon: Icon(Icons.analytics_outlined, color: textColor),
                   onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportScreen()));
                   },
                 )
               ],
            ),
            floatingActionButton: FloatingActionButton.extended(
                onPressed: () => _showQuickAdd(context, provider),
                backgroundColor: AppTheme.primaryColor,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Add Task", style: TextStyle(color: Colors.white)),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  
                  // Active Timer Section
                  if (activeTask != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: ActiveTaskTimer(task: activeTask),
                      ),

                  Expanded(
                    child: ListView.builder(
                      itemCount: tasks.length,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), // Bottom padding for FAB
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final isRunning = task.startedAt != null;

                        return Dismissible(
                          key: Key('task_${task.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: const [
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.delete_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                             return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                    title: const Text('Delete Task'),
                                    content: Text('Are you sure you want to delete "${task.title}"?'),
                                    actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
                                            child: const Text('Delete'),
                                        ),
                                    ],
                                ),
                             ) ?? false;
                          },
                          onDismissed: (direction) {
                             provider.deleteTask(task.id);
                             ScaffoldMessenger.of(context).showSnackBar(
                                 const SnackBar(content: Text('Task deleted')),
                             );
                          },
                          child: Card(
                          color: isRunning 
                             ? (isDark ? const Color(0xFF2C2C30) : Colors.blue.shade50) 
                             : (isDark ? const Color(0xFF1E1E20) : Colors.white),
                          elevation: isRunning ? 4 : 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: isRunning ? BorderSide(color: AppTheme.primaryColor, width: 2) : BorderSide.none
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            onTap: () async {
                                // EDIT TASK
                                await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => QuickTaskInputSheet(
                                        isEditing: true,
                                        initialTitle: task.title,
                                        initialPriority: task.priority,
                                        initialTags: [], // Extract from description if needed, or pass empty
                                        initialRepeat: task.frequency != 'one-time' ? task.frequency : null,
                                        initialLocation: task.suggestedLocation != 'any' ? task.suggestedLocation : null,
                                        onSubmit: (title, date, priority, tags, repeat, location) {
                                            final updatedTask = task.copyWith(
                                                title: title,
                                                priority: priority,
                                                frequency: repeat ?? 'one-time',
                                                suggestedLocation: location ?? 'any',
                                                scheduledDate: date ?? task.scheduledDate,
                                            );
                                            provider.updateTask(updatedTask);
                                            Navigator.pop(context);
                                        },
                                        initialDate: task.scheduledDate,
                                    ),
                                );
                            },
                            leading: Checkbox(
                              value: task.isCompleted,
                              activeColor: AppTheme.primaryColor,
                              onChanged: (val) {
                                if (val == true) {
                                  provider.completeTask(task.id);
                                } else {
                                  provider.uncompleteTask(task.id);
                                }
                              },
                            ),
                            title: Text(
                              task.title, 
                              style: TextStyle(
                                color: textColor,
                                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                decorationColor: subtleColor,
                                fontWeight: FontWeight.w500,
                              )
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isRunning ? Icons.pause_circle_filled : Icons.play_circle_fill,
                                color: isRunning ? Colors.amber : AppTheme.primaryColor,
                                size: 32,
                              ),
                              onPressed: () {
                                provider.toggleTaskTimer(task.id);
                              },
                            ),
                          ),
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // MODE A: MORNING DUMP (No Plan or Creating New)
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
             title: InkWell(
                  onTap: _pickDate,
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Text(
                              isToday ? "The Day Architect" : AnalyticsHelper.formatDate(_selectedDate), 
                              style: TextStyle(color: textColor)
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_drop_down, color: textColor),
                      ],
                  ),
              ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
          ),
          floatingActionButton: _generatedPlan == null ? FloatingActionButton.extended(
                onPressed: () => _showQuickAdd(context, provider),
                backgroundColor: AppTheme.primaryColor,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Add Manual Task", style: TextStyle(color: Colors.white)),
            ) : null,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Input Section
                if (_generatedPlan == null) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isToday ? "What needs to happen today?" : "What needs to happen on ${AnalyticsHelper.formatDate(_selectedDate)}?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Dump your thoughts. We'll structure them.",
                            style: TextStyle(color: subtleColor),
                          ),
                          const SizedBox(height: 32),
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              TextField(
                                controller: _inputController,
                                style: TextStyle(color: textColor, fontSize: 18),
                                maxLines: 6,
                                decoration: InputDecoration(
                                  hintText: "e.g., Finish the report, call John at 2pm, gym at 5...",
                                  hintStyle: TextStyle(color: subtleColor.withOpacity(0.5)),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 48), // Space for fab
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: FloatingActionButton.small(
                                  onPressed: _toggleListening,
                                  backgroundColor: _isListening ? AppTheme.errorColor : AppTheme.primaryColor,
                                  child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isConverting ? null : _generatePlan,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isConverting 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("Structure My Day", style: TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // 2. Review Section
                  Expanded(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            "Here is your Plan",
                            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _generatedPlan!.length,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemBuilder: (context, index) {
                              final item = _generatedPlan![index];
                              return Card(
                                color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                                    child: Text('${index + 1}', style: TextStyle(color: AppTheme.primaryColor)),
                                  ),
                                  title: Text(item['title'], style: TextStyle(color: textColor)),
                                  subtitle: Text(
                                    "${item['estimatedMinutes']} mins • ${item['priority']}",
                                    style: TextStyle(color: subtleColor),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _generatedPlan!.removeAt(index);
                                      });
                                    },
                                  ),
                                ),
                              ).animate().fadeIn(delay: (100 * index).ms).slideX();
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isConverting ? null : _confirmAndSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.successColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isConverting 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("Confirm & Start Day", style: TextStyle(fontSize: 18, color: Colors.white)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
