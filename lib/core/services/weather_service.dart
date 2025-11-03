import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Weather service using Open-Meteo API
/// Free, open-source weather API - no API key required!
/// Documentation: https://open-meteo.com/en/docs
class WeatherService {
  // Open-Meteo API endpoint (free, no API key required)
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch current weather conditions for a location
  /// Returns weather data including temperature, weather code, and precipitation
  Future<Map<String, dynamic>?> fetchCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Open-Meteo API: Get current weather conditions
      // Parameters:
      // - latitude, longitude: location
      // - current: weather_code (WMO code), temperature_2m, precipitation
      // - timezone: auto (uses location timezone)
      final uri = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude&current=weather_code,temperature_2m,precipitation,is_day&timezone=auto',
      );

      debugPrint('🌦️ Fetching weather from Open-Meteo API for location: $latitude,$longitude');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        debugPrint('✅ Weather data received successfully from Open-Meteo');
        return data;
      } else {
        debugPrint('⚠️ Weather HTTP ${res.statusCode}: ${res.body}');
        return null;
      }
    } catch (e) {
      debugPrint('⚠️ WeatherService error: $e');
      return null;
    }
  }

  /// Check if it's currently raining based on Open-Meteo API response
  /// Open-Meteo uses WMO weather codes:
  /// - 51-67: Drizzle/Rain
  /// - 71-77: Snow
  /// - 80-82: Rain showers
  /// - 95-99: Thunderstorms
  bool isRaining(Map<String, dynamic> weatherJson) {
    try {
      // Open-Meteo API response structure:
      // {
      //   "current": {
      //     "weather_code": 61 (integer, WMO code),
      //     "temperature_2m": 15.5,
      //     "precipitation": 0.5,
      //     "is_day": 1
      //   }
      // }
      
      final current = weatherJson['current'] as Map<String, dynamic>?;
      if (current == null) return false;

      // Check weather code (WMO codes: 51-67 = rain/drizzle, 80-82 = rain showers, 95-99 = thunderstorms)
      final weatherCode = current['weather_code'] as int?;
      if (weatherCode != null) {
        // Rain-related WMO codes
        final isRainCode = (weatherCode >= 51 && weatherCode <= 67) || // Drizzle/Rain
                          (weatherCode >= 80 && weatherCode <= 82) || // Rain showers
                          (weatherCode >= 95 && weatherCode <= 99);    // Thunderstorms
        if (isRainCode) {
          debugPrint('🌧️ Weather code indicates rain: $weatherCode');
          return true;
        }
      }

      // Also check precipitation amount if available (mm)
      final precipitation = current['precipitation'] as num?;
      if (precipitation != null && precipitation > 0) {
        debugPrint('🌧️ Precipitation detected: ${precipitation}mm');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('⚠️ Error parsing weather data: $e');
      return false;
    }
  }
}


