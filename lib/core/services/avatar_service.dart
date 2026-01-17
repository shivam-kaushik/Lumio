import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AvatarService {
  static const String _keyAvatar = 'user_avatar_config';
  
  // Default Configuration
  static const Map<String, dynamic> _defaultConfig = {
    'skinColor': 0xFFFFDFC4, // Light Skin
    'backgroundColor': 0xFFE0F7FA, // Light Cyan
    'accessory': 'none',
    'shirt': 'tshirt_blue',
    'emotion': 'happy',
  };

  Future<Map<String, dynamic>> loadAvatarConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_keyAvatar);
    if (jsonStr == null) return _defaultConfig;
    return jsonDecode(jsonStr);
  }

  Future<void> saveAvatarConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAvatar, jsonEncode(config));
  }

  // Define available assets (Mocking assets for now)
  List<String> getAvailableAccessories() {
    return ['none', 'glasses', 'hat', 'headphones'];
  }
  
  List<String> getAvailableShirts() {
    return ['tshirt_blue', 'tshirt_red', 'hoodie_grey', 'suit'];
  }
}
