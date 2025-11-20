import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/firestore_service.dart';
import '../models/reminder.dart';
import '../models/context_event.dart';
import '../models/reminder_occurrence.dart';
import '../../core/constants/app_constants.dart';

/// Firestore repository for reminder CRUD operations
class FirestoreReminderRepository {
  final FirestoreService _firestoreService = FirestoreService();

  /// Create a new reminder
  Future<String> createReminder(Reminder reminder) async {
    final collection = _firestoreService.remindersCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(reminder.id).set(reminder.toFirestore());
    await _firestoreService.ensureUserDocument();
    return reminder.id;
  }

  /// Get reminder by ID
  Future<Reminder?> getReminder(String id) async {
    final collection = _firestoreService.remindersCollection;
    if (collection == null) return null;

    final doc = await collection.doc(id).get();
    if (!doc.exists) return null;

    return Reminder.fromFirestore(doc);
  }

  /// Get all reminders
  Future<List<Reminder>> getAllReminders() async {
    final collection = _firestoreService.remindersCollection;
    if (collection == null) return [];

    final snapshot = await collection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Reminder.fromFirestore(doc))
        .toList();
  }

  /// Get active (enabled) reminders
  Future<List<Reminder>> getActiveReminders() async {
    final collection = _firestoreService.remindersCollection;
    if (collection == null) return [];

    final snapshot = await collection
        .where('enabled', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Reminder.fromFirestore(doc))
        .toList();
  }

  /// Update reminder
  Future<int> updateReminder(Reminder reminder) async {
    final collection = _firestoreService.remindersCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(reminder.id).update(reminder.toFirestore());
    return 1; // Return 1 to match SQLite interface
  }

  /// Delete reminder
  Future<int> deleteReminder(String id) async {
    final collection = _firestoreService.remindersCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    // Delete all occurrences first
    await deleteReminderOccurrences(id);

    await collection.doc(id).delete();
    return 1; // Return 1 to match SQLite interface
  }

  /// Toggle reminder enabled state
  Future<int> toggleReminder(String id, bool enabled) async {
    final collection = _firestoreService.remindersCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(id).update({
      'enabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return 1;
  }

  /// Update reminder trigger stats
  Future<void> updateTriggerStats(String id) async {
    final reminder = await getReminder(id);
    if (reminder != null) {
      final collection = _firestoreService.remindersCollection;
      if (collection == null) return;

      await collection.doc(id).update({
        'lastTriggeredAt': Timestamp.now(),
        'triggerCount': reminder.triggerCount + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ==================== Context Events Methods ====================

  /// Create context event
  Future<String> createContextEvent(ContextEvent event) async {
    final collection = _firestoreService.contextEventsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(event.id).set(event.toFirestore());
    return event.id;
  }

  /// Get context events for a reminder
  Future<List<ContextEvent>> getContextEvents(String reminderId) async {
    final collection = _firestoreService.contextEventsCollection;
    if (collection == null) return [];

    final snapshot = await collection
        .where('reminderId', isEqualTo: reminderId)
        .orderBy('triggerTime', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ContextEvent.fromFirestore(doc))
        .toList();
  }

  /// Get all context events
  Future<List<ContextEvent>> getAllContextEvents() async {
    final collection = _firestoreService.contextEventsCollection;
    if (collection == null) return [];

    final snapshot = await collection
        .orderBy('triggerTime', descending: true)
        .limit(100)
        .get();

    return snapshot.docs
        .map((doc) => ContextEvent.fromFirestore(doc))
        .toList();
  }

  /// Update context event outcome
  Future<int> updateContextEventOutcome(String eventId, String outcome) async {
    final collection = _firestoreService.contextEventsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(eventId).update({
      'outcome': outcome,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return 1;
  }

  // ==================== Reminder Occurrences Methods ====================

  /// Create a reminder occurrence
  Future<String> createReminderOccurrence(ReminderOccurrence occurrence) async {
    final collection = _firestoreService.getOccurrencesCollection(occurrence.reminderId);
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(occurrence.id).set(occurrence.toFirestore());
    return occurrence.id;
  }

  /// Get occurrence by notification ID
  Future<ReminderOccurrence?> getOccurrenceByNotificationId(int notificationId) async {
    final remindersCollection = _firestoreService.remindersCollection;
    if (remindersCollection == null) return null;

    // Query all reminders to find the occurrence
    final reminders = await remindersCollection.get();
    
    for (final reminderDoc in reminders.docs) {
      final occurrencesCollection = _firestoreService.getOccurrencesCollection(reminderDoc.id);
      if (occurrencesCollection == null) continue;

      final snapshot = await occurrencesCollection
          .where('notificationId', isEqualTo: notificationId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return ReminderOccurrence.fromFirestore(snapshot.docs.first);
      }
    }

    return null;
  }

  /// Get all occurrences for a reminder
  Future<List<ReminderOccurrence>> getReminderOccurrences(String reminderId) async {
    final collection = _firestoreService.getOccurrencesCollection(reminderId);
    if (collection == null) return [];

    final snapshot = await collection
        .orderBy('scheduledTime', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => ReminderOccurrence.fromFirestore(doc))
        .toList();
  }

  /// Get pending (not completed) occurrences for a reminder
  Future<List<ReminderOccurrence>> getPendingOccurrences(String reminderId) async {
    final collection = _firestoreService.getOccurrencesCollection(reminderId);
    if (collection == null) return [];

    final snapshot = await collection
        .where('isCompleted', isEqualTo: false)
        .orderBy('scheduledTime', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => ReminderOccurrence.fromFirestore(doc))
        .toList();
  }

  /// Mark an occurrence as completed
  Future<int> completeOccurrence(String occurrenceId) async {
    // Find the occurrence first
    final remindersCollection = _firestoreService.remindersCollection;
    if (remindersCollection == null) {
      throw Exception('User not authenticated');
    }

    final reminders = await remindersCollection.get();
    
    for (final reminderDoc in reminders.docs) {
      final occurrencesCollection = _firestoreService.getOccurrencesCollection(reminderDoc.id);
      if (occurrencesCollection == null) continue;

      final occurrenceDoc = occurrencesCollection.doc(occurrenceId);
      final occurrenceSnapshot = await occurrenceDoc.get();

      if (occurrenceSnapshot.exists) {
        await occurrenceDoc.update({
          'isCompleted': true,
          'completedAt': Timestamp.now(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return 1;
      }
    }

    return 0;
  }

  /// Mark an occurrence as completed by notification ID
  Future<int> completeOccurrenceByNotificationId(int notificationId) async {
    final occurrence = await getOccurrenceByNotificationId(notificationId);
    if (occurrence == null) return 0;

    final collection = _firestoreService.getOccurrencesCollection(occurrence.reminderId);
    if (collection == null) return 0;

    await collection.doc(occurrence.id).update({
      'isCompleted': true,
      'completedAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return 1;
  }

  /// Uncomplete an occurrence (mark as not completed)
  Future<int> uncompleteOccurrence(String occurrenceId) async {
    final remindersCollection = _firestoreService.remindersCollection;
    if (remindersCollection == null) {
      throw Exception('User not authenticated');
    }

    final reminders = await remindersCollection.get();
    
    for (final reminderDoc in reminders.docs) {
      final occurrencesCollection = _firestoreService.getOccurrencesCollection(reminderDoc.id);
      if (occurrencesCollection == null) continue;

      final occurrenceDoc = occurrencesCollection.doc(occurrenceId);
      final occurrenceSnapshot = await occurrenceDoc.get();

      if (occurrenceSnapshot.exists) {
        await occurrenceDoc.update({
          'isCompleted': false,
          'completedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return 1;
      }
    }

    return 0;
  }

  /// Uncomplete an occurrence by notification ID
  Future<int> uncompleteOccurrenceByNotificationId(int notificationId) async {
    final occurrence = await getOccurrenceByNotificationId(notificationId);
    if (occurrence == null) return 0;

    final collection = _firestoreService.getOccurrencesCollection(occurrence.reminderId);
    if (collection == null) return 0;

    await collection.doc(occurrence.id).update({
      'isCompleted': false,
      'completedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return 1;
  }

  /// Get completed occurrences for a reminder (most recent first)
  Future<List<ReminderOccurrence>> getCompletedOccurrences(String reminderId) async {
    final collection = _firestoreService.getOccurrencesCollection(reminderId);
    if (collection == null) return [];

    final snapshot = await collection
        .where('isCompleted', isEqualTo: true)
        .orderBy('completedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ReminderOccurrence.fromFirestore(doc))
        .toList();
  }

  /// Delete occurrence
  Future<int> deleteOccurrence(String occurrenceId) async {
    final remindersCollection = _firestoreService.remindersCollection;
    if (remindersCollection == null) {
      throw Exception('User not authenticated');
    }

    final reminders = await remindersCollection.get();
    
    for (final reminderDoc in reminders.docs) {
      final occurrencesCollection = _firestoreService.getOccurrencesCollection(reminderDoc.id);
      if (occurrencesCollection == null) continue;

      final occurrenceDoc = occurrencesCollection.doc(occurrenceId);
      final occurrenceSnapshot = await occurrenceDoc.get();

      if (occurrenceSnapshot.exists) {
        await occurrenceDoc.delete();
        return 1;
      }
    }

    return 0;
  }

  /// Delete all occurrences for a reminder
  Future<int> deleteReminderOccurrences(String reminderId) async {
    final collection = _firestoreService.getOccurrencesCollection(reminderId);
    if (collection == null) return 0;

    final snapshot = await collection.get();
    final batch = _firestoreService.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    return snapshot.docs.length;
  }

  /// Get completion statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final remindersCollection = _firestoreService.remindersCollection;
    if (remindersCollection == null) {
      return {
        'totalReminders': 0,
        'activeReminders': 0,
        'totalEvents': 0,
        'completedEvents': 0,
        'completionRate': 0,
      };
    }

    final remindersSnapshot = await remindersCollection.get();
    final totalCount = remindersSnapshot.docs.length;

    final activeSnapshot = await remindersCollection
        .where('enabled', isEqualTo: true)
        .get();
    final activeCount = activeSnapshot.docs.length;

    final contextEventsCollection = _firestoreService.contextEventsCollection;
    int totalEvents = 0;
    int completedEvents = 0;

    if (contextEventsCollection != null) {
      final eventsSnapshot = await contextEventsCollection.get();
      totalEvents = eventsSnapshot.docs.length;

      final completedSnapshot = await contextEventsCollection
          .where('outcome', isEqualTo: AppConstants.outcomeCompleted)
          .get();
      completedEvents = completedSnapshot.docs.length;
    }

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

