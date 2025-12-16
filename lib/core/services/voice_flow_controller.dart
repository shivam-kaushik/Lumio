import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/text_to_speech_service.dart';
import '../services/privacy_gpt_service.dart';
import '../services/text_to_speech_service.dart';
import '../services/privacy_gpt_service.dart';
import '../services/permission_service.dart';
import '../models/conversation_models.dart'; // Add this import

enum VoiceState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

/// Orchestrates the hands-free conversation loop
class VoiceFlowController extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextToSpeechService _tts = TextToSpeechService();
  final PrivacyGptService _gpt = PrivacyGptService();
  final PermissionService _permissions = PermissionService();

  VoiceState _state = VoiceState.idle;
  String _currentTranscript = '';
  String _lastSystemMessage = '';
  ConversationResponse? _lastResponse; // Add this
  List<Map<String, String>> _conversationHistory = [];
  
  // Streams for UI updates
  VoiceState get state => _state;
  String get currentTranscript => _currentTranscript;
  String get lastSystemMessage => _lastSystemMessage;
  ConversationResponse? get lastResponse => _lastResponse; // Add this

  bool _isSessionActive = false;
  Timer? _silenceTimer;

  /// Start the hands-free session
  Future<void> startSession() async {
    _isSessionActive = true;
    _conversationHistory.clear();
    
    // Check permissions
    final hasMic = await _permissions.requestMicrophonePermission();
    if (!hasMic) {
      _setError('Microphone permission denied');
      return;
    }

    // Initialize services
    final available = await _speech.initialize(
      onError: (e) => _handleError(e.errorMsg),
      onStatus: (s) => debugPrint('STT Status: $s'),
    );

    if (!available) {
      _setError('Speech recognition not available');
      return;
    }

    await _tts.initialize();

    // Start the loop with an intro
    await _speakAndListen("I'm listening. What goal would you like to achieve?");
  }

  /// Stop the session
  Future<void> stopSession() async {
    _isSessionActive = false;
    _silenceTimer?.cancel();
    await _speech.stop();
    await _tts.stop();
    _setState(VoiceState.idle);
  }

  /// speak text, then immediately listen
  Future<void> _speakAndListen(String text) async {
    if (!_isSessionActive) return;

    _lastSystemMessage = text;
    _addToHistory('system', text);
    _setState(VoiceState.speaking);

    debugPrint('🤖 AI SPEAKING: "$text"'); // Log AI speech

    // Speak
    await _tts.speak(text);

    // approximate wait for speech to finish (since flutter_tts completion handler can be flaky)
    // calculating duration: avg 150 words/min = 2.5 words/sec
    final wordCount = text.split(' ').length;
    final duration = Duration(milliseconds: (wordCount * 400) + 1000); 
    
    // Wait for speech to ideally finish
    await Future.delayed(duration);

    // Start Listening
    if (_isSessionActive) {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_isSessionActive) return;

    _setState(VoiceState.listening);
    _currentTranscript = '';
    notifyListeners();

    await _speech.listen(
      onResult: (result) {
        _currentTranscript = result.recognizedWords;
        notifyListeners();

        if (result.finalResult) {
          _processUserResponse(result.recognizedWords);
        }
      },
      localeId: 'en_US',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.search, // Optimized for short phrases
        cancelOnError: true,
        partialResults: true,
        onDevice: false,
      ),
    );

    // Safety timeout: if no speech detected for 5 seconds, prompt user
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 8), () {
      if (_state == VoiceState.listening && _currentTranscript.isEmpty) {
        _speech.stop();
        _speakAndListen("I didn't hear anything. Are you still there?");
      }
    });
  }

  Future<void> _processUserResponse(String userText) async {
    _silenceTimer?.cancel();
    if (userText.isEmpty) return;

    _setState(VoiceState.processing);
    _addToHistory('user', userText);
    
    debugPrint('👤 USER SAID: "$userText"'); // Log User Input
    debugPrint('⏳ Processing response...');

    try {
      // Send to GPT to decide next step
      final response = await _gpt.continueConversation(_conversationHistory);
      
      if (response == null) {
        await _speakAndListen("I'm having trouble connecting. Let's try that again.");
        return;
      }

      _lastResponse = response; // Store response
      notifyListeners(); // Notify UI

      if (response.isAction) {
        // Finalize
        _setState(VoiceState.idle);
        _isSessionActive = false;
        debugPrint('✅ AI ACTION TRIGGERED: ${response.actionData}'); // Log Action
        await _tts.speak(response.responseText);
        // Trigger action callback (to be handled by UI)
        // For MVP, just speak result
      } else {
        // Continue loop
        debugPrint('🔄 AI QUESTION: "${response.responseText}"');
        await _speakAndListen(response.responseText);
      }

    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _setState(VoiceState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String msg) {
    _lastSystemMessage = "Error: $msg";
    _setState(VoiceState.error);
    _isSessionActive = false;
  }

  void _handleError(String error) {
    debugPrint("Voice Error: $error");
    // Don't kill session immediately on minor errors, just retry listen
    if (_isSessionActive && _state == VoiceState.listening) {
       _speakAndListen("Sorry, I didn't catch that.");
    }
  }

  void _addToHistory(String role, String content) {
    _conversationHistory.add({'role': role, 'content': content});
  }
}
