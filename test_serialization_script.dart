
import 'package:flutter/material.dart';
import 'lib/data/models/goal.dart';
import 'lib/data/models/goal_settings.dart';

void main() {
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

  if (settingsMap['notificationTime'] != '10:30') {
    print("ERROR: notificationTime mismatch. Got ${settingsMap['notificationTime']}");
  }
  if (settingsMap['frequency'] != NotificationFrequency.weekly.index) {
     print("ERROR: frequency mismatch");
  }

  // 5. Deserialize (simulate fromFirestore)
  // Simulate Firestore returning these exact types.
  // Note: Firestore returns Map<String, dynamic> usually.
  
  // Create a mock DocumentSnapshot data map
  final docData = Map<String, dynamic>.from(firestoreMap);
  
  // We can't easily mock DocumentSnapshot, but we can call Goal.fromMap if we add it or just test the logic inside fromFirestore
  
  // Let's test GoalSettings.fromMap directly first
  final restoredSettings = GoalSettings.fromMap(settingsMap);
  
  print("Restored Settings: ${restoredSettings.notificationTime}, ${restoredSettings.frequency}");

  if (restoredSettings.notificationTime?.hour != 10 || restoredSettings.notificationTime?.minute != 30) {
      print("FAIL: Time failed to restore");
  }
  if (restoredSettings.frequency != NotificationFrequency.weekly) {
      print("FAIL: Frequency failed to restore");
  }
  
  print("Test Complete");
}
