import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/conversation_models.dart';
import '../services/local_nlu_preprocessor.dart';
import '../services/privacy_gpt_service.dart';
import '../../data/models/reminder.dart';
import '../../core/services/home_detection_service.dart';

/// AI Conversation Service with privacy-first architecture
/// Supports both GPT Realtime Audio and text chat
class AiConversationService {
  // State management
  final LocalNluPreprocessor _preprocessor = LocalNluPreprocessor();
  final PrivacyGptService _privacyGpt = PrivacyGptService();
  final HomeDetectionService _homeService = HomeDetectionService();

  // Voice input/output
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  // GPT Realtime Audio connection
  WebSocketChannel? _realtimeChannel;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _useRealtimeAudio = false;

  // Conversation state
  final List<ConversationMessage> _messages = [];
  ReminderDraft? _currentDraft;
  ConversationState _state = ConversationState.idle;
  StreamController<ConversationMessage>? _messageStream;

  // Callbacks
  Function(String)? onUserMessage;
  Function(String)? onAiMessage;
  Function(Reminder)? onReminderReady;
  Function(String)? onError;
  Function(ConversationState)? onStateChanged;

  /// Get current conversation state
  ConversationState get state => _state;

  /// Get current draft
  ReminderDraft? get currentDraft => _currentDraft;

  /// Get messages
  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  /// Stream of messages
  Stream<ConversationMessage> get messageStream =>
      _messageStream?.stream ?? const Stream.empty();

  /// Initialize conversation service
  Future<bool> initialize() async {
    try {
      debugPrint('🎤 AiConversationService: Initializing...');

      // Initialize speech recognition
      final speechAvailable = await _speechToText.initialize(
        onError: (error) {
          debugPrint('⚠️ Speech recognition error: $error');
          onError?.call('Speech recognition: $error');
        },
        onStatus: (status) {
          debugPrint('🎤 Speech recognition status: $status');
        },
      );

      if (!speechAvailable) {
        debugPrint('⚠️ Speech recognition not available');
      }

      // Initialize TTS
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.9);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Initialize message stream
      _messageStream = StreamController<ConversationMessage>.broadcast();

      // Reset state
      _messages.clear();
      _currentDraft = ReminderDraft();
      _state = ConversationState.idle;

      debugPrint('✅ AiConversationService: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to initialize: $e');
      onError?.call('Failed to initialize: $e');
      return false;
    }
  }

  /// Start conversation (voice or text)
  Future<void> startConversation({bool useVoice = false}) async {
    debugPrint('💬 Starting conversation (voice: $useVoice)');

    _useRealtimeAudio = useVoice && await _isRealtimeAvailable();
    _state = ConversationState.collecting;
    _updateState();

    if (_useRealtimeAudio) {
      await _connectRealtimeAudio();
    }

    await _sendGreeting();
  }

  /// Check if GPT Realtime Audio is available
  Future<bool> _isRealtimeAvailable() async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    return apiKey != null &&
        apiKey.isNotEmpty &&
        apiKey != 'your_openai_api_key_here';
  }

  /// Connect to GPT Realtime Audio API
  Future<void> _connectRealtimeAudio() async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null) {
        throw Exception('OpenAI API key not found');
      }

      debugPrint('🔌 Connecting to GPT Realtime Audio...');

      // Note: GPT Realtime Audio API endpoint and format may vary
      // This is a placeholder implementation
      // For production, use the official OpenAI Realtime API documentation

      final uri = Uri.parse(
        'wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-12-17',
      );

      _realtimeChannel = WebSocketChannel.connect(uri);

      // Authenticate
      _realtimeChannel!.sink.add(jsonEncode({
        'type': 'session.update',
        'session': {
          'modalities': ['text', 'audio'],
          'instructions': _buildSystemInstructions(),
          'voice': 'alloy',
          'temperature': 0.7,
        },
      }));

      // Listen for responses
      _realtimeChannel!.stream.listen(
        _handleRealtimeMessage,
        onError: (error) {
          debugPrint('❌ Realtime connection error: $error');
          onError?.call('Connection error: $error');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('🔌 Realtime connection closed');
          _isConnected = false;
        },
      );

      _isConnected = true;
      debugPrint('✅ Connected to GPT Realtime Audio');
    } catch (e) {
      debugPrint('❌ Failed to connect to Realtime API: $e');
      onError?.call('Failed to connect: $e');
      _useRealtimeAudio = false; // Fallback to text mode
    }
  }

  /// Build system instructions for GPT
  String _buildSystemInstructions() {
    return '''You are Awarely, a privacy-focused reminder assistant.

Your role:
1. Ask clarifying questions ONLY for required fields
2. Be conversational and helpful
3. Keep questions concise (one at a time)

Required fields for reminders:
- text: What to remind about (ALWAYS required)
- trigger: When/how (time OR location OR activity - at least one required)
  - If time: ask for specific time or recurrence
  - If location: ask which location and arrive/leave
  - If recurring: ask interval and unit

Optional fields (don't ask unless user mentions):
- priority: Low, Medium, High, Critical (default: Medium)
- category: Health, Work, Study, Personal, Shopping, Family, Other (default: Other)

Privacy rules:
- Don't ask for personal details (names, addresses)
- Use generic location types (home, work, gym) not specific addresses
- Keep conversation focused on reminder creation

Example conversation:
User: "Remind me to take keys"
You: "Sure! When should I remind you? At a specific time, when you leave a location, or based on activity?"
User: "When I leave home"
You: "Perfect! I'll remind you to take your keys every time you leave home. Should I create this reminder now?"
''';
  }

  /// Process user input (text or transcribed voice)
  Future<void> processUserInput(String input) async {
    if (input.trim().isEmpty) return;

    debugPrint('📥 Processing user input: "$input"');

    // Add to conversation history
    final userMessage = ConversationMessage(
      role: MessageRole.user,
      content: input,
      timestamp: DateTime.now(),
    );
    _addMessage(userMessage);
    onUserMessage?.call(input);

    // Check for confirmation/cancellation
    final lowerInput = input.toLowerCase();
    if (lowerInput.contains('yes') ||
        lowerInput.contains('confirm') ||
        lowerInput.contains('create') ||
        lowerInput.contains('done') ||
        lowerInput == 'create it') {
      if (_state == ConversationState.confirming) {
        await _createReminder();
        return;
      }
      // Even if not in confirming state, if we have all required fields, create it
      final requiredFields = _getRequiredFieldsForIntent(_currentDraft?.intent);
      final missingFields = requiredFields
          .where((field) => !_currentDraft!.hasField(field))
          .toList();
      if (missingFields.isEmpty && _currentDraft!.text != null && _currentDraft!.text!.isNotEmpty) {
        await _createReminder();
        return;
      }
    }

    if (lowerInput.contains('no') ||
        lowerInput.contains('cancel') ||
        lowerInput.contains('stop')) {
      await _cancelConversation();
      return;
    }

    // 1. Preprocess locally (privacy-first)
    final localResult = await _preprocessor.preprocess(input);
    
    debugPrint('📥 Processing: "$input"');
    debugPrint('📥 Extracted: ${localResult.extracted}');
    debugPrint('📥 Intent: ${localResult.intent}');
    debugPrint('📥 Draft BEFORE update: text="${_currentDraft?.text}", timeAt=${_currentDraft?.timeAt}, intent=${_currentDraft?.intent}');

    // 2. Update reminder draft - merge with existing data (don't overwrite if already set)
    _updateDraft(localResult.extracted, localResult.intent, merge: true, userInput: input);
    
    debugPrint('📥 Draft AFTER update: text="${_currentDraft!.text}", timeAt=${_currentDraft!.timeAt}, intent=${_currentDraft!.intent}');

    // 3. Infer defaults for optional fields if not provided
    if (_currentDraft!.priority == null) {
      _currentDraft!.priority = ReminderPriority.medium;
    }
    if (_currentDraft!.category == null) {
      _currentDraft!.category = ReminderCategory.other;
    }
    // If no recurring mentioned, assume one-time (don't set repeatInterval/repeatUnit)

    // 4. Check if we have all required fields (AFTER draft update)
    final requiredFields =
        _getRequiredFieldsForIntent(_currentDraft?.intent);
    final missingFields = requiredFields
        .where((field) => !_currentDraft!.hasField(field))
        .toList();

    debugPrint('🔍 Required fields: $requiredFields');
    debugPrint('🔍 Missing fields: $missingFields');
    debugPrint('🔍 Draft state: text="${_currentDraft!.text}", timeAt=${_currentDraft!.timeAt}, intent=${_currentDraft!.intent}');

    if (missingFields.isEmpty && _currentDraft!.text != null && _currentDraft!.text!.isNotEmpty) {
      // All required fields present - confirm and create
      debugPrint('✅ All required fields present! Confirming...');
      await _confirmAndCreateReminder();
      return;
    }

    // 5. Ask clarifying question (local or GPT) - ONLY for required fields
    if (missingFields.isNotEmpty) {
      if (localResult.needsGpt && localResult.confidence < 0.8) {
        // Use GPT for complex reasoning
        await _askClarifyingQuestionViaGpt(missingFields);
      } else {
        // Use local logic for simple questions
        await _askClarifyingQuestionLocally(missingFields);
      }
    }
  }

  /// Ask question using local logic
  Future<void> _askClarifyingQuestionLocally(List<String> missingFields) async {
    if (missingFields.isEmpty) {
      debugPrint('⚠️ No missing fields but asking question? This shouldn\'t happen.');
      return;
    }

    final nextField = missingFields.first;
    debugPrint('❓ Asking about missing field: $nextField');
    String question;

    switch (nextField) {
      case 'text':
        question = 'What would you like to be reminded about?';
        break;
      case 'time':
        question = 'What time should I remind you?';
        break;
      case 'location':
        // Only ask if intent is location-based
        if (_currentDraft?.intent == IntentType.locationBased) {
          question =
              'Which location should I use? Home, work, or another place?';
        } else {
          // If intent is time-based, don't ask about location
          return;
        }
        break;
      case 'locationTrigger':
        question =
            'Should I remind you when you arrive, when you leave, or both?';
        break;
      case 'recurrence':
        question =
            'How often should this repeat? For example, "every day", "every week", "every 2 hours".';
        break;
      case 'repeatInterval':
        question =
            'What interval? For example, "every 2 hours" means interval is 2.';
        break;
      case 'repeatUnit':
        question = 'What unit? Minutes, hours, days, weeks, or months?';
        break;
      case 'intent':
        question =
            'When should I remind you? At a specific time, or when you reach a location?';
        break;
      default:
        question = 'I need a bit more information. Could you clarify?';
    }

    await _sendAiMessage(question);
  }

  /// Ask question using GPT (only when needed)
  Future<void> _askClarifyingQuestionViaGpt(List<String> missingFields) async {
    try {
      // Use privacy-preserving GPT service
      final response = await _privacyGpt.askClarifyingQuestion(
        localExtracted: _currentDraft!.toMap(),
        missingFields: missingFields,
        conversationContext: _getConversationContext(),
      );

      await _sendAiMessage(response.question);
    } catch (e) {
      debugPrint('❌ GPT error: $e');
      // Fallback to local question
      await _askClarifyingQuestionLocally(missingFields);
    }
  }

  /// Send AI message (voice + text)
  Future<void> _sendAiMessage(String message) async {
    debugPrint('📤 AI message: "$message"');

    final aiMessage = ConversationMessage(
      role: MessageRole.assistant,
      content: message,
      timestamp: DateTime.now(),
    );
    _addMessage(aiMessage);
    onAiMessage?.call(message);

    // Speak if in voice mode
    if (_useRealtimeAudio || _isRecording) {
      await _tts.speak(message);
    }
  }

  /// Send greeting message
  Future<void> _sendGreeting() async {
    await _sendAiMessage(
      'Hi! What would you like to be reminded about?',
    );
  }

  /// Confirm and create reminder
  Future<void> _confirmAndCreateReminder() async {
    if (_currentDraft!.text == null) return;

    // Summarize reminder
    final summary = _generateReminderSummary(_currentDraft!);

    await _sendAiMessage(
      'Perfect! Here\'s what I\'ll remind you:\n\n$summary\n\nShould I create this reminder?',
    );

    _state = ConversationState.confirming;
    _updateState();
  }

  /// Create reminder from draft
  Future<Reminder> _createReminder() async {
    final draft = _currentDraft!;

    // Resolve location if needed
    if (draft.geofenceId == 'home' && draft.geofenceLat == null) {
      final homeLocation = await _homeService.getHomeLocation();
      if (homeLocation != null) {
        draft.geofenceLat = homeLocation.latitude;
        draft.geofenceLng = homeLocation.longitude;
        draft.geofenceRadius = homeLocation.radius ?? 100.0;
      }
    }

    final reminder = draft.toReminder();

    onReminderReady?.call(reminder);
    _state = ConversationState.completed;
    _updateState();

    await _sendAiMessage('Reminder created successfully! ✅');

    return reminder;
  }

  /// Cancel conversation
  Future<void> _cancelConversation() async {
    await _sendAiMessage('No problem! Let me know if you need anything else.');
    _state = ConversationState.cancelled;
    _updateState();
    _currentDraft = ReminderDraft();
  }

  /// Voice input handling
  Future<void> startVoiceInput() async {
    if (!await _speechToText.hasPermission) {
      onError?.call('Microphone permission required');
      return;
    }

    _isRecording = true;

    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          _isRecording = false;
          processUserInput(result.recognizedWords);
        }
      },
      localeId: 'en_US',
      listenMode: ListenMode.confirmation,
      cancelOnError: true,
    );
  }

  /// Stop voice input
  Future<void> stopVoiceInput() async {
    await _speechToText.stop();
    _isRecording = false;
  }

  /// Handle GPT Realtime Audio messages
  void _handleRealtimeMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;

      switch (type) {
        case 'response.audio_transcript.done':
          final transcript = data['transcript'] as String?;
          if (transcript != null) {
            processUserInput(transcript);
          }
          break;

        case 'response.text.done':
          final text = data['text'] as String?;
          if (text != null) {
            _sendAiMessage(text);
          }
          break;

        case 'conversation.item.input_audio_transcription.completed':
          final transcript = data['transcript'] as String?;
          if (transcript != null) {
            processUserInput(transcript);
          }
          break;
      }
    } catch (e) {
      debugPrint('❌ Error handling realtime message: $e');
    }
  }

  // Helper methods
  void _addMessage(ConversationMessage message) {
    _messages.add(message);
    _messageStream?.add(message);
  }

  /// Check if text is just time/date (not a real reminder)
  bool _isTimeOrDateOnly(String text) {
    final lower = text.toLowerCase();
    // Check if it's just time patterns
    if (RegExp(r'^(8|9|1[0-2]|0?[1-7])\s*(am|pm)', caseSensitive: false).hasMatch(lower.trim()) ||
        RegExp(r'^(today|tomorrow|nov|dec|jan|feb|mar|apr|may|jun|jul|aug|sep|oct)\s*\d*$', caseSensitive: false).hasMatch(lower.trim()) ||
        RegExp(r'^(no\s+location|specific\s+time)$', caseSensitive: false).hasMatch(lower.trim())) {
      return true;
    }
    return false;
  }

  void _updateDraft(Map<String, dynamic> extracted, IntentType? intent, {bool merge = false, String? userInput}) {
    // Ensure draft exists
    if (_currentDraft == null) {
      _currentDraft = ReminderDraft();
    }
    
    if (merge && _currentDraft != null) {
      // Merge mode: only update fields that are actually provided and not already set
      final merged = <String, dynamic>{};
      
      // Text: only update if new text is meaningful reminder text (not just time/date)
      // If extracted text is empty or just time/date, preserve existing text
      if (extracted['text'] != null && 
          (extracted['text'] as String).isNotEmpty &&
          !_isTimeOrDateOnly(extracted['text'] as String)) {
        merged['text'] = extracted['text'];
        debugPrint('   📝 Text updated: "${extracted['text']}"');
      } else if (_currentDraft!.text != null && _currentDraft!.text!.isNotEmpty) {
        merged['text'] = _currentDraft!.text;
        debugPrint('   📝 Text preserved: "${_currentDraft!.text}" (extracted was empty or time/date only)');
      }
      
      // Time: update if provided, otherwise keep existing (NEVER overwrite with null)
      if (extracted['timeAt'] != null && extracted['timeAt'].toString().isNotEmpty) {
        merged['timeAt'] = extracted['timeAt'];
        debugPrint('   ⏰ Time updated: ${extracted['timeAt']}');
      } else if (_currentDraft!.timeAt != null) {
        // No new time provided - preserve existing time
        // But if user mentioned "today" or a date, update the date part while keeping time
        final lowerInput = (userInput ?? '').toLowerCase();
        if (lowerInput.contains('today') || lowerInput.contains('tomorrow') || 
            lowerInput.contains('nov') || lowerInput.contains('dec') || 
            lowerInput.contains('jan') || lowerInput.contains('feb')) {
          // Date mentioned - update date part of existing time
          final existingTime = _currentDraft!.timeAt!;
          final now = DateTime.now();
          DateTime targetDate;
          
          if (lowerInput.contains('today') || lowerInput.contains('now')) {
            targetDate = DateTime(now.year, now.month, now.day);
          } else if (lowerInput.contains('tomorrow')) {
            targetDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
          } else {
            // Try to parse date from text
            final dateMatch = RegExp(r'(nov|dec|jan|feb|mar|apr|may|jun|jul|aug|sep|oct)\s*(\d{1,2})', caseSensitive: false).firstMatch(lowerInput);
            if (dateMatch != null) {
              final monthStr = dateMatch.group(1)!.toLowerCase();
              final dayStr = dateMatch.group(2);
              if (dayStr != null) {
                final day = int.tryParse(dayStr);
                if (day != null) {
                  final monthMap = {'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
                    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12};
                  final month = monthMap[monthStr];
                  if (month != null) {
                    final year = now.year;
                    final candidateDate = DateTime(year, month, day);
                    targetDate = candidateDate.isBefore(now) ? DateTime(year + 1, month, day) : candidateDate;
                  } else {
                    targetDate = DateTime(now.year, now.month, now.day);
                  }
                } else {
                  targetDate = DateTime(now.year, now.month, now.day);
                }
              } else {
                targetDate = DateTime(now.year, now.month, now.day);
              }
            } else {
              targetDate = DateTime(now.year, now.month, now.day);
            }
          }
          
          merged['timeAt'] = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
            existingTime.hour,
            existingTime.minute,
          ).toIso8601String();
          debugPrint('   ⏰ Date updated for existing time: ${merged['timeAt']}');
        } else {
          merged['timeAt'] = _currentDraft!.timeAt?.toIso8601String();
          debugPrint('   ⏰ Time preserved: ${_currentDraft!.timeAt}');
        }
      }
      
      // Location: update if provided, otherwise keep existing
      if (extracted['geofenceId'] != null) {
        merged['geofenceId'] = extracted['geofenceId'];
        merged['geofenceLat'] = extracted['geofenceLat'] ?? _currentDraft!.geofenceLat;
        merged['geofenceLng'] = extracted['geofenceLng'] ?? _currentDraft!.geofenceLng;
        merged['geofenceRadius'] = extracted['geofenceRadius'] ?? _currentDraft!.geofenceRadius;
      } else if (_currentDraft!.geofenceId != null) {
        merged['geofenceId'] = _currentDraft!.geofenceId;
        merged['geofenceLat'] = _currentDraft!.geofenceLat;
        merged['geofenceLng'] = _currentDraft!.geofenceLng;
        merged['geofenceRadius'] = _currentDraft!.geofenceRadius;
      }
      
      // Location triggers: update if provided, otherwise keep existing
      if (extracted['onLeaveContext'] != null) {
        merged['onLeaveContext'] = extracted['onLeaveContext'];
      } else if (_currentDraft!.onLeaveContext != null) {
        merged['onLeaveContext'] = _currentDraft!.onLeaveContext;
      }
      
      if (extracted['onArriveContext'] != null) {
        merged['onArriveContext'] = extracted['onArriveContext'];
      } else if (_currentDraft!.onArriveContext != null) {
        merged['onArriveContext'] = _currentDraft!.onArriveContext;
      }
      
      // Recurrence: update if provided, otherwise keep existing
      if (extracted['repeatInterval'] != null) {
        merged['repeatInterval'] = extracted['repeatInterval'];
        merged['repeatUnit'] = extracted['repeatUnit'];
      } else if (_currentDraft!.repeatInterval != null) {
        merged['repeatInterval'] = _currentDraft!.repeatInterval;
        merged['repeatUnit'] = _currentDraft!.repeatUnit;
      }
      
      // Priority/Category: keep existing if not explicitly provided
      merged['priority'] = extracted['priority'] ?? _currentDraft!.priority?.name;
      merged['category'] = extracted['category'] ?? _currentDraft!.category?.name;
      
      // Intent: update if provided and clearer
      if (intent != null && intent != IntentType.ambiguous) {
        merged['intent'] = intent.name;
      } else if (_currentDraft!.intent != null) {
        merged['intent'] = _currentDraft!.intent?.name;
      }
      
      _currentDraft = _currentDraft!.copyWith(merged);
      if (intent != null && intent != IntentType.ambiguous) {
        _currentDraft!.intent = intent;
      }
    } else {
      // Non-merge mode: replace with new data
      _currentDraft = _currentDraft?.copyWith(extracted) ?? ReminderDraft.fromMap(extracted);
      if (intent != null) {
        _currentDraft!.intent = intent;
      }
    }
    
    debugPrint('📝 Draft updated: text="${_currentDraft!.text}", timeAt=${_currentDraft!.timeAt}, location=${_currentDraft!.geofenceId}, intent=${_currentDraft!.intent}');
  }

  List<String> _getRequiredFieldsForIntent(IntentType? intent) {
    final required = ['text']; // Always required

    // If intent is ambiguous or null, we need to determine it
    if (intent == null || intent == IntentType.ambiguous) {
      // Check if we have any hints
      if (_currentDraft!.timeAt != null) {
        // Has time, so it's time-based
        return required; // time is already set, so we're good
      } else if (_currentDraft!.geofenceId != null) {
        // Has location, check if trigger is set
        if (_currentDraft!.onLeaveContext == true || _currentDraft!.onArriveContext == true) {
          return required; // location and trigger are set
        }
        required.add('locationTrigger');
        return required;
      } else {
        // Need to determine intent
        required.add('intent');
        return required;
      }
    }

    switch (intent) {
      case IntentType.timeBased:
        // Time-based reminders don't need location
        // Only need time if not already set
        if (_currentDraft!.timeAt == null) {
          required.add('time');
        }
        break;
      case IntentType.locationBased:
        // Only require location if intent is explicitly location-based
        if (_currentDraft!.geofenceId == null && 
            (_currentDraft!.geofenceLat == null || _currentDraft!.geofenceLng == null)) {
          required.add('location');
        }
        if (_currentDraft!.onLeaveContext != true && 
            _currentDraft!.onArriveContext != true) {
          required.add('locationTrigger');
        }
        break;
      case IntentType.recurring:
        // Only require if user explicitly mentioned recurring
        if (_currentDraft!.repeatInterval == null || _currentDraft!.repeatUnit == null) {
          required.addAll(['repeatInterval', 'repeatUnit']);
        }
        break;
      case IntentType.activityBased:
        if (_currentDraft!.activityType == null) {
          required.add('activity');
        }
        break;
      case IntentType.weatherBased:
        if (_currentDraft!.weatherCondition == null) {
          required.add('weather');
        }
        break;
      case IntentType.ambiguous:
        // Ambiguous intent - need to determine intent first
        required.add('intent');
        break;
    }

    return required;
  }

  String _getConversationContext() {
    return _messages
        .map((m) => '${m.role.name}: ${m.content}')
        .join('\n');
  }

  String _generateReminderSummary(ReminderDraft draft) {
    final parts = <String>[];
    parts.add('Reminder: ${draft.text}');

    if (draft.timeAt != null) {
      parts.add('Time: ${draft.timeAt}');
    }

    if (draft.repeatInterval != null && draft.repeatUnit != null) {
      parts.add('Repeat: Every ${draft.repeatInterval} ${draft.repeatUnit}');
    }

    if (draft.geofenceId != null) {
      parts.add('Location: ${draft.geofenceId}');
      if (draft.onLeaveContext == true) parts.add('Trigger: When leaving');
      if (draft.onArriveContext == true) parts.add('Trigger: When arriving');
    }

    if (draft.activityType != null) {
      parts.add('Activity: ${draft.activityType}');
    }

    if (draft.weatherCondition != null) {
      parts.add('Weather: ${draft.weatherCondition}');
    }

    return parts.join('\n');
  }

  void _updateState() {
    onStateChanged?.call(_state);
  }

  /// Reset conversation
  void reset() {
    _messages.clear();
    _currentDraft = ReminderDraft();
    _state = ConversationState.idle;
    _updateState();
  }

  /// Dispose resources
  void dispose() {
    _realtimeChannel?.sink.close();
    _speechToText.stop();
    _messageStream?.close();
    _tts.stop();
  }
}
