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
  Future<bool> isPremium() async {
    try {
      // First, check if current user is the test premium user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.email != null) {
        if (currentUser.email!.toLowerCase() == _testPremiumUserEmail.toLowerCase()) {
          // Test premium user - always has premium access
          return true;
        }
      }
      
      // Otherwise, check stored premium status
      final prefs = await SharedPreferences.getInstance();
      final isPremium = prefs.getBool(_premiumKey) ?? false;
      
      // Check if premium has expired
      if (isPremium) {
        final expiryDateStr = prefs.getString(_premiumExpiryKey);
        if (expiryDateStr != null) {
          final expiryDate = DateTime.parse(expiryDateStr);
          if (DateTime.now().isAfter(expiryDate)) {
            // Premium expired, remove it
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_premiumKey, isPremium);
      
      if (isPremium && expiryDate != null) {
        await prefs.setString(_premiumExpiryKey, expiryDate.toIso8601String());
      } else if (!isPremium) {
        await prefs.remove(_premiumExpiryKey);
      }
    } catch (e) {
      // Handle error silently
    }
  }

  /// Get premium expiry date
  Future<DateTime?> getPremiumExpiryDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryDateStr = prefs.getString(_premiumExpiryKey);
      if (expiryDateStr != null) {
        return DateTime.parse(expiryDateStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

