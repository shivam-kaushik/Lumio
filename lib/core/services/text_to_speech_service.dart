import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Text-to-speech service for hands-free feedback
class TextToSpeechService {
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;
  TextToSpeechService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;

  /// Initialize TTS service
  Future<void> initialize() async {
    if (_initialized) return;

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5); // Slightly slower for clarity
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _initialized = true;
  }

  /// Speak text (hands-free feedback)
  Future<void> speak(String text) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking: $e');
    }
  }

  /// Stop speaking
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  /// Check if currently speaking (not available on all platforms)
  Future<bool> isSpeaking() async {
    try {
      // Note: isSpeaking may not be available on all platforms
      return false; // Simplified for compatibility
    } catch (e) {
      return false;
    }
  }
}

