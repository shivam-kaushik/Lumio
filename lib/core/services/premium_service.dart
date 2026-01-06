import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service for managing premium subscription status
class PremiumService {
  static const String _premiumKey = 'is_premium_user';
  static const String _premiumExpiryKey = 'premium_expiry_date';
  
  // Test premium user email - this account will have access to AI features
  static const String _testPremiumUserEmail = 'premium@lumio.test';

  /// Check if user has premium subscription
  /// Checks both stored premium status and test premium user email
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  String _getPremiumKey(String uid) => '${_premiumKey}_$uid';
  String _getExpiryKey(String uid) => '${_premiumExpiryKey}_$uid';

  /// Check if user has premium subscription
  /// Checks both stored premium status and test premium user email
  Future<bool> isPremium() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // 1. Check test user
      if (currentUser != null && currentUser.email != null) {
        if (currentUser.email!.toLowerCase() == _testPremiumUserEmail.toLowerCase()) {
          return true;
        }
      }
      
      if (currentUser == null) return false;

      // 2. Check stored premium status for THIS user
      final prefs = await SharedPreferences.getInstance();
      final key = _getPremiumKey(currentUser.uid);
      final isPremium = prefs.getBool(key) ?? false;
      
      // 3. Check expiry
      if (isPremium) {
        final expiryKey = _getExpiryKey(currentUser.uid);
        final expiryDateStr = prefs.getString(expiryKey);
        
        if (expiryDateStr != null) {
          final expiryDate = DateTime.parse(expiryDateStr);
          if (DateTime.now().isAfter(expiryDate)) {
             // Expired
             await setPremium(false);
             return false;
          }
        }
      }
      
      return isPremium;
    } catch (e) {
      return false;
    }
  }

  /// Set premium status
  Future<void> setPremium(bool isPremium, {DateTime? expiryDate}) async {
    try {
      final uid = _userId;
      if (uid == null) return;

      final prefs = await SharedPreferences.getInstance();
      final key = _getPremiumKey(uid);
      
      await prefs.setBool(key, isPremium);
      
      final expiryKey = _getExpiryKey(uid);
      if (isPremium && expiryDate != null) {
        await prefs.setString(expiryKey, expiryDate.toIso8601String());
      } else if (!isPremium) {
        await prefs.remove(expiryKey);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get premium expiry date
  Future<DateTime?> getPremiumExpiryDate() async {
    try {
      final uid = _userId;
      if (uid == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final expiryKey = _getExpiryKey(uid);
      final expiryDateStr = prefs.getString(expiryKey);
      
      if (expiryDateStr != null) {
        return DateTime.parse(expiryDateStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

