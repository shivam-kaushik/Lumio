import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/text_to_speech_service.dart';
import '../services/privacy_gpt_service.dart';
import '../services/permission_service.dart';
import '../../presentation/models/chat_message.dart';

enum ChatState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

class ChatController extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final TextToSpeechService _tts = TextToSpeechService();
  final PrivacyGptService _gpt = PrivacyGptService();
  final PermissionService _permissions = PermissionService();

  ChatState _state = ChatState.idle;
  String _currentTranscript = '';
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = []; // For GPT context
  
  // Getters
  ChatState get state => _state;
  String get currentTranscript => _currentTranscript;
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _permissions.requestMicrophonePermission();
    await _tts.initialize();
    
    final available = await _speech.initialize(
      onError: (e) => debugPrint('STT Error: ${e.errorMsg}'),
      onStatus: (s) => debugPrint('STT Status: $s'),
    );

    if (available) {
      _isInitialized = true;
    } else {
        debugPrint('STT not available');
    }
    
    // Add initial greeting
    _addMessage(ChatMessage.ai("Hi! What goal are you working on today?"));
    _addToHistory('assistant', "Hi! What goal are you working on today?");
  }

  // --- Input Methods ---

  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    _addMessage(ChatMessage.user(text));
    _addToHistory('user', text);
    
    await _processResponse();
  }

  Future<void> startListening() async {
    if (!_isInitialized) await initialize();
    
    _state = ChatState.listening;
    _currentTranscript = '';
    notifyListeners();

    await _speech.listen(
      onResult: (result) {
        _currentTranscript = result.recognizedWords;
        notifyListeners();

        if (result.finalResult) {
            _stopListeningAndSend();
        }
      },
      localeId: 'en_US',
    );
  }

  Future<void> stopListening() async {
      await _speech.stop();
      _stopListeningAndSend();
  }

  void _stopListeningAndSend() {
      if (_state == ChatState.listening && _currentTranscript.isNotEmpty) {
          final text = _currentTranscript;
          _state = ChatState.idle;
          _currentTranscript = '';
          notifyListeners();
          
          sendTextMessage(text);
      } else {
          _state = ChatState.idle;
          notifyListeners();
      }
  }

  // --- internal logic ---

  Future<void> _processResponse() async {
      _state = ChatState.processing;
      notifyListeners();

      try {
          final response = await _gpt.continueConversation(_conversationHistory);
          
          if (response != null) {
              if (response.isAction) {
                  _addMessage(ChatMessage.action(response.responseText, response.actionData ?? {}));
                  // Optional: Speak the completion message
                   _tts.speak(response.responseText);
              } else {
                  _addMessage(ChatMessage.ai(response.responseText));
                  _addToHistory('assistant', response.responseText);
                   // Check if user USED voice recently or standard behavior?
                   // For now, let's NOT speak every text response unless in a "Voice Mode", 
                   // but the user requirement implies a chat. 
                   // Let's keep it silent by default for Chat, unless we add a toggle.
                   // Actually, "whne the user want to use that chatbot hew should se options to either type or mic to speak in it and then we will transcribe it and then senfd to get reposenss"
                   // Usually chatbots don't read out loud unless requested. safely omit TTS for now for standard text replies.
              }
          } else {
              _addMessage(ChatMessage.ai("I'm having trouble connecting. Try again?"));
          }
      } catch (e) {
          _addMessage(ChatMessage.ai("Error: $e"));
      } finally {
          _state = ChatState.idle;
          notifyListeners();
      }
  }

  void _addMessage(ChatMessage msg) {
      _messages.add(msg);
      notifyListeners();
  }

  void _addToHistory(String role, String content) {
      _conversationHistory.add({'role': role, 'content': content});
  }

  void disposeHelper() {
      _speech.stop();
      _tts.stop();
      super.dispose();
  }
}
