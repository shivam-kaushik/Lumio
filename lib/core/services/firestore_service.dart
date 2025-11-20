import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for Firestore database operations
/// Handles user-specific data isolation
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Get user document reference
  DocumentReference? get _userDoc {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('⚠️ FirestoreService: No authenticated user');
      return null;
    }
    return _firestore.collection('users').doc(userId);
  }

  /// Get user document reference (public access)
  DocumentReference? get userDoc => _userDoc;

  /// Get reminders collection reference for current user
  CollectionReference? get remindersCollection {
    final userDoc = _userDoc;
    if (userDoc == null) return null;
    return userDoc.collection('reminders');
  }

  /// Get goals collection reference for current user
  CollectionReference? get goalsCollection {
    final userDoc = _userDoc;
    if (userDoc == null) return null;
    return userDoc.collection('goals');
  }

  /// Get context events collection reference for current user
  CollectionReference? get contextEventsCollection {
    final userDoc = _userDoc;
    if (userDoc == null) return null;
    return userDoc.collection('context_events');
  }

  /// Get tasks collection reference for a specific goal
  CollectionReference? getTasksCollection(String goalId) {
    final userDoc = _userDoc;
    if (userDoc == null) return null;
    return userDoc
        .collection('goals')
        .doc(goalId)
        .collection('tasks');
  }

  /// Get phases collection reference for a specific goal
  CollectionReference? getPhasesCollection(String goalId) {
    final userDoc = _userDoc;
    if (userDoc == null) return null;
    return userDoc
        .collection('goals')
        .doc(goalId)
        .collection('phases');
  }

  /// Get occurrences collection reference for a specific reminder
  CollectionReference? getOccurrencesCollection(String reminderId) {
    final userDoc = _userDoc;
    if (userDoc == null) return null;
    return userDoc
        .collection('reminders')
        .doc(reminderId)
        .collection('occurrences');
  }

  /// Ensure user document exists (create if not exists)
  Future<void> ensureUserDocument() async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('⚠️ FirestoreService: Cannot ensure user document - no authenticated user');
      return;
    }

    final userDoc = _firestore.collection('users').doc(userId);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ FirestoreService: Created user document for $userId');
    }
  }

  /// Batch write helper
  WriteBatch batch() => _firestore.batch();

  /// Run transaction
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) updateFunction,
  ) async {
    return await _firestore.runTransaction(updateFunction);
  }
}

