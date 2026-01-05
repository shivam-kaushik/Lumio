import 'package:flutter/material.dart';

class UserLocation {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final IconData icon;

  const UserLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.icon = Icons.place_rounded,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'iconCode': icon.codePoint,
    };
  }

  factory UserLocation.fromMap(Map<String, dynamic> map) {


    return UserLocation(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: map['name'] ?? 'Unknown',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      icon: _getIconFromCode(map['iconCode']),
    );
  }

  static IconData _getIconFromCode(int? code) {
    if (code == null) return Icons.place_rounded;
    
    // Map common icons to ensure tree-shaking works
    // We match the code point to known Material Icons
    if (code == Icons.home.codePoint) return Icons.home;
    if (code == Icons.work.codePoint) return Icons.work;
    if (code == Icons.fitness_center.codePoint) return Icons.fitness_center;
    if (code == Icons.school.codePoint) return Icons.school;
    if (code == Icons.local_cafe.codePoint) return Icons.local_cafe;
    if (code == Icons.park.codePoint) return Icons.park;
    if (code == Icons.shopping_cart.codePoint) return Icons.shopping_cart;
    if (code == Icons.local_library.codePoint) return Icons.local_library;
    
    // Fallback for any others (this might still technically allow dynamic construction 
    // IF the compiler isn't smart enough, but usually isolating it helps. 
    // However, strictly speaking, to fix tree shaking, we should ONLY return consts.
    // If an unknown code comes in, we return default.)
    return Icons.place_rounded;
  }
}
