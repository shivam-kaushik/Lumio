import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/services/text_to_speech_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/smart_nudge_service.dart';
import '../../data/repositories/growth_repository.dart';
import '../../data/models/skill.dart';

/// Voice-based completion handler for hands-free task completion
class VoiceCompletionHandler {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final SmartNudgeService _nudgeService = SmartNudgeService();
  final GrowthRepository _growthRepository = GrowthRepository();

  /// Handle voice completion ("Done" command)
  Future<bool> handleVoiceCompletion({
    required int subtaskId,
    required int? skillId,
    required String taskDescription,
    required Function(String message) onComplete,
  }) async {
    try {
      // Check for "done" or "complete" via voice
      final permissionService = PermissionService();
      final hasPermission = await permissionService.requestMicrophonePermission();
      
      if (!hasPermission) {
        return false;
      }

      final available = await _speech.initialize();
      if (!available) {
        return false;
      }

      // Listen for "done" command
      String? recognizedText;
      await _speech.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords.toLowerCase();
          if (result.finalResult) {
            _speech.stop();
          }
        },
        localeId: 'en_US',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
      );

      // Wait for result
      await Future.delayed(const Duration(seconds: 3));

      if (recognizedText == null) {
        return false;
      }

      // Check if user said "done" or similar
      final doneKeywords = ['done', 'complete', 'finished', 'yes', 'okay'];
      final isDone = doneKeywords.any((keyword) => recognizedText!.contains(keyword));

      if (!isDone) {
        return false;
      }

      // Complete the task
      await _growthRepository.completeSubtask(subtaskId);

      // Get updated skill info for feedback
      Skill? skill;
      if (skillId != null) {
        final skills = await _growthRepository.getSkills();
        skill = skills.firstWhere((s) => s.id == skillId, orElse: () => throw Exception());
      }

      // Generate voice feedback
      String feedbackMessage;
      if (skill != null) {
        feedbackMessage = 
            'Nice! You just completed a rep for ${skill.name}. '
            'Your streak is now ${skill.currentStreak} days.';
      } else {
        feedbackMessage = 'Task completed! Great work!';
      }

      // Speak feedback
      await _ttsService.speak(feedbackMessage);
      onComplete(feedbackMessage);

        // Check for momentum nudges
        if (skill != null && skillId != null) {
          final reps = await _growthRepository.getRepsForSkill(skillId);
        final now = DateTime.now();
        final weekAgo = now.subtract(const Duration(days: 7));
        final repsThisWeek = reps.where((r) => r.timestamp.isAfter(weekAgo)).length;

        if (repsThisWeek >= 6) {
          await _nudgeService.sendMomentumNudge(skill, repsThisWeek);
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error in voice completion: $e');
      return false;
    }
  }

  /// Quick voice confirmation (for notifications)
  Future<bool> quickVoiceConfirm() async {
    try {
      final permissionService = PermissionService();
      final hasPermission = await permissionService.requestMicrophonePermission();
      
      if (!hasPermission) {
        return false;
      }

      final available = await _speech.initialize();
      if (!available) {
        return false;
      }

      String? recognizedText;
      await _speech.listen(
        onResult: (result) {
          recognizedText = result.recognizedWords.toLowerCase();
          if (result.finalResult) {
            _speech.stop();
          }
        },
        localeId: 'en_US',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      if (recognizedText == null) {
        return false;
      }

      final confirmKeywords = ['done', 'yes', 'okay', 'complete'];
      return confirmKeywords.any((keyword) => recognizedText!.contains(keyword));
    } catch (e) {
      debugPrint('Error in quick voice confirm: $e');
      return false;
    }
  }
}

