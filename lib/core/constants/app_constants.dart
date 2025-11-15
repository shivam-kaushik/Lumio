/// Application-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Awarely';
  static const String appTagline = 'Never forget what matters';
  static const String version = '1.0.0';

  // Database
  static const String dbName = 'awarely.db';
  static const int dbVersion = 11; // Core Features: Enhanced Skills, Subtasks, Reps, and Goal linking

  // Tables
  static const String remindersTable = 'reminders';
  static const String contextEventsTable = 'context_events';
  static const String locationsTable = 'locations';
  static const String reminderOccurrencesTable = 'reminder_occurrences';
  static const String skillsTable = 'skills';
  static const String repsTable = 'reps';
  static const String goalsTable = 'goals';
  static const String subtasksTable = 'subtasks';

  // Geofence
  static const double defaultGeofenceRadius = 100.0; // meters
  static const int geofenceLoiteringDelay = 30000; // 30 seconds in ms

  // Background Tasks
  static const String contextMonitorTaskName = 'contextMonitorTask';
  static const Duration contextCheckInterval = Duration(minutes: 15);

  // Notification Channels
  static const String notificationChannelId = 'awarely_reminders';
  static const String notificationChannelName = 'Reminders';
  static const String notificationChannelDesc =
      'Context-aware reminder notifications';

  // Limits (Free Tier)
  static const int freeReminderLimit = 10;
  static const int proReminderLimit = 1000;

  // Context Types
  static const String contextTypeTime = 'time';
  static const String contextTypeGeofence = 'geofence';
  static const String contextTypeWifi = 'wifi';
  static const String contextTypeMotion = 'motion';
  static const String contextTypeLeaving = 'leaving';
  static const String contextTypeArriving = 'arriving';

  // Outcomes
  static const String outcomeCompleted = 'completed';
  static const String outcomeMissed = 'missed';
  static const String outcomeSnoozed = 'snoozed';
  static const String outcomeDismissed = 'dismissed';
  static const String outcomeSeen = 'seen';
  static const String outcomePending = 'pending';

  // NLU Keywords
  static const List<String> timeKeywords = ['at', 'by', 'before', 'after'];
  static const List<String> leaveKeywords = [
    'leave',
    'leaving',
    'exit',
    'depart',
  ];
  static const List<String> arriveKeywords = [
    'arrive',
    'reach',
    'get to',
    'enter',
  ];
  static const List<String> locationKeywords = [
    'home',
    'work',
    'office',
    'gym',
    'school',
  ];

  // Sample Phrases
  static const List<String> samplePhrases = [
    'Remind me to take my vitamin when I wake up',
    'Remind me to turn off the AC when I leave home',
    'Remind me to call Mom at 8 PM',
    'Remind me to carry my ID when leaving for work',
    'Remind me to drink water every 2 hours',
    "Remind me to take umbrella when it's raining",
  ];
}
