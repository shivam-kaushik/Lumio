import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
/// Service for searching locations using Google Places API
class PlacesService {
  static const String _placesApiBaseUrl = 'https://maps.googleapis.com/maps/api/place';
  
  /// Get API key - use the one from AndroidManifest/iOS config
  /// For production, consider using flutter_dotenv to load from .env file
  String? _getApiKey() {
    // Use the same key configured in AndroidManifest.xml
    // TODO: In production, load from .env file using flutter_dotenv
    return 'AIzaSyAcmaXYIoGpbXYHxC7uk52n2rxlyAj_GFg';
  }

  /// Search for places using Google Places API
  /// Returns a list of place predictions
  Future<List<PlacePrediction>> searchPlaces(String query) async {
    if (query.isEmpty) return [];

    final apiKey = _getApiKey();
    if (apiKey == null) {
      debugPrint('⚠️ PlacesService: No API key found');
      return [];
    }

    try {
      final url = Uri.parse(
        '$_placesApiBaseUrl/autocomplete/json?input=$query&key=$apiKey&types=establishment|geocode',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS') {
          final predictions = (data['predictions'] as List?)
              ?.map((p) => PlacePrediction.fromJson(p))
              .toList() ?? [];
          
          debugPrint('✅ PlacesService: Found ${predictions.length} places for "$query"');
          return predictions;
        } else {
          debugPrint('⚠️ PlacesService: API error: ${data['status']}');
          return [];
        }
      } else {
        debugPrint('❌ PlacesService: HTTP error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ PlacesService: Error searching places: $e');
      return [];
    }
  }

  /// Get place details by place_id
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final apiKey = _getApiKey();
    if (apiKey == null) return null;

    try {
      final url = Uri.parse(
        '$_placesApiBaseUrl/details/json?place_id=$placeId&key=$apiKey&fields=name,formatted_address,geometry,place_id',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['result'] != null) {
          return PlaceDetails.fromJson(data['result']);
        }
      }
    } catch (e) {
      debugPrint('❌ PlacesService: Error getting place details: $e');
    }
    
    return null;
  }

  /// Reverse geocode: Get place name from coordinates
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    final apiKey = _getApiKey();
    if (apiKey == null) return null;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$apiKey',
      );

      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          // Try to get a readable name
          final name = result['formatted_address'] ?? 
                       result['address_components']?[0]?['long_name'] ?? 
                       'Unknown Location';
          return name.toString();
        }
      }
    } catch (e) {
      debugPrint('❌ PlacesService: Error reverse geocoding: $e');
    }
    
    return null;
  }
}

/// Place prediction from autocomplete API
class PlacePrediction {
  final String placeId;
  final String description;
  final String? mainText;
  final String? secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    this.mainText,
    this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'];
    return PlacePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: structuredFormatting?['main_text'] as String?,
      secondaryText: structuredFormatting?['secondary_text'] as String?,
    );
  }
}

/// Place details with coordinates
class PlaceDetails {
  final String placeId;
  final String name;
  final String? formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>;
    final location = geometry['location'] as Map<String, dynamic>;
    
    return PlaceDetails(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      formattedAddress: json['formatted_address'] as String?,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
    );
  }
}

