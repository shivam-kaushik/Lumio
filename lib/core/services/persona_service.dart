import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PersonaType {
  standard,
  drillSergeant,
  sassyFriend,
  wisePhilosopher,
  hypeMan
}

class PersonaService {
  static const String _keyPersona = 'user_persona';

  Future<PersonaType> getActivePersona() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_keyPersona) ?? 0;
    return PersonaType.values[index];
  }

  Future<void> setPersona(PersonaType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyPersona, type.index);
  }

  String getPromptModifier(PersonaType type) {
    switch (type) {
      case PersonaType.drillSergeant:
        return "Act as a tough military drill sergeant. Be motivational but strict. Use caps lock for emphasis. No excuses.";
      case PersonaType.sassyFriend:
        return "Act as a sassy best friend. Use emojis, slang, and be playfully judgmental if they are slacking. Keep it fun.";
      case PersonaType.wisePhilosopher:
        return "Act as a stoic philosopher (like Marcus Aurelius). Use deep, meaningful metaphors about time and duty.";
      case PersonaType.hypeMan:
        return "Act as an energetic hype man. Use exclamation marks! High energy! You believe in them 100%!";
      case PersonaType.standard:
      default:
        return "Act as a helpful, professional productivity assistant.";
    }
  }

  String getDisplayName(PersonaType type) {
    switch (type) {
      case PersonaType.drillSergeant: return "Drill Sergeant 🪖";
      case PersonaType.sassyFriend: return "Sassy Bestie 💅";
      case PersonaType.wisePhilosopher: return "The Stoic 🏛️";
      case PersonaType.hypeMan: return "Hype Man 🚀";
      case PersonaType.standard: return "Standard 🤖";
    }
  }
}
