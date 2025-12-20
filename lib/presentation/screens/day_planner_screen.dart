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

class DayPlannerScreen extends StatefulWidget {
  const DayPlannerScreen({super.key});

  @override
  State<DayPlannerScreen> createState() => _DayPlannerScreenState();
}

class _DayPlannerScreenState extends State<DayPlannerScreen> {
  final _inputController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isConverting = false;
  bool _isListening = false;
  bool _speechAvailable = false;
  List<Map<String, dynamic>>? _generatedPlan;

  @override
  void initState() {
    super.initState();
    _initSpeech();
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
      setState(() {});
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
      
      // 1. Ensure Daily Goal Exists
      final goalId = await provider.ensureDailyGoal(DateTime.now());
      
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
          // Set scheduledDate to today
          scheduledDate: DateTime.now(),
        );
        
        await provider.createTask(task);
      }

      if (mounted) {
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtleColor = isDark ? Colors.white54 : Colors.black54;

    return Consumer<GrowthProvider>(
      builder: (context, provider, _) {
        // Check for existing plan
        final today = DateTime.now();
        final dateStr = "${today.year}-${today.month}-${today.day}";
        final goalName = "Daily Plan - $dateStr";
        
        // Find goal
        int? dayGoalId;
        try {
          final goal = provider.goals.firstWhere((g) => g.name == goalName);
          dayGoalId = goal.id;
        } catch (_) {}
        
        // Check tasks
        final hasPlan = dayGoalId != null && provider.getTasksForGoal(dayGoalId).isNotEmpty;
        
        if (hasPlan && _generatedPlan == null) {
          // MODE B: DASHBOARD (Plan Exists)
          final tasks = provider.getTasksForGoal(dayGoalId!);
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            appBar: AppBar(
              title: Text('Today\'s Plan', style: TextStyle(color: textColor)),
              backgroundColor: Colors.transparent,
              iconTheme: IconThemeData(color: textColor),
              actions: [
                 IconButton(
                   icon: Icon(Icons.analytics_outlined, color: textColor),
                   onPressed: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportScreen()));
                   },
                 )
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: tasks.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Card(
                          color: isDark ? const Color(0xFF1E1E20) : Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
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
                            subtitle: Text(
                              "${task.estimatedMinutes ?? 0}m est • ${task.actualMinutes ?? 0}m act",
                              style: TextStyle(color: subtleColor),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                task.startedAt != null ? Icons.stop_circle : Icons.play_circle_fill,
                                color: task.startedAt != null ? AppTheme.errorColor : AppTheme.primaryColor,
                              ),
                              onPressed: () {
                                provider.toggleTaskTimer(task.id);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                           Navigator.push(context, MaterialPageRoute(builder: (_) => DailyReportScreen()));
                        },
                        icon: const Icon(Icons.summarize),
                        label: const Text("View Daily Retro"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppTheme.darkSurfaceElevated : AppTheme.surfaceColor,
                          foregroundColor: textColor,
                          elevation: 0,
                          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
                        ),
                      ),
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
            title: Text('The Day Architect', style: TextStyle(color: textColor)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
          ),
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
                            "What needs to happen today?",
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
