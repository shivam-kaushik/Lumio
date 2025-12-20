import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  // Predefined sounds (assuming asset paths)
  // Note: User needs to add these files to assets/sounds/
  static const String _successSound = 'sounds/success.mp3';
  static const String _startSound = 'sounds/start.mp3';
  static const String _stopSound = 'sounds/stop.mp3';
  static const String _magicSound = 'sounds/magic.mp3';

  Future<void> playSuccess() async {
    await _playSound(_successSound);
  }

  Future<void> playStart() async {
    await _playSound(_startSound);
  }

  Future<void> playStop() async {
    await _playSound(_stopSound);
  }

  Future<void> playMagic() async {
    await _playSound(_magicSound);
  }

  Future<void> _playSound(String assetPath) async {
    try {
      // In a real app, we'd ensure assets exist.
      // For now, we wrap in try-catch to prevent crashes if assets are missing
      await _player.stop(); // Stop potential previous sound
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint("Error playing sound '$assetPath': $e");
    }
  }
}
