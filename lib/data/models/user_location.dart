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
      icon: IconData(map['iconCode'] ?? Icons.place_rounded.codePoint, fontFamily: 'MaterialIcons'),
    );
  }
}
