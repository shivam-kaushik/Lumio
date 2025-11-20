import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/services/text_to_speech_service.dart';
import '../../core/services/permission_service.dart';
import '../../data/repositories/firestore_growth_repository.dart';

/// Voice-based completion handler for hands-free task completion
class VoiceCompletionHandler {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final FirestoreGrowthRepository _growthRepository = FirestoreGrowthRepository();

  /// Handle voice completion ("Done" command)
  Future<bool> handleVoiceCompletion({
    required int subtaskId,
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

      // Complete the goal task
      await _growthRepository.completeTask(subtaskId);

      // Generate voice feedback
      final feedbackMessage =
          taskDescription.isNotEmpty
              ? 'Task "$taskDescription" completed. Great work!'
              : 'Task completed! Great work!';

      // Speak feedback
      await _ttsService.speak(feedbackMessage);
      onComplete(feedbackMessage);

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

