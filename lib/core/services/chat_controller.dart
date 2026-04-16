import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _historyStorageKey = 'chat_conversation_history_v1';
  late final stt.SpeechToText _speech;
  late final TextToSpeechService _tts;
  late final PrivacyGptService _gpt;
  late final PermissionService _permissions;

  ChatController({
    stt.SpeechToText? speech,
    TextToSpeechService? tts,
    PrivacyGptService? gpt,
    PermissionService? permissions,
  }) {
    _speech = speech ?? stt.SpeechToText();
    _tts = tts ?? TextToSpeechService();
    _gpt = gpt ?? PrivacyGptService();
    _permissions = permissions ?? PermissionService();
  }

  ChatState _state = ChatState.idle;
  String _currentTranscript = '';
  final List<ChatMessage> _messages = [];
  final List<Map<String, String>> _conversationHistory = []; // For GPT context
  final List<Map<String, dynamic>> _savedConversations = [];
  final Set<String> _executedActionMessageIds = <String>{};
  String _activeConversationId = DateTime.now().millisecondsSinceEpoch.toString();
  bool _hasUserMessageInActiveConversation = false;
  
  // Getters
  ChatState get state => _state;
  String get currentTranscript => _currentTranscript;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<Map<String, dynamic>> get savedConversations => List.unmodifiable(_savedConversations);
  String get activeConversationId => _activeConversationId;
  bool isActionExecuted(String messageId) => _executedActionMessageIds.contains(messageId);
  String get activeConversationTitle {
    final match = _savedConversations
        .where((c) => c['id'] == _activeConversationId)
        .toList();
    if (match.isNotEmpty) {
      return (match.first['title'] ?? 'New Conversation').toString();
    }
    return 'New Conversation';
  }

  bool _isInitialized = false;

  Future<void> initialize({bool openFreshChat = false}) async {
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
    
    await _loadSavedConversations();

    if (openFreshChat) {
      await startNewConversation();
      return;
    }

    if (_messages.isEmpty) {
      _addMessage(ChatMessage.ai('Hi! What goal are you working on today?'));
      _addToHistory('assistant', 'Hi! What goal are you working on today?');
    }
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
                  _addMessage(ChatMessage.action(
                    response.responseText, 
                    response.actionData ?? {},
                    type: response.actionType
                  ));
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
      if (msg.sender == ChatSender.user) {
        _hasUserMessageInActiveConversation = true;
      }
      if (_hasUserMessageInActiveConversation) {
        unawaited(_saveActiveConversation());
      }
      notifyListeners();
  }

  void _addToHistory(String role, String content) {
      _conversationHistory.add({'role': role, 'content': content});
  }

  Future<void> loadConversation(String conversationId) async {
    final conversation = _savedConversations.where((c) => c['id'] == conversationId).toList();
    if (conversation.isEmpty) return;

    _activeConversationId = conversationId;
    _messages.clear();
    _conversationHistory.clear();
    _executedActionMessageIds.clear();
    _hasUserMessageInActiveConversation = false;

    final msgs = (conversation.first['messages'] as List<dynamic>? ?? []);
    for (final item in msgs) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final senderRaw = (map['sender'] ?? 'ai').toString();
      final sender = senderRaw == 'user'
          ? ChatSender.user
          : senderRaw == 'system'
              ? ChatSender.system
              : ChatSender.ai;

      _messages.add(
        ChatMessage(
          id: (map['id'] ?? DateTime.now().microsecondsSinceEpoch.toString()).toString(),
          text: (map['text'] ?? '').toString(),
          sender: sender,
          timestamp: DateTime.tryParse((map['timestamp'] ?? '').toString()) ?? DateTime.now(),
          isAction: map['isAction'] == true,
          actionType: map['actionType']?.toString(),
          actionData: map['actionData'] is Map
              ? Map<String, dynamic>.from(map['actionData'] as Map)
              : null,
        ),
      );

      if (sender == ChatSender.user) {
        _hasUserMessageInActiveConversation = true;
        _conversationHistory.add({'role': 'user', 'content': (map['text'] ?? '').toString()});
      } else {
        _conversationHistory.add({'role': 'assistant', 'content': (map['text'] ?? '').toString()});
      }
    }
    final executed = (conversation.first['executedActionMessageIds'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();
    _executedActionMessageIds.addAll(executed);

    notifyListeners();
  }

  Future<void> startNewConversation() async {
    _activeConversationId = DateTime.now().millisecondsSinceEpoch.toString();
    _messages.clear();
    _conversationHistory.clear();
    _executedActionMessageIds.clear();
    _hasUserMessageInActiveConversation = false;
    _messages.add(ChatMessage.ai('Hi! What goal are you working on today?'));
    _addToHistory('assistant', 'Hi! What goal are you working on today?');
    notifyListeners();
  }

  Future<void> deleteConversation(String conversationId) async {
    _savedConversations.removeWhere((c) => c['id'] == conversationId);

    if (_activeConversationId == conversationId) {
      if (_savedConversations.isNotEmpty) {
        final fallbackId = (_savedConversations.first['id'] ?? '').toString();
        if (fallbackId.isNotEmpty) {
          await loadConversation(fallbackId);
        } else {
          await startNewConversation();
        }
      } else {
        await startNewConversation();
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyStorageKey, jsonEncode(_savedConversations));
    notifyListeners();
  }

  Future<void> _loadSavedConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _savedConversations
        ..clear()
        ..addAll(decoded.map((e) => Map<String, dynamic>.from(e as Map)));

      if (_savedConversations.isNotEmpty) {
        final latest = _savedConversations.first;
        final id = (latest['id'] ?? '').toString();
        if (id.isNotEmpty) {
          await loadConversation(id);
        }
      }
    } catch (e) {
      debugPrint('Failed to load chat history: $e');
    }
  }

  Future<void> _saveActiveConversation() async {
    if (!_hasUserMessageInActiveConversation) return;
    final prefs = await SharedPreferences.getInstance();

    final title = _deriveConversationTitle();
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'id': _activeConversationId,
      'title': title,
      'updatedAt': now,
      'executedActionMessageIds': _executedActionMessageIds.toList(),
      'messages': _messages.map((m) {
        return <String, dynamic>{
          'id': m.id,
          'text': m.text,
          'sender': m.sender.name,
          'timestamp': m.timestamp.toIso8601String(),
          'isAction': m.isAction,
          'actionType': m.actionType,
          'actionData': m.actionData,
        };
      }).toList(),
    };

    _savedConversations.removeWhere((c) => c['id'] == _activeConversationId);
    _savedConversations.insert(0, payload);
    if (_savedConversations.length > 30) {
      _savedConversations.removeRange(30, _savedConversations.length);
    }

    await prefs.setString(_historyStorageKey, jsonEncode(_savedConversations));
  }

  Future<void> markActionExecuted(String messageId) async {
    if (messageId.isEmpty) return;
    _executedActionMessageIds.add(messageId);
    await _saveActiveConversation();
    notifyListeners();
  }

  String _deriveConversationTitle() {
    for (final m in _messages) {
      if (m.sender == ChatSender.user && m.text.trim().isNotEmpty) {
        final t = m.text.trim();
        return t.length > 40 ? '${t.substring(0, 40)}...' : t;
      }
    }
    return 'New Conversation';
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}
