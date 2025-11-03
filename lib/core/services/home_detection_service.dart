import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../data/models/saved_location.dart';

/// Service for intelligently detecting user's home location
/// Uses GPS-based location detection with auto-learning and manual setup
class HomeDetectionService {
  static const String _prefHomeLocation = 'home_location';
  static const String _prefLocationVisits = 'location_visits';
  static const String _prefHomeDetectionMode = 'home_detection_mode';

  // Detection modes
  static const String modeAutomatic = 'automatic';
  static const String modeManual = 'manual';
  static const String modeHybrid = 'hybrid';

  /// Get current home location (if set)
  Future<SavedLocation?> getHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefHomeLocation);

    if (jsonString == null) return null;

    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return SavedLocation.fromMap(map);
    } catch (e) {
      debugPrint('❌ Error parsing home location: $e');
      return null;
    }
  }

  /// Set home location manually
  Future<void> setHomeLocation(SavedLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefHomeLocation, jsonEncode(location.toMap()));
    await prefs.setString(_prefHomeDetectionMode, modeManual);
    debugPrint('✅ Home location set manually: ${location.name}');
  }


  /// Check if user is currently at home (GPS-based)
  Future<bool> isAtHomeViaGps() async {
    try {
      final home = await getHomeLocation();
      if (home == null) return false;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final distance = Geolocator.distanceBetween(
        home.latitude,
        home.longitude,
        position.latitude,
        position.longitude,
      );

      final isHome = distance <= home.radius;
      debugPrint(
          '📍 GPS check: ${distance.toStringAsFixed(0)}m from home ${isHome ? "IS" : "is NOT"} home',);
      return isHome;
    } catch (e) {
      debugPrint('❌ Error checking home GPS: $e');
      return false;
    }
  }

  /// Check if user is at home (GPS-based)
  Future<bool> isAtHome() async {
    return await isAtHomeViaGps();
  }

  /// Learn home location automatically based on user behavior
  /// Tracks where user spends most time during "home hours" (10 PM - 7 AM)
  Future<void> trackLocationVisit(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // Only track during typical "home hours" (night time)
      final hour = now.hour;
      final isHomeHours = hour >= 22 || hour <= 7; // 10 PM to 7 AM

      if (!isHomeHours) return;

      // Get existing visits
      final jsonString = prefs.getString(_prefLocationVisits);
      Map<String, dynamic> visits = {};

      if (jsonString != null) {
        visits = jsonDecode(jsonString) as Map<String, dynamic>;
      }

      // Create location key (rounded to ~100m precision)
      final latKey = (position.latitude * 100).round() / 100;
      final lngKey = (position.longitude * 100).round() / 100;
      final locationKey = '$latKey,$lngKey';

      // Increment visit count
      visits[locationKey] = (visits[locationKey] ?? 0) + 1;

      // Save updated visits
      await prefs.setString(_prefLocationVisits, jsonEncode(visits));

      // Check if we should auto-set home location
      await _checkAndSetAutoHome(visits, position);
    } catch (e) {
      debugPrint('❌ Error tracking location visit: $e');
    }
  }

  /// Automatically set home location if confidence is high enough
  Future<void> _checkAndSetAutoHome(
      Map<String, dynamic> visits, Position lastPosition,) async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_prefHomeDetectionMode) ?? modeAutomatic;

    // Don't override if user set it manually
    if (mode == modeManual) return;

    // Need at least 10 visits during home hours
    final totalVisits =
        visits.values.fold<int>(0, (sum, count) => sum + (count as int));
    if (totalVisits < 10) {
      debugPrint('📊 Auto-learning: $totalVisits/10 visits collected');
      return;
    }

    // Find most visited location
    String? topLocation;
    int maxVisits = 0;

    visits.forEach((location, count) {
      if (count > maxVisits) {
        maxVisits = count;
        topLocation = location;
      }
    });

    // Check if this location has >60% of visits (high confidence)
    final confidence = maxVisits / totalVisits;
    if (confidence < 0.6) {
      debugPrint(
          '📊 Auto-learning: Confidence too low (${(confidence * 100).toStringAsFixed(0)}%)',);
      return;
    }

    // Parse location
    if (topLocation != null) {
      final parts = topLocation!.split(',');
      final lat = double.parse(parts[0]);
      final lng = double.parse(parts[1]);

      // Auto-set home location
      final homeLocation = SavedLocation(
        id: 'home_auto',
        name: 'Home (Auto-detected)',
        latitude: lat,
        longitude: lng,
        radius: 150.0, // Slightly larger radius for auto-detected
      );

      await prefs.setString(
          _prefHomeLocation, jsonEncode(homeLocation.toMap()),);
      await prefs.setString(_prefHomeDetectionMode, modeAutomatic);

      debugPrint(
          '🏠 Auto-detected home location with ${(confidence * 100).toStringAsFixed(0)}% confidence',);
      debugPrint('   Location: $lat, $lng');
      debugPrint('   Based on $maxVisits visits');
    }
  }


  /// Setup wizard: Check if home location is set
  Future<Map<String, dynamic>> getSetupStatus() async {
    final home = await getHomeLocation();
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_prefHomeDetectionMode);

    return {
      'hasHomeLocation': home != null,
      'homeLocation': home?.toMap(),
      'detectionMode': mode ?? 'none',
      'isFullySetup': home != null,
    };
  }

  /// Reset all home detection data
  Future<void> resetHomeData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefHomeLocation);
    await prefs.remove(_prefLocationVisits);
    await prefs.remove(_prefHomeDetectionMode);
    debugPrint('🗑️ Reset all home detection data');
  }

  /// Get debug information
  Future<Map<String, dynamic>> getDebugInfo() async {
    final home = await getHomeLocation();
    final isHomeGps = await isAtHomeViaGps();
    final prefs = await SharedPreferences.getInstance();
    final visits = prefs.getString(_prefLocationVisits);

    return {
      'homeLocation': home?.toMap(),
      'isAtHomeViaGps': isHomeGps,
      'isAtHome': isHomeGps,
      'detectionMode': prefs.getString(_prefHomeDetectionMode),
      'totalLocationVisits': visits != null
          ? (jsonDecode(visits) as Map)
              .values
              .fold(0, (sum, v) => sum + (v as int))
          : 0,
    };
  }
}
