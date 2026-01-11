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
import '../widgets/timeline_task_tile.dart';
import '../utils/analytics_helper.dart'; 
import 'package:intl/intl.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // Added

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

  // Schedule Settings
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 8, minute: 0);
  String _wakeUpTitle = "Rise and Shine";
  TimeOfDay _bedTime = const TimeOfDay(hour: 22, minute: 0);
  String _bedTimeTitle = "Wind Down";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    
    // Initialize date from constructor or default to now
    _selectedDate = widget.initialDate ?? DateTime.now();
    _isViewingToday = AnalyticsHelper.isSameDay(_selectedDate, DateTime.now());
    
    _initSpeech();
    _startRolloverCheck();
    _loadScheduleSettings(); // Load saved custom schedule
  }

  Future<void> _loadScheduleSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wakeUpTitle = prefs.getString('schedule_wakeup_title') ?? "Rise and Shine";
      _bedTimeTitle = prefs.getString('schedule_bedtime_title') ?? "Wind Down";
      
      final wakeHour = prefs.getInt('schedule_wakeup_hour') ?? 8;
      final wakeMin = prefs.getInt('schedule_wakeup_min') ?? 0;
      _wakeUpTime = TimeOfDay(hour: wakeHour, minute: wakeMin);
      
      final bedHour = prefs.getInt('schedule_bedtime_hour') ?? 22;
      final bedMin = prefs.getInt('schedule_bedtime_min') ?? 0;
      _bedTime = TimeOfDay(hour: bedHour, minute: bedMin);
    });
  }

  Future<void> _saveScheduleSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    }
  }

  void _showEditAnchorDialog(bool isMaskUp) {
     final isWakeUp = isMaskUp;
     final initialTime = isWakeUp ? _wakeUpTime : _bedTime;
     final initialTitle = isWakeUp ? _wakeUpTitle : _bedTimeTitle;
     final controller = TextEditingController(text: initialTitle);

     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text(isWakeUp ? 'Edit Morning Routine' : 'Edit Night Routine'),
         content: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             TextField(
               controller: controller,
               decoration: const InputDecoration(
                 labelText: 'Routine Name',
                 hintText: 'e.g. Rise and Shine',
               ),
             ),
             const SizedBox(height: 16),
             ListTile(
               title: const Text('Schedule Time'),
               trailing: Text(initialTime.format(context)),
               onTap: () async {
                 final picked = await showTimePicker(
                   context: context,
                   initialTime: initialTime,
                 );
                 if (picked != null) {
                    Navigator.pop(context); // Close current dialog to refresh (simple way)
                    // Save temporarily and reopen? Or better, use StatefulWidget dialog.
                    // For simplicity, let's just update main state and reopen content
                    if (isWakeUp) {
                       setState(() => _wakeUpTime = picked);
                    } else {
                       setState(() => _bedTime = picked);
                    }
                    _showEditAnchorDialog(isWakeUp); // Reopen with new time
                 }
               },
             ),
           ],
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(context),
             child: const Text('Cancel'),
           ),
           ElevatedButton(
             onPressed: () {
               setState(() {
                 if (isWakeUp) {
                   _wakeUpTitle = controller.text;
                   _saveScheduleSetting('schedule_wakeup_title', _wakeUpTitle);
                   _saveScheduleSetting('schedule_wakeup_hour', _wakeUpTime.hour);
                   _saveScheduleSetting('schedule_wakeup_min', _wakeUpTime.minute);
                 } else {
                   _bedTimeTitle = controller.text;
                   _saveScheduleSetting('schedule_bedtime_title', _bedTimeTitle);
                   _saveScheduleSetting('schedule_bedtime_hour', _bedTime.hour);
                   _saveScheduleSetting('schedule_bedtime_min', _bedTime.minute);
                 }
               });
               Navigator.pop(context);
             },
             child: const Text('Save'),
           ),
         ],
       ),
     );
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
    // Get plan but don't set separate state yet
    final plan = await gpt.generateDailySchedule(_inputController.text);
    
    if (plan == null) {
       setState(() => _isConverting = false);
       if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Could not generate plan. Please try different text.')),
           );
       }
       return;
    }

    // 2. Auto-Confirm & Save (Skip Review Screen)
    try {
      final provider = context.read<GrowthProvider>();
      
      // Ensure Daily Goal Exists for SELECTED DATE
      final goalId = await provider.ensureDailyGoal(_selectedDate);
      
      // Create Tasks
      for (var item in plan) {
        // Parse explicit time if available
        DateTime? finalDate = _selectedDate;
        if (item['specificTime'] != null) {
            final parts = item['specificTime'].toString().split(':');
            if (parts.length == 2) {
               final hour = int.tryParse(parts[0]);
               final min = int.tryParse(parts[1]);
               if (hour != null && min != null) {
                  finalDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, min);
               }
            }
        }
        
        final task = GoalTask(
          id: 0, 
          goalId: goalId,
          title: item['title'] ?? 'Untitled',
          description: item['description'] ?? '',
          estimatedMinutes: item['estimatedMinutes'],
          priority: item['priority'] ?? 'medium',
          suggestedTime: item['suggestedTime'] ?? 'any',
          createdAt: DateTime.now(),
          isCompleted: false,
          subtasks: [],
          scheduledDate: finalDate, // Use precise time if available
        );
        
        await provider.createTask(task);
      }

      if (mounted) {
        _inputController.clear();
        _generatedPlan = null; // Ensure this stays null so we don't trigger review UI
        
        SoundService().playMagic();
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
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final subtleColor = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Consumer<GrowthProvider>(
      builder: (context, provider, _) {
        // Check for existing plan
        final isToday = AnalyticsHelper.isSameDay(_selectedDate, DateTime.now());
        final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
        final goalName = "Daily Plan - $dateStr";
        
        // Collect tasks for the selected date: ONLY from "Daily Plan" and "Inbox"
        List<GoalTask> tasks = [];
        
        // 1. Daily Plan Tasks
        try {
           final dailyPlanGoal = provider.goals.firstWhere((g) => g.name == goalName);
           tasks.addAll(provider.getTasksForGoal(dailyPlanGoal.id));
        } catch (_) {
           // No daily plan goal yet, that's fine
        }

        // 2. Inbox Tasks (Scheduled for today OR Created today)
        try {
           final inboxGoal = provider.goals.firstWhere((g) => g.name == 'Inbox');
           final inboxTasks = provider.getTasksForGoal(inboxGoal.id);
           tasks.addAll(inboxTasks.where((t) {
               final dateToCheck = t.scheduledDate ?? t.createdAt;
               return AnalyticsHelper.isSameDay(dateToCheck, _selectedDate);
           }));
        } catch (_) {
           // No Inbox, or no inbox tasks
        }
        
        // Check tasks
        final hasPlan = tasks.isNotEmpty;
        
        if (hasPlan && _generatedPlan == null) {
          // MODE B: DASHBOARD (Plan Exists)
          
          // Find active task for Timer (Prioritize Focused ID, then Started Task)
          GoalTask? activeTask;
          
          if (provider.focusedTaskId != null) {
              try {
                  activeTask = tasks.firstWhere((t) => t.id == provider.focusedTaskId);
              } catch (_) {
                  // Focused task might be in another goal or hidden, try finding in all tasks
                  try {
                       activeTask = provider.allTasks.firstWhere((t) => t.id == provider.focusedTaskId);
                  } catch (e) {
                       // Task might be deleted
                  }
              }
          }
          
          // Fallback: If no focus but something is running (e.g. app restart), show that
          if (activeTask == null) {
              try {
                 activeTask = tasks.firstWhere((t) => t.startedAt != null);
              } catch (_) {
                  try {
                      // Check globally if not in today's view
                      activeTask = provider.allTasks.firstWhere((t) => t.startedAt != null);
                  } catch (_) {}
              }
          }

          // Sort tasks for timeline
          tasks.sort((a, b) {
            final aTime = _getSortableTime(a);
            final bTime = _getSortableTime(b);
            return aTime.compareTo(bTime);
          });

          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: SafeArea(
              child: CustomScrollView(
                slivers: [
                  // 1. Header & Date Strip
                  SliverToBoxAdapter(
                    child: _buildDateHeader(theme, textColor, subtleColor),
                  ),

                  // 2. Active Timer (Floating at top if Focus is active)
                  if (activeTask != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ActiveTaskTimer(task: activeTask),
                      ),
                    ),

                  // 3. Timeline Content (Converted to Slivers)
                  _buildTimelineSliver(context, provider, tasks, activeTask?.id, isDark, textColor, subtleColor),
                ],
              ),
            ),
            floatingActionButton: Padding(
              padding: const EdgeInsets.only(bottom: 100.0), // Clear nav bar
              child: FloatingActionButton(
                heroTag: "day_planner_fab_mode_b",
                onPressed: () => _showQuickAdd(context, provider),
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          );
        }

        // MODE A: MORNING DUMP (No Plan or Creating New)
        // ... (Keep existing implementation) ...
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          // Removed AppBar to match Timeline style

          floatingActionButton: _generatedPlan == null ? Padding(
                padding: const EdgeInsets.only(bottom: 90), 
                child: FloatingActionButton(
                    heroTag: "day_planner_fab_mode_a",
                    onPressed: () => _showQuickAdd(context, provider),
                    backgroundColor: AppTheme.primaryColor,
                    tooltip: "Add Manual Task",
                    child: const Icon(Icons.add, color: Colors.white),
                ),
            ) : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          body: SafeArea(
            child: Column(
              children: [
                // 1. Unified Header
                _buildDateHeader(theme, textColor, subtleColor),
                
                // 1. Input Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20), // Add top spacing for scroll
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
                        const SizedBox(height: 100), // Bottom padding for keyboard/FAB
                      ],
                    ),
                  ),
                ),
                ],
              ),
          ),
        );
      },
    );
  }

  // --- Helpers for Timeline UI ---

  DateTime _getSortableTime(GoalTask task) {
    if (task.scheduledDate != null) {
      if (task.scheduledDate!.hour == 0 && task.scheduledDate!.minute == 0) {
        // Map fuzzy times to approximate hours for sorting
        if (task.suggestedTime == 'morning') return DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day, 9);
        if (task.suggestedTime == 'afternoon') return DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day, 14);
        if (task.suggestedTime == 'evening') return DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day, 18);
        return DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day, 12); // "Any" -> Noon
      }
      return task.scheduledDate!;
    }
    return DateTime.now().add(const Duration(days: 365)); // Put undefined at end
  }

  Widget _buildDateHeader(ThemeData theme, Color textColor, Color subtleColor) {
    // Generate dates for the strip (e.g., this week)
    // For simplicity, we center on _selectedDate and show +/- 3 days
    final startDate = _selectedDate.subtract(const Duration(days: 3));
    final dates = List.generate(7, (index) => startDate.add(Duration(days: index)));

    return Container(
      color: theme.scaffoldBackgroundColor, // Or specific header color
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        children: [
          // Month Year Row with Calendar Icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(_selectedDate),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24, 
                    fontWeight: FontWeight.bold
                  ),
                ),
                IconButton(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month, color: AppTheme.primaryColor),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Horizontal Date Strip
          SizedBox(
            height: 70, 
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 20),
              itemBuilder: (context, index) {
                final date = dates[index];
                final isSelected = AnalyticsHelper.isSameDay(date, _selectedDate);
                final isToday = AnalyticsHelper.isSameDay(date, DateTime.now());
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedDate = date),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('E').format(date), 
                        style: TextStyle(
                          color: isSelected 
                              ? AppTheme.primaryColor 
                              : (isToday ? textColor : subtleColor),
                          fontWeight: FontWeight.w600
                        )
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected ? Border.all(color: AppTheme.primaryColor) : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "${date.day}",
                          style: TextStyle(
                            color: isSelected ? Colors.white : textColor,
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSliver(BuildContext context, GrowthProvider provider, List<GoalTask> tasks, int? activeTaskId, bool isDark, Color textColor, Color subtleColor) {
     return SliverPadding(
       padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
       sliver: SliverList(
         delegate: SliverChildListDelegate([
           // 1. Rise and Shine Anchor
           _buildTimelineAnchor(
             icon: Icons.wb_sunny_rounded,
             time: _wakeUpTime.format(context),
             title: _wakeUpTitle,
             color: AppTheme.primaryColor,
             isStart: true,
             isDark: isDark,
             textColor: textColor,
             subtleColor: subtleColor,
             onTap: () => _showEditAnchorDialog(true),
           ),
           
           // 2. Task List
           if (tasks.isEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 40),
               child: Text(
                 "No tasks scheduled yet. Tap + to add one!", 
                 style: TextStyle(color: subtleColor.withOpacity(0.5)),
                 textAlign: TextAlign.center,
               ),
             )
           else
             ...tasks.asMap().entries.map((entry) {
               final index = entry.key;
               final task = entry.value;
               return TimelineTaskTile(
                 task: task,
                 isFirst: index == 0,
                 isLast: index == tasks.length - 1,
                 isPast: task.isCompleted, 
                 onTap: () => _showEditTask(task, provider),
                 onDelete: () {
                   setState(() {});
                   provider.deleteTask(task.id);
                 },
                 onToggle: (val) {
                   if (val == true) {
                      provider.completeTask(task.id);
                   } else {
                      provider.uncompleteTask(task.id);
                   }
                 },
                 onToggleTimer: () => provider.toggleTaskTimer(task.id),
               );
             }),

           // 3. Wind Down Anchor
           _buildTimelineAnchor(
             icon: Icons.nights_stay_rounded,
             time: _bedTime.format(context),
             title: _bedTimeTitle,
             color: const Color(0xFF6C757D), 
             isStart: false,
             isDark: isDark,
             textColor: textColor,
             subtleColor: subtleColor,
             onTap: () => _showEditAnchorDialog(false),
           ),
         ]),
       ),
     );
  }

  Widget _buildTimelineAnchor({
    required IconData icon,
    required String time,
    required String title,
    required Color color,
    required bool isStart,
    required bool isDark,
    required Color textColor,
    required Color subtleColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             // Time
             SizedBox(
               width: 80,
               child: Padding(
                 padding: const EdgeInsets.symmetric(vertical: 20),
                 child: Text(
                   time,
                   textAlign: TextAlign.right,
                   style: TextStyle(
                     color: subtleColor, // Use subtleColor
                     fontWeight: FontWeight.w600,
                     fontSize: 12,
                   ),
                 ),
               ),
             ),
             // Line & Node
             SizedBox(
                width: 40,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                     if (isStart)
                       Positioned(
                         top: 40, bottom: 0, 
                         child: Container(width: 2, color: subtleColor.withOpacity(0.3))
                       ),
                     if (!isStart)
                       Positioned(
                         top: 0, bottom: 40, 
                         child: Container(width: 2, color: subtleColor.withOpacity(0.3))
                       ),
                     
                     Container(
                       margin: const EdgeInsets.only(top: 10),
                       width: 50, height: 50,
                       decoration: BoxDecoration(
                         color: isStart ? color : (isDark ? const Color(0xFF3E3E42) : Colors.grey.shade300),
                         shape: BoxShape.circle,
                       ),
                       child: Icon(icon, color: isStart || isDark ? Colors.white : Colors.black54, size: 24),
                     ),
                  ],
                )
             ),
             // Title
             Expanded(
               child: Padding(
                 padding: const EdgeInsets.only(left: 16, top: 24),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: textColor, 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                      if (isStart) ...[
                        const SizedBox(height: 4),
                      ]
                   ],
                 )
               )
             )
          ],
        ),
      ),
    );
  }

  void _showEditTask(GoalTask task, GrowthProvider provider) {
     showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => QuickTaskInputSheet(
              isEditing: true,
              initialTitle: task.title,
              initialPriority: task.priority,
              initialTags: [],
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
  }

}
