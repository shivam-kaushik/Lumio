import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/growth_provider.dart';
import '../theme/theme.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../core/services/text_to_speech_service.dart';
import '../../core/services/permission_service.dart';
import '../../data/models/subtask.dart' show Task;
import 'goal_planning_screen.dart';

/// Hands-free voice-based goal creation screen
class VoiceGoalCreationScreen extends StatefulWidget {
  const VoiceGoalCreationScreen({super.key});

  @override
  State<VoiceGoalCreationScreen> createState() => _VoiceGoalCreationScreenState();
}

class _VoiceGoalCreationScreenState extends State<VoiceGoalCreationScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final PrivacyGptService _gptService = PrivacyGptService();
  
  bool _isListening = false;
  bool _isProcessing = false;
  String _transcribedText = '';
  String _currentQuestion = '';
  String _goalDescription = '';
  DateTime? _targetDeadline;
  double? _hoursPerDay;
  Map<String, dynamic>? _roadmap;
  
  int _conversationStep = 0; // 0: goal, 1: deadline, 2: hours, 3: confirm

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _startConversation();
  }

  Future<void> _startConversation() async {
    setState(() {
      _currentQuestion = 'Great! I can help you turn your goal into a plan. What goal would you like to work on?';
    });
    
    // Speak the question
    await _ttsService.speak(_currentQuestion);
    
    // Wait a moment, then start listening
    await Future.delayed(const Duration(seconds: 2));
    await _startListening();
  }

  Future<void> _startListening() async {
    final permissionService = PermissionService();
    final hasPermission = await permissionService.requestMicrophonePermission();
    
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      return;
    }

    final available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _isListening = true);
    }

    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _transcribedText = result.recognizedWords;
            if (result.finalResult) {
              _isListening = false;
              _handleUserResponse(result.recognizedWords);
            }
          });
        }
      },
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      ),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _handleUserResponse(String response) async {
    setState(() => _isProcessing = true);

    try {
      switch (_conversationStep) {
        case 0: // Goal description
          await _handleGoalDescription(response);
          break;
        case 1: // Deadline
          await _handleDeadline(response);
          break;
        case 2: // Hours per day
          await _handleHoursPerDay(response);
          break;
        case 3: // Confirmation
          await _handleConfirmation(response);
          break;
      }
    } catch (e) {
      debugPrint('Error handling response: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleGoalDescription(String response) async {
    _goalDescription = response;
    
    setState(() {
      _currentQuestion = "Got it! When do you want to achieve this goal? You can say something like 'in 3 months' or 'by December 31st'.";
      _conversationStep = 1;
    });

    await _ttsService.speak(_currentQuestion);
    await Future.delayed(const Duration(seconds: 2));
    await _startListening();
  }

  Future<void> _handleDeadline(String response) async {
    // Simple date parsing (can be enhanced with NLP)
    final now = DateTime.now();
    DateTime? deadline;
    
    // Try to parse common patterns
    if (response.toLowerCase().contains('month')) {
      final months = _extractNumber(response) ?? 3;
      deadline = now.add(Duration(days: months * 30));
    } else if (response.toLowerCase().contains('week')) {
      final weeks = _extractNumber(response) ?? 4;
      deadline = now.add(Duration(days: weeks * 7));
    } else if (response.toLowerCase().contains('day')) {
      final days = _extractNumber(response) ?? 30;
      deadline = now.add(Duration(days: days));
    } else {
      // Default to 3 months
      deadline = now.add(const Duration(days: 90));
    }

    _targetDeadline = deadline;
    
    setState(() {
      _currentQuestion = "Perfect! How many hours per day can you work on this? For example, say 'one hour' or 'two hours'.";
      _conversationStep = 2;
    });

    await _ttsService.speak(_currentQuestion);
    await Future.delayed(const Duration(seconds: 2));
    await _startListening();
  }

  Future<void> _handleHoursPerDay(String response) async {
    // Extract number from response
    final hours = _extractNumber(response)?.toDouble() ?? 2.0;
    _hoursPerDay = hours;
    
    // Generate roadmap
    setState(() {
      _currentQuestion = "Great! I'm creating your roadmap now. This will take a moment...";
      _isProcessing = true;
    });

    await _ttsService.speak(_currentQuestion);
    
    // Generate roadmap using GPT
    final roadmap = await _gptService.generateDetailedRoadmap(
      _goalDescription,
      targetDeadline: _targetDeadline!,
      hoursPerDay: _hoursPerDay!,
    );

    if (roadmap == null) {
      setState(() {
        _currentQuestion = 'I had trouble creating the roadmap. Let\'s try again.';
      });
      await _ttsService.speak(_currentQuestion);
      return;
    }

    _roadmap = roadmap;
    
    // Summarize the roadmap
    final subtasks = (roadmap['subtasks'] as List?) ?? [];
    final phases = _groupSubtasksIntoPhases(subtasks);
    
      final summary = 
          'I\'ve created a roadmap with ${phases.length} phases and ${subtasks.length} tasks. '
          'Do you want me to schedule everything automatically? Say \'yes\' to continue or \'no\' to review first.';
    
    setState(() {
      _currentQuestion = summary;
      _conversationStep = 3;
      _isProcessing = false;
    });

    await _ttsService.speak(summary);
    await Future.delayed(const Duration(seconds: 2));
    await _startListening();
  }

  Future<void> _handleConfirmation(String response) async {
    final confirmed = response.toLowerCase().contains('yes') || 
                     response.toLowerCase().contains('sure') ||
                     response.toLowerCase().contains('okay');
    
    if (!confirmed) {
      // Show review screen
      if (mounted) {
        await _showReviewScreen();
      }
      return;
    }

    // Create goal and schedule
    await _createGoalAndSchedule();
  }

  Future<void> _createGoalAndSchedule() async {
    setState(() {
      _currentQuestion = 'Perfect! Creating your goal and scheduling everything now...';
      _isProcessing = true;
    });

    await _ttsService.speak(_currentQuestion);

    try {
      final growthProvider = context.read<GrowthProvider>();

      // Create goal
      final goalId = await growthProvider.createGoal(
        _goalDescription,
        targetDeadline: _targetDeadline,
        hoursPerDay: _hoursPerDay,
        totalEstimatedHours: _roadmap?['totalEstimatedHours'] as int?,
      );

      // Navigate to planning screen
      if (mounted) {
        final tasks = (_roadmap!['subtasks'] as List)
            .map((s) => Task.fromMap(s as Map<String, dynamic>))
            .toList();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GoalPlanningScreen(
              goalId: goalId,
              goalName: _goalDescription,
              initialTasks: tasks,
              timeline: {
                'deadline': _targetDeadline,
                'hoursPerDay': _hoursPerDay,
              },
            ),
          ),
        );

        await _ttsService.speak('All set! Your goal has been created and tasks are scheduled. Let\'s get started!');
      }
    } catch (e) {
      debugPrint('Error creating goal: $e');
      await _ttsService.speak('I encountered an error. Please try again.');
    }
  }

  Future<void> _showReviewScreen() async {
    // Navigate to review screen (can be enhanced)
      await _ttsService.speak('Let me show you the plan for review.');
    
    // For now, proceed to planning screen
    if (_roadmap != null && _targetDeadline != null && _hoursPerDay != null) {
      final growthProvider = context.read<GrowthProvider>();
      
      final goalId = await growthProvider.createGoal(
        _goalDescription,
        targetDeadline: _targetDeadline,
        hoursPerDay: _hoursPerDay,
        totalEstimatedHours: _roadmap?['totalEstimatedHours'] as int?,
      );

      if (mounted) {
        final tasks = (_roadmap!['subtasks'] as List)
            .map((s) => Task.fromMap(s as Map<String, dynamic>))
            .toList();

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GoalPlanningScreen(
              goalId: goalId,
              goalName: _goalDescription,
              initialTasks: tasks,
              timeline: {
                'deadline': _targetDeadline,
                'hoursPerDay': _hoursPerDay,
              },
            ),
          ),
        );
      }
    }
  }

  int? _extractNumber(String text) {
    final numbers = RegExp(r'\d+').allMatches(text);
    if (numbers.isEmpty) return null;
    return int.tryParse(numbers.first.group(0) ?? '');
  }

  List<Map<String, dynamic>> _groupSubtasksIntoPhases(List<dynamic> subtasks) {
    // Simple phase grouping (can be enhanced)
    final phases = <Map<String, dynamic>>[];
    final chunkSize = (subtasks.length / 3).ceil();
    
    for (int i = 0; i < subtasks.length; i += chunkSize) {
      phases.add({
        'phase': (phases.length + 1),
        'subtasks': subtasks.sublist(i, (i + chunkSize).clamp(0, subtasks.length)),
      });
    }
    
    return phases;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Voice Goal Creation'),
        backgroundColor: AppTheme.surfaceColor,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Visual indicator
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening 
                    ? AppTheme.primaryColor.withOpacity(0.2)
                    : AppTheme.borderColor.withOpacity(0.1),
                border: Border.all(
                  color: _isListening 
                      ? AppTheme.primaryColor
                      : AppTheme.borderColor,
                  width: 3,
                ),
              ),
              child: Icon(
                _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                size: 48,
                color: _isListening 
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Current question
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                _currentQuestion.isEmpty 
                    ? 'Initializing...'
                    : _currentQuestion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            // Transcribed text
            if (_transcribedText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _transcribedText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            
            const Spacer(),
            
            // Manual input fallback
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _ttsService.stop();
    super.dispose();
  }
}

