import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../core/services/sound_service.dart';
import '../providers/growth_provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import '../../data/models/goal_task.dart';
import '../theme/theme.dart';
import 'daily_report_screen.dart';
import 'day_planner_history_screen.dart';
import '../widgets/active_task_timer.dart';
import '../widgets/quick_task_input_sheet.dart';
import '../utils/analytics_helper.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../widgets/streak_counter.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/avatar_widget.dart';
import 'avatar_editor_screen.dart';

class DayPlannerScreen extends StatefulWidget {
  final DateTime? initialDate;

  const DayPlannerScreen({super.key, this.initialDate});

  @override
  State<DayPlannerScreen> createState() => _DayPlannerScreenState();
}

class _DayPlannerScreenState extends State<DayPlannerScreen> with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ScrollController _scrollController = ScrollController();

  bool _isConverting = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  List<Map<String, dynamic>>? _generatedPlan;
  Timer? _rolloverTimer;
  bool _isViewingToday = true;
  late DateTime _selectedDate;
  late ConfettiController _confettiController;
  StreamSubscription? _levelSubscription;

  // Schedule Settings
  TimeOfDay _wakeUpTime = const TimeOfDay(hour: 8, minute: 0);
  String _wakeUpTitle = "Rise and Shine";
  TimeOfDay _bedTime = const TimeOfDay(hour: 22, minute: 0);
  String _bedTimeTitle = "Wind Down";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _selectedDate = widget.initialDate ?? DateTime.now();
    _isViewingToday = AnalyticsHelper.isSameDay(_selectedDate, DateTime.now());

    _initSpeech();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<GrowthProvider>();
      _levelSubscription = provider.levelUpStream.listen((newLevel) {
         if (mounted) {
           showDialog(
             context: context,
             barrierDismissible: false,
             builder: (_) => LevelUpOverlay(
               newLevel: newLevel,
               onDismiss: () => Navigator.of(context).pop(),
             ),
           );
         }
      });
    });
    _startRolloverCheck();
    _loadScheduleSettings();

    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
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
                    Navigator.pop(context);
                    if (isWakeUp) {
                       setState(() => _wakeUpTime = picked);
                    } else {
                       setState(() => _bedTime = picked);
                    }
                    _showEditAnchorDialog(isWakeUp);
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
    _confettiController.dispose();
    _levelSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startRolloverCheck() {
    _rolloverTimer = Timer.periodic(const Duration(minutes: 1), (_) => _checkRollover());
  }

  void _checkRollover() {
    if (!mounted) return;

    final now = DateTime.now();

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
      _checkRollover();
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

    final gpt = PrivacyGptService();
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

    try {
      final provider = context.read<GrowthProvider>();

      final goalId = await provider.ensureDailyGoal(_selectedDate);

      for (var item in plan) {
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
          scheduledDate: finalDate,
        );

        await provider.createTask(task);
      }

      if (mounted) {
        _inputController.clear();
        _generatedPlan = null;

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
              onSubmit: (title, date, priority, tags, repeat) async {
                  final goalId = await provider.ensureDailyGoal(_selectedDate);
                  final task = GoalTask(
                      id: 0,
                      goalId: goalId,
                      title: title,
                      description: '',
                      priority: priority,
                      createdAt: DateTime.now(),
                      scheduledDate: _selectedDate,
                      frequency: repeat ?? 'one-time',
                  );
                  await provider.createTask(task);
                  if (mounted) Navigator.pop(context);
              },
              initialDate: _selectedDate,
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
        _isViewingToday = AnalyticsHelper.isSameDay(picked, DateTime.now());
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? LumioColors.backgroundDark : const Color(0xFFF8F7F6);
    final surfaceColor = isDark ? LumioColors.surfaceDark : Colors.white;
    final textColor = isDark ? LumioColors.textPrimaryDark : const Color(0xFF1A150F);
    final subtleColor = isDark ? LumioColors.textSecondaryDark : const Color(0xFF917755);
    final dividerColor = isDark ? const Color(0xFF403A32) : const Color(0xFFE5DDD2);

    return Consumer<GrowthProvider>(
      builder: (context, provider, _) {
        final isToday = AnalyticsHelper.isSameDay(_selectedDate, DateTime.now());
        final dateStr = "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
        final goalName = "Daily Plan - $dateStr";

        List<GoalTask> tasks = [];

        try {
           final dailyPlanGoal = provider.goals.firstWhere((g) => g.name == goalName);
           tasks.addAll(provider.getTasksForGoal(dailyPlanGoal.id));
        } catch (_) {}

        try {
           final inboxGoal = provider.goals.firstWhere((g) => g.name == 'Inbox');
           final inboxTasks = provider.getTasksForGoal(inboxGoal.id);
           tasks.addAll(inboxTasks.where((t) {
               final dateToCheck = t.scheduledDate ?? t.createdAt;
               return AnalyticsHelper.isSameDay(dateToCheck, _selectedDate);
           }));
        } catch (_) {}

        final hasPlan = tasks.isNotEmpty;

        if (hasPlan && _generatedPlan == null) {
          GoalTask? activeTask;

          if (provider.focusedTaskId != null) {
              try {
                  activeTask = tasks.firstWhere((t) => t.id == provider.focusedTaskId);
              } catch (_) {
                  try {
                       activeTask = provider.allTasks.firstWhere((t) => t.id == provider.focusedTaskId);
                  } catch (e) {}
              }
          }

          if (activeTask == null) {
              try {
                 activeTask = tasks.firstWhere((t) => t.startedAt != null);
              } catch (_) {
                  try {
                      activeTask = provider.allTasks.firstWhere((t) => t.startedAt != null);
                  } catch (_) {}
              }
          }

          tasks.sort((a, b) {
            final aTime = _getSortableTime(a);
            final bTime = _getSortableTime(b);
            return aTime.compareTo(bTime);
          });

          return Scaffold(
            backgroundColor: backgroundColor,
            body: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      // Header
                      _buildStitchHeader(context, provider, isDark, textColor, subtleColor, surfaceColor, dividerColor),

                      // Main Content
                      Expanded(
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 100),
                          children: [
                            // AI Schedule Optimized Card
                            _buildAIInsightCard(context, tasks, isDark, textColor, subtleColor, surfaceColor),

                            // Week Date Picker
                            _buildWeekDatePicker(isDark, textColor, subtleColor, surfaceColor, dividerColor),

                            const SizedBox(height: 16),

                            // Timeline
                            _buildTimeline(context, provider, tasks, activeTask?.id, isDark, textColor, subtleColor, surfaceColor, dividerColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    displayTarget: false,
                    gravity: 0.3,
                    numberOfParticles: 20,
                    colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple],
                  ),
                ),
              ],
            ),
          );
        }

        // MODE A: MORNING DUMP (No Plan)
        return Scaffold(
          backgroundColor: backgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildStitchHeader(context, provider, isDark, textColor, subtleColor, surfaceColor, dividerColor),

                // Week Date Picker
                _buildWeekDatePicker(isDark, textColor, subtleColor, surfaceColor, dividerColor),

                // Input Section
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.wb_sunny_outlined,
                          size: 64,
                          color: LumioColors.primary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          isToday ? "What needs to happen today?" : "Plan for ${DateFormat('MMM d').format(_selectedDate)}",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Dump your thoughts. We'll structure them.",
                          style: TextStyle(color: subtleColor, fontSize: 14),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: dividerColor),
                          ),
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              TextField(
                                controller: _inputController,
                                style: TextStyle(color: textColor, fontSize: 16),
                                maxLines: 6,
                                decoration: InputDecoration(
                                  hintText: "e.g., Finish the report, call John at 2pm, gym at 5...",
                                  hintStyle: TextStyle(color: subtleColor.withOpacity(0.5)),
                                  filled: true,
                                  fillColor: Colors.transparent,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Material(
                                  color: _isListening ? LumioColors.error : LumioColors.primary,
                                  borderRadius: BorderRadius.circular(24),
                                  child: InkWell(
                                    onTap: _toggleListening,
                                    borderRadius: BorderRadius.circular(24),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      alignment: Alignment.center,
                                      child: Icon(
                                        _isListening ? Icons.stop : Icons.mic,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isConverting ? null : _generatePlan,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: LumioColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: LumioColors.primary.withOpacity(0.4),
                            ),
                            child: _isConverting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    "Structure My Day",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => _showQuickAdd(context, provider),
                          icon: Icon(Icons.add, color: subtleColor),
                          label: Text(
                            "Or add a task manually",
                            style: TextStyle(color: subtleColor),
                          ),
                        ),
                        const SizedBox(height: 100),
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

  String _getUserName() {
    try {
      final authProvider = context.read<app_auth.AuthProvider>();
      final name = authProvider.user?.displayName ?? 'there';
      return name.split(' ').first;
    } catch (_) {
      return 'there';
    }
  }

  Widget _buildStitchHeader(
    BuildContext context,
    GrowthProvider provider,
    bool isDark,
    Color textColor,
    Color subtleColor,
    Color surfaceColor,
    Color dividerColor,
  ) {
    final userName = _getUserName();
    final isToday = AnalyticsHelper.isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          // Profile Avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AvatarEditorScreen()),
              );
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: LumioColors.primary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: AvatarWidget(
                  config: provider.avatarConfig,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Greeting & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${_getGreeting()}, $userName",
                  style: TextStyle(
                    color: subtleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: _pickDate,
                  child: Row(
                    children: [
                      Text(
                        isToday
                            ? "Today, ${DateFormat('MMM d').format(_selectedDate)}"
                            : DateFormat('EEE, MMM d').format(_selectedDate),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.expand_more,
                        color: subtleColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Notification Button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: surfaceColor,
              shape: BoxShape.circle,
              border: Border.all(color: dividerColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              onPressed: () {},
              icon: Icon(Icons.notifications_outlined, color: textColor, size: 22),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightCard(
    BuildContext context,
    List<GoalTask> tasks,
    bool isDark,
    Color textColor,
    Color subtleColor,
    Color surfaceColor,
  ) {
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final totalCount = tasks.length;
    final titleText = tasks.isEmpty ? "Plan Your Day" : "Schedule Overview";
    final subtitleText = tasks.isEmpty
        ? "Your tasks have been organized for optimal focus. Deep work is scheduled during your peak hours."
        : "$completedCount of $totalCount tasks done today";
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [LumioColors.surfaceDark, const Color(0xFF322C24)]
              : [surfaceColor, const Color(0xFFFDFBF7)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LumioColors.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            top: -8,
            right: -8,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: LumioColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: LumioColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: LumioColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          color: subtleColor,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Review Button
                Material(
                  color: LumioColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        "Review",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildWeekDatePicker(
    bool isDark,
    Color textColor,
    Color subtleColor,
    Color surfaceColor,
    Color dividerColor,
  ) {
    final startDate = _selectedDate.subtract(const Duration(days: 3));
    final dates = List.generate(7, (index) => startDate.add(Duration(days: index)));

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = AnalyticsHelper.isSameDay(date, _selectedDate);
          final isToday = AnalyticsHelper.isSameDay(date, DateTime.now());

          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = date;
              _isViewingToday = AnalyticsHelper.isSameDay(date, DateTime.now());
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              decoration: BoxDecoration(
                color: isSelected ? LumioColors.primary : surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: isSelected ? null : Border.all(color: dividerColor),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: LumioColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).substring(0, 3),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : subtleColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${date.day}",
                    style: TextStyle(
                      color: isSelected ? Colors.white : textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isToday && !isSelected) ...[
                    const SizedBox(height: 2),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: LumioColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    GrowthProvider provider,
    List<GoalTask> tasks,
    int? activeTaskId,
    bool isDark,
    Color textColor,
    Color subtleColor,
    Color surfaceColor,
    Color dividerColor,
  ) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Section header with + button
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AnalyticsHelper.isSameDay(_selectedDate, DateTime.now())
                      ? "Today's Tasks"
                      : DateFormat('MMM d\'s Tasks').format(_selectedDate),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showQuickAdd(context, provider),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: LumioColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: LumioColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Timeline with tasks
          ...tasks.asMap().entries.map((entry) {
            final index = entry.key;
            final task = entry.value;
            final taskTime = _getSortableTime(task);
            final taskMinutes = taskTime.hour * 60 + taskTime.minute;
            final isActive = task.id == activeTaskId;
            final isPast = task.isCompleted;

            // Check if current time indicator should appear before this task
            final showCurrentTimeBeforeThis = index == 0
                ? currentMinutes < taskMinutes
                : false;

            // Check if current time indicator should appear after this task
            bool showCurrentTimeAfterThis = false;
            if (index < tasks.length - 1) {
              final nextTask = tasks[index + 1];
              final nextTaskTime = _getSortableTime(nextTask);
              final nextTaskMinutes = nextTaskTime.hour * 60 + nextTaskTime.minute;
              showCurrentTimeAfterThis = AnalyticsHelper.isSameDay(_selectedDate, now) &&
                  currentMinutes >= taskMinutes &&
                  currentMinutes < nextTaskMinutes;
            }

            return Column(
              children: [
                if (showCurrentTimeBeforeThis && AnalyticsHelper.isSameDay(_selectedDate, now))
                  _buildCurrentTimeIndicator(now, subtleColor),

                _buildTimelineTaskCard(
                  context,
                  provider,
                  task,
                  isActive: isActive,
                  isPast: isPast,
                  isDark: isDark,
                  textColor: textColor,
                  subtleColor: subtleColor,
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),

                // Current time indicator after this task if needed
                if (showCurrentTimeAfterThis)
                  _buildCurrentTimeIndicator(now, subtleColor),
              ],
            );
          }),

          // Free slot at the end
          _buildFreeSlot(isDark, subtleColor, dividerColor),
        ],
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(DateTime now, Color subtleColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              DateFormat('HH:mm').format(now),
              style: TextStyle(
                color: LumioColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: LumioColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: LumioColors.primary.withOpacity(0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: LumioColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTaskCard(
    BuildContext context,
    GrowthProvider provider,
    GoalTask task, {
    required bool isActive,
    required bool isPast,
    required bool isDark,
    required Color textColor,
    required Color subtleColor,
    required Color surfaceColor,
    required Color dividerColor,
  }) {
    final taskTime = _getSortableTime(task);
    final timeStr = DateFormat('HH:mm').format(taskTime);
    final progress = task.startedAt != null && task.estimatedMinutes != null
        ? DateTime.now().difference(task.startedAt!).inMinutes / task.estimatedMinutes!
        : 0.0;

    // Get tag color based on priority/type
    Color tagColor;
    String tagLabel;
    switch (task.priority) {
      case 'high':
        tagColor = LumioColors.primary;
        tagLabel = 'Priority';
        break;
      case 'low':
        tagColor = Colors.green;
        tagLabel = 'Easy';
        break;
      default:
        tagColor = Colors.indigo;
        tagLabel = 'Task';
    }

    // Secondary tag based on suggested time
    Color? secondaryTagColor;
    String? secondaryTagLabel;
    if (task.suggestedTime == 'morning') {
      secondaryTagColor = const Color(0xFF917755);
      secondaryTagLabel = 'Morning';
    } else if (task.suggestedTime == 'afternoon') {
      secondaryTagColor = Colors.orange;
      secondaryTagLabel = 'Afternoon';
    } else if (task.suggestedTime == 'evening') {
      secondaryTagColor = Colors.purple;
      secondaryTagLabel = 'Evening';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isPast ? 0.6 : 1.0,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time
            SizedBox(
              width: 48,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  timeStr,
                  style: TextStyle(
                    color: isActive ? LumioColors.primary : subtleColor,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Task Card
            Expanded(
              child: GestureDetector(
                onTap: () => _showEditTask(task, provider),
                child: Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border(
                      left: BorderSide(
                        color: isActive ? LumioColors.primary : Colors.transparent,
                        width: 4,
                      ),
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: LumioColors.primary.withOpacity(0.1),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Drag indicator
                        Positioned(
                          right: 8,
                          top: 0,
                          bottom: 0,
                          child: Icon(
                            Icons.drag_indicator,
                            color: subtleColor.withOpacity(0.3),
                            size: 20,
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 32, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tags
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _buildTag(tagLabel, tagColor, isDark),
                                  if (secondaryTagLabel != null)
                                    _buildTag(secondaryTagLabel, secondaryTagColor!, isDark),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Title
                              Text(
                                task.title,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration: isPast ? TextDecoration.lineThrough : null,
                                ),
                              ),

                              // Description
                              if (task.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  task.description,
                                  style: TextStyle(
                                    color: subtleColor,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              // Footer: Time/Collaborators
                              if (task.estimatedMinutes != null || isActive) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    if (isActive) ...[
                                      Icon(Icons.timer, size: 14, color: subtleColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${((1 - progress.clamp(0.0, 1.0)) * (task.estimatedMinutes ?? 30)).toInt()}m left",
                                        style: TextStyle(
                                          color: subtleColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ] else if (task.estimatedMinutes != null) ...[
                                      Icon(Icons.schedule, size: 14, color: subtleColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${task.estimatedMinutes}m",
                                        style: TextStyle(
                                          color: subtleColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    const Spacer(),
                                    // Checkbox
                                    GestureDetector(
                                      onTap: () {
                                        if (isPast) {
                                          provider.uncompleteTask(task.id);
                                        } else {
                                          provider.completeTask(task.id);
                                          _confettiController.play();
                                        }
                                      },
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: isPast ? LumioColors.primary : Colors.transparent,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isPast ? LumioColors.primary : dividerColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: isPast
                                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Progress bar at bottom for active task
                        if (isActive && progress > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 3,
                              color: dividerColor.withOpacity(0.3),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(color: LumioColors.primary),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildFreeSlot(bool isDark, Color subtleColor, Color dividerColor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              "",
              style: TextStyle(color: subtleColor, fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: dividerColor,
                  width: 2,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 16, color: subtleColor.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Text(
                    "Free Slot",
                    style: TextStyle(
                      color: subtleColor.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _getSortableTime(GoalTask task) {
    if (task.scheduledDate != null) {
      if (task.scheduledDate!.hour == 0 && task.scheduledDate!.minute == 0) {
        if (task.suggestedTime == 'morning') return DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day, 9);
        if (task.suggestedTime == 'afternoon') return DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day, 14);
        if (task.suggestedTime == 'evening') return DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day, 18);
        return DateTime(task.scheduledDate!.year, task.scheduledDate!.month, task.scheduledDate!.day, 12);
      }
      return task.scheduledDate!;
    }
    return DateTime.now().add(const Duration(days: 365));
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
              onSubmit: (title, date, priority, tags, repeat) {
                  final updatedTask = task.copyWith(
                      title: title,
                      priority: priority,
                      frequency: repeat ?? 'one-time',
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
