
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_settings.dart';

void main() {
  test('Goal Settings Serialization', () {
    print("Testing Goal Serialization...");

    // 1. Create Settings
    final settings = GoalSettings(
      notificationTime: const TimeOfDay(hour: 10, minute: 30),
      frequency: NotificationFrequency.weekly,
      alertTiming: AlertTiming.custom,
      customAlertMinutes: 45,
      tone: NotificationTone.funny,
      enableNotifications: true,
    );

    // 2. Wrap in Goal
    final goal = Goal(
      id: 123,
      name: "Test Goal",
      createdAt: DateTime.now(),
      settings: settings,
    );

    // 3. Serialize (simulate toFirestore)
    final firestoreMap = goal.toFirestore();
    print("Serialized Map: $firestoreMap");

    // 4. Validate Settings Map
    final settingsMap = firestoreMap['settings'] as Map<String, dynamic>;
    print("Settings Map: $settingsMap");

    expect(settingsMap['notificationTime'], '10:30');
    expect(settingsMap['frequency'], NotificationFrequency.weekly.index);

    // 5. Deserialize (simulate fromFirestore)
    // Create a mock DocumentSnapshot data map
    // Note: We need to handle type casting exactly as Firestore does (or as Dart sees it locally)
    final docData = Map<String, dynamic>.from(firestoreMap);
    
    final restoredSettings = GoalSettings.fromMap(settingsMap);
    
    print("Restored Settings: ${restoredSettings.notificationTime}, ${restoredSettings.frequency}");

    expect(restoredSettings.notificationTime?.hour, 10);
    expect(restoredSettings.notificationTime?.minute, 30);
    expect(restoredSettings.frequency, NotificationFrequency.weekly);
    
    print("Test Complete");
  });
}
