
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart' as stt_result;
import 'package:speech_to_text/speech_recognition_error.dart' as stt_error;
import 'package:lumio/core/services/chat_controller.dart';
import 'package:lumio/core/services/text_to_speech_service.dart';
import 'package:lumio/core/services/privacy_gpt_service.dart';
import 'package:lumio/core/services/permission_service.dart';
import 'package:lumio/core/models/conversation_models.dart';
import 'package:lumio/presentation/models/chat_message.dart';

// Fakes
class FakeSpeechToText extends Fake implements stt.SpeechToText {
  bool _available = true;
  bool _isListening = false;
  
  void setAvailable(bool val) => _available = val;

  @override
  Future<bool> initialize({
    Function(stt_error.SpeechRecognitionError)? onError,
    Function(String)? onStatus,
    debugLogging = false,
    finalTimeout = const Duration(milliseconds: 2000),
    options,
  }) async {
    return _available;
  }

  @override
  Future<void> listen({
    Function(stt_result.SpeechRecognitionResult)? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    Function(double)? onSoundLevelChange,
    cancelOnError = false,
    partialResults = true,
    onDevice = false,
    stt.ListenMode listenMode = stt.ListenMode.confirmation,
    sampleRate = 0,
    stt.SpeechListenOptions? listenOptions,
  }) async {
    _isListening = true;
  }

  @override
  Future<void> stop() async {
    _isListening = false;
  }
}

class FakeTextToSpeechService extends Fake implements TextToSpeechService {
  @override
  Future<void> initialize() async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
}

class FakePermissionService extends Fake implements PermissionService {
  @override
  Future<bool> requestMicrophonePermission() async => true;
}

// Fake for Logic Testing
class FakePrivacyGptService extends Fake implements PrivacyGptService {
  ConversationResponse? _nextResponse;
  
  void setNextResponse(ConversationResponse? response) {
    _nextResponse = response;
  }

  @override
  Future<ConversationResponse?> continueConversation(List<Map<String, String>> history) async {
    return _nextResponse;
  }
}

void main() {
  late ChatController controller;
  late FakeSpeechToText fakeSpeech; 
  late FakeTextToSpeechService fakeTTS; 
  late FakePrivacyGptService fakeGPT; 
  late FakePermissionService fakePerms; 

  setUp(() {
    fakeSpeech = FakeSpeechToText();
    fakeTTS = FakeTextToSpeechService();
    fakeGPT = FakePrivacyGptService();
    fakePerms = FakePermissionService();

    controller = ChatController(
      speech: fakeSpeech,
      tts: fakeTTS,
      gpt: fakeGPT,
      permissions: fakePerms,
    );
  });

  group('ChatController Voice Logic Tests', () {
    
    // 1. Initialization
    test('1. Initialization runs without error', () async {
      await controller.initialize();
      expect(controller.state, ChatState.idle);
    });

    // 2. Start Listening
    test('2. Start Listening updates state', () async {
      await controller.startListening();
      expect(controller.state, ChatState.listening);
    });
    
    // 9. Manual Stop
    test('9. Manual Stop updates state', () async {
       await controller.startListening();
       await controller.stopListening();
       // Should go to processing or idle. 
       // If no text, goes to idle.
       expect(controller.state, ChatState.idle);
    });

    // 19. Chat Message Model
    test('19. ChatMessage supports ActionType', () {
        final msg = ChatMessage.action("Done", {}, type: "CREATE_TASK");
        expect(msg.actionType, "CREATE_TASK");
        expect(msg.isAction, true);
    });

    // 12. GPT Success (Task)
    test('12. GPT Response triggers correct message add', () async {
        final response = ConversationResponse(
            responseText: "Added", 
            isAction: true, 
            actionType: "CREATE_TASK",
            actionData: {"title": "Buy Milk"}
        );
        
        // Setup Fake
        fakeGPT.setNextResponse(response);
        
        await controller.sendTextMessage("Buy Milk");
        
        expect(controller.messages.last.actionType, "CREATE_TASK");
        expect(controller.messages.last.actionData!['title'], "Buy Milk");
    });
    
    // 20. Privacy Mode (Empty check)
    test('20. Empty input does not send', () async {
        fakeGPT.setNextResponse(ConversationResponse(responseText: "Should Not Happen", isAction: false));
        await controller.sendTextMessage("");
        expect(controller.messages.length, 1); 
    });

  });
}
