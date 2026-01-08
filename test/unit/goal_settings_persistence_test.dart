
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';

// Mock DocumentSnapshot
class MockDocumentSnapshot extends Mock implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;

  MockDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;
  
  @override
  dynamic get(Object field) => _data[field];
}

void main() {
  group('GoalSettings Persistence 10 Test Cases', () {
    
    // 1. Full Round Trip (Map -> Object -> Map)
    test('1. Full Round Trip Serialization', () {
      final initial = GoalSettings(
        notificationTime: const TimeOfDay(hour: 14, minute: 30),
        frequency: NotificationFrequency.weekly,
        alertTiming: AlertTiming.custom,
        customAlertMinutes: 45,
        tone: NotificationTone.funny,
        enableNotifications: true,
      );
      
      final map = initial.toMap();
      final restored = GoalSettings.fromMap(map);
      
      expect(restored.notificationTime?.hour, 14);
      expect(restored.notificationTime?.minute, 30);
      expect(restored.frequency, NotificationFrequency.weekly);
      expect(restored.alertTiming, AlertTiming.custom);
      expect(restored.customAlertMinutes, 45);
      expect(restored.tone, NotificationTone.funny);
      expect(restored.enableNotifications, true);
    });

    // 2. Default Values (Null Map)
    test('2. Handles Missing Keys/Nulls gracefully', () {
      final map = <String, dynamic>{}; // Empty map
      final settings = GoalSettings.fromMap(map);
      
      expect(settings.notificationTime, null);
      expect(settings.frequency, NotificationFrequency.daily); // Default
      expect(settings.alertTiming, AlertTiming.fifteenMinBefore); // Default
      expect(settings.tone, NotificationTone.motivational); // Default
      expect(settings.enableNotifications, true); // Default
    });

    // 3. TimeOfDay Parsing logic
    test('3. TimeOfDay Parsing handles correct format', () {
      final map = {'notificationTime': '08:45', 'frequency': 0};
      final settings = GoalSettings.fromMap(map);
      expect(settings.notificationTime!.hour, 8);
      expect(settings.notificationTime!.minute, 45);
    });

    // 4. TimeOfDay Invalid Format
    test('4. TimeOfDay Parsing handles invalid format gracefully', () {
      final map = {'notificationTime': 'invalid-time', 'frequency': 0};
      final settings = GoalSettings.fromMap(map);
      expect(settings.notificationTime, null); // Should remain null/default logic (null in factory)
    });

    // 5. Enum Index Out of Bounds (Future Proofing)
    test('5. Enum Index out of bounds falls back to default', () {
      final map = {'frequency': 999}; // Invalid index
      final settings = GoalSettings.fromMap(map);
      expect(settings.frequency, NotificationFrequency.daily);
    });

    // 6. Disable Notifications Persistence
    test('6. Persistence of enableNotifications=false', () {
      final initial = GoalSettings(enableNotifications: false);
      final map = initial.toMap();
      final restored = GoalSettings.fromMap(map);
      expect(restored.enableNotifications, false);
    });

    // 7. Goal integration: Goal.fromFirestore with settings
    test('7. Goal.fromFirestore correctly extracts settings', () {
      final settingsMap = {
        'frequency': 2, // Weekly
        'tone': 1, // Funny
        'notificationTime': '10:00'
      };
      
      final goalData = {
        'name': 'Test Goal',
        'createdAt': Timestamp.now(),
        'settings': settingsMap, // Nested map
      };
      
      final doc = MockDocumentSnapshot('123', goalData);
      final goal = Goal.fromFirestore(doc);
      
      expect(goal.settings, isNotNull);
      expect(goal.settings!.frequency, NotificationFrequency.weekly);
      expect(goal.settings!.notificationTime!.hour, 10);
    });

    // 8. Goal integration: Goal.fromFirestore with NULL settings
    test('8. Goal.fromFirestore handles null settings', () {
      final goalData = {
        'name': 'Test Goal',
        'createdAt': Timestamp.now(),
        'settings': null,
      };
      
      final doc = MockDocumentSnapshot('123', goalData);
      final goal = Goal.fromFirestore(doc);
      
      expect(goal.settings, null);
    });

    // 9. Goal integration: Goal.fromFirestore with UNTYPED settings (LinkedMap simulation)
    test('9. Goal.fromFirestore handles generic Map type casting', () {
      // Create a map that isn't explicitly String, dynamic (simulating what Firestore might return in some edge cases)
      final Map<dynamic, dynamic> weirdMap = {
        'frequency': 1,
        'notificationTime': '12:00'
      };
      
      final goalData = {
        'name': 'Test Goal',
        'createdAt': Timestamp.now(),
        'settings': weirdMap, // Pass dynamic map
      };
      
      final doc = MockDocumentSnapshot('123', goalData);
      final goal = Goal.fromFirestore(doc);
      
      expect(goal.settings, isNotNull);
      expect(goal.settings!.notificationTime!.hour, 12);
    });

    // 10. CopyWith behaves correctly (State updates)
    test('10. GoalSettings.copyWith preserves existing values', () {
      final original = GoalSettings(
        frequency: NotificationFrequency.monthly,
        tone: NotificationTone.severe
      );
      
      final updated = original.copyWith(frequency: NotificationFrequency.daily);
      
      expect(updated.frequency, NotificationFrequency.daily);
      expect(updated.tone, NotificationTone.severe); // Should persist
    });

  });
}
