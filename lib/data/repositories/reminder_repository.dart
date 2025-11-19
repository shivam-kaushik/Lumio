import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/reminder.dart';
import '../models/context_event.dart';
import '../models/reminder_occurrence.dart';

/// Repository for reminder CRUD operations
class ReminderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Create a new reminder
  Future<String> createReminder(Reminder reminder) async {
    final db = await _dbHelper.database;
    await db.insert(
      AppConstants.remindersTable,
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return reminder.id;
  }

  /// Get reminder by ID
  Future<Reminder?> getReminder(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.remindersTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  /// Get all reminders
  Future<List<Reminder>> getAllReminders() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.remindersTable,
      orderBy: 'createdAt DESC',
    );

    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  /// Get active (enabled) reminders
  Future<List<Reminder>> getActiveReminders() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.remindersTable,
      where: 'enabled = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );

    return maps.map((map) => Reminder.fromMap(map)).toList();
  }

  /// Update reminder
  Future<int> updateReminder(Reminder reminder) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.remindersTable,
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  /// Delete reminder
  Future<int> deleteReminder(String id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.remindersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggle reminder enabled state
  Future<int> toggleReminder(String id, bool enabled) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.remindersTable,
      {'enabled': enabled ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update reminder trigger stats
  Future<void> updateTriggerStats(String id) async {
    final db = await _dbHelper.database;
    final reminder = await getReminder(id);
    if (reminder != null) {
      await db.update(
        AppConstants.remindersTable,
        {
          'lastTriggeredAt': DateTime.now().toIso8601String(),
          'triggerCount': reminder.triggerCount + 1,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Create context event
  Future<String> createContextEvent(ContextEvent event) async {
    final db = await _dbHelper.database;
    await db.insert(
      AppConstants.contextEventsTable,
      event.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return event.id;
  }

  /// Get context events for a reminder
  Future<List<ContextEvent>> getContextEvents(String reminderId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.contextEventsTable,
      where: 'reminderId = ?',
      whereArgs: [reminderId],
      orderBy: 'triggerTime DESC',
    );

    return maps.map((map) => ContextEvent.fromMap(map)).toList();
  }

  /// Get all context events
  Future<List<ContextEvent>> getAllContextEvents() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.contextEventsTable,
      orderBy: 'triggerTime DESC',
      limit: 100,
    );

    return maps.map((map) => ContextEvent.fromMap(map)).toList();
  }

  /// Update context event outcome (e.g., mark as seen/completed)
  Future<int> updateContextEventOutcome(String eventId, String outcome) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.contextEventsTable,
      {'outcome': outcome},
      where: 'id = ?',
      whereArgs: [eventId],
    );
  }

  // ==================== Reminder Occurrences Methods ====================

  /// Create a reminder occurrence
  Future<String> createReminderOccurrence(ReminderOccurrence occurrence) async {
    final db = await _dbHelper.database;
    await db.insert(
      AppConstants.reminderOccurrencesTable,
      occurrence.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return occurrence.id;
  }

  /// Get occurrence by notification ID
  Future<ReminderOccurrence?> getOccurrenceByNotificationId(int notificationId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.reminderOccurrencesTable,
      where: 'notificationId = ?',
      whereArgs: [notificationId],
    );

    if (maps.isEmpty) return null;
    return ReminderOccurrence.fromMap(maps.first);
  }

  /// Get all occurrences for a reminder
  Future<List<ReminderOccurrence>> getReminderOccurrences(String reminderId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.reminderOccurrencesTable,
      where: 'reminderId = ?',
      whereArgs: [reminderId],
      orderBy: 'scheduledTime ASC',
    );

    return maps.map((map) => ReminderOccurrence.fromMap(map)).toList();
  }

  /// Get pending (not completed) occurrences for a reminder
  Future<List<ReminderOccurrence>> getPendingOccurrences(String reminderId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.reminderOccurrencesTable,
      where: 'reminderId = ? AND isCompleted = ?',
      whereArgs: [reminderId, 0],
      orderBy: 'scheduledTime ASC',
    );

    return maps.map((map) => ReminderOccurrence.fromMap(map)).toList();
  }

  /// Mark an occurrence as completed
  Future<int> completeOccurrence(String occurrenceId) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.reminderOccurrencesTable,
      {
        'isCompleted': 1,
        'completedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  /// Mark an occurrence as completed by notification ID
  Future<int> completeOccurrenceByNotificationId(int notificationId) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.reminderOccurrencesTable,
      {
        'isCompleted': 1,
        'completedAt': DateTime.now().toIso8601String(),
      },
      where: 'notificationId = ?',
      whereArgs: [notificationId],
    );
  }

  /// Uncomplete an occurrence (mark as not completed)
  Future<int> uncompleteOccurrence(String occurrenceId) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.reminderOccurrencesTable,
      {
        'isCompleted': 0,
        'completedAt': null,
      },
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  /// Uncomplete an occurrence by notification ID
  Future<int> uncompleteOccurrenceByNotificationId(int notificationId) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.reminderOccurrencesTable,
      {
        'isCompleted': 0,
        'completedAt': null,
      },
      where: 'notificationId = ?',
      whereArgs: [notificationId],
    );
  }

  /// Get completed occurrences for a reminder (most recent first)
  Future<List<ReminderOccurrence>> getCompletedOccurrences(String reminderId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.reminderOccurrencesTable,
      where: 'reminderId = ? AND isCompleted = ?',
      whereArgs: [reminderId, 1],
      orderBy: 'completedAt DESC',
    );

    return maps.map((map) => ReminderOccurrence.fromMap(map)).toList();
  }

  /// Delete occurrence
  Future<int> deleteOccurrence(String occurrenceId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.reminderOccurrencesTable,
      where: 'id = ?',
      whereArgs: [occurrenceId],
    );
  }

  /// Delete all occurrences for a reminder
  Future<int> deleteReminderOccurrences(String reminderId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.reminderOccurrencesTable,
      where: 'reminderId = ?',
      whereArgs: [reminderId],
    );
  }

  /// Get completion statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await _dbHelper.database;

    // Total reminders
    final totalCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.remindersTable}',
          ),
        ) ??
        0;

    // Active reminders
    final activeCount = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.remindersTable} WHERE enabled = 1',
          ),
        ) ??
        0;

    // Total events
    final totalEvents = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.contextEventsTable}',
          ),
        ) ??
        0;

    // Completed events
    final completedEvents = Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.contextEventsTable} WHERE outcome = ?',
            [AppConstants.outcomeCompleted],
          ),
        ) ??
        0;

    // Calculate completion rate
    final completionRate =
        totalEvents > 0 ? (completedEvents / totalEvents * 100).round() : 0;

    return {
      'totalReminders': totalCount,
      'activeReminders': activeCount,
      'totalEvents': totalEvents,
      'completedEvents': completedEvents,
      'completionRate': completionRate,
    };
  }
}
