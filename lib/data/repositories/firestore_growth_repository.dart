import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/firestore_service.dart';
import '../models/goal.dart';
import '../models/goal_task.dart';
import '../models/goal_phase.dart';

/// Firestore repository for growth-related operations (goals and tasks)
class FirestoreGrowthRepository {
  final FirestoreService _firestoreService = FirestoreService();

  // ==================== Goals ====================

  /// Create a new goal
  /// Returns the goal ID as an integer (converted from Firestore string ID)
  Future<int> createGoal(
    String name, {
    DateTime? targetDeadline,
    double? hoursPerDay,
    int? totalEstimatedHours,
  }) async {
    final collection = _firestoreService.goalsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    final goal = Goal(
      id: 0, // Will be converted from Firestore ID
      name: name,
      createdAt: DateTime.now(),
      targetDeadline: targetDeadline,
      hoursPerDay: hoursPerDay,
      totalEstimatedHours: totalEstimatedHours,
    );

    // Generate a unique ID (using timestamp-based approach)
    final goalId = DateTime.now().millisecondsSinceEpoch.toString();
    final docRef = collection.doc(goalId);
    await docRef.set(goal.toFirestore());
    await _firestoreService.ensureUserDocument();

    // Return as int (using hash of string ID for consistency)
    return int.parse(goalId);
  }

  /// Get all goals
  Future<List<Goal>> getGoals() async {
    final collection = _firestoreService.goalsCollection;
    if (collection == null) return [];

    final snapshot = await collection
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      try {
        // Try to parse the document ID as int
        final goalId = int.parse(doc.id);
        final goal = Goal.fromFirestore(doc);
        // Replace the ID with the parsed int ID
        return Goal(
          id: goalId,
          name: goal.name,
          createdAt: goal.createdAt,
          targetDeadline: goal.targetDeadline,
          hoursPerDay: goal.hoursPerDay,
          totalEstimatedHours: goal.totalEstimatedHours,
        );
      } catch (e) {
        // If parsing fails, use hash of string ID
        final goal = Goal.fromFirestore(doc);
        return Goal(
          id: doc.id.hashCode,
          name: goal.name,
          createdAt: goal.createdAt,
          targetDeadline: goal.targetDeadline,
          hoursPerDay: goal.hoursPerDay,
          totalEstimatedHours: goal.totalEstimatedHours,
        );
      }
    }).toList();
  }

  /// Get goal by ID
  Future<Goal?> getGoal(int goalId) async {
    final collection = _firestoreService.goalsCollection;
    if (collection == null) return null;

    // Try to find goal by converting int ID to string
    final doc = await collection.doc(goalId.toString()).get();
    if (doc.exists) {
      final goal = Goal.fromFirestore(doc);
      return Goal(
        id: goalId,
        name: goal.name,
        createdAt: goal.createdAt,
        targetDeadline: goal.targetDeadline,
        hoursPerDay: goal.hoursPerDay,
        totalEstimatedHours: goal.totalEstimatedHours,
      );
    }

    // If not found, search all goals (fallback for hash-based IDs)
    final snapshot = await collection.get();
    for (final doc in snapshot.docs) {
      if (doc.id.hashCode == goalId) {
        final goal = Goal.fromFirestore(doc);
        return Goal(
          id: goalId,
          name: goal.name,
          createdAt: goal.createdAt,
          targetDeadline: goal.targetDeadline,
          hoursPerDay: goal.hoursPerDay,
          totalEstimatedHours: goal.totalEstimatedHours,
        );
      }
    }

    return null;
  }

  /// Update goal
  Future<int> updateGoal(Goal goal) async {
    final collection = _firestoreService.goalsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(goal.id.toString()).update(goal.toFirestore());
    return 1;
  }

  /// Delete goal
  Future<int> deleteGoal(int id) async {
    final collection = _firestoreService.goalsCollection;
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    // Delete all tasks and phases for this goal
    final tasksCollection = _firestoreService.getTasksCollection(id.toString());
    if (tasksCollection != null) {
      final tasksSnapshot = await tasksCollection.get();
      final batch = _firestoreService.batch();
      for (final doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    final phasesCollection = _firestoreService.getPhasesCollection(id.toString());
    if (phasesCollection != null) {
      final phasesSnapshot = await phasesCollection.get();
      final batch = _firestoreService.batch();
      for (final doc in phasesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await collection.doc(id.toString()).delete();
    return 1;
  }

  // ==================== Tasks ====================

  /// Create a task for a goal
  Future<int> createTask(GoalTask task) async {
    final collection = _firestoreService.getTasksCollection(task.goalId.toString());
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    // Generate unique ID
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    await collection.doc(taskId).set(task.toFirestore());
    return int.parse(taskId);
  }

  /// Get all tasks for a goal
  Future<List<GoalTask>> getTasksForGoal(int goalId) async {
    final collection = _firestoreService.getTasksCollection(goalId.toString());
    if (collection == null) return [];

    final snapshot = await collection
        .orderBy('scheduledDate', descending: false)
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      try {
        final taskId = int.parse(doc.id);
        final task = GoalTask.fromFirestore(doc);
        return GoalTask(
          id: taskId,
          goalId: task.goalId,
          title: task.title,
          description: task.description,
          estimatedHours: task.estimatedHours,
          priority: task.priority,
          frequency: task.frequency,
          suggestedTime: task.suggestedTime,
          suggestedLocation: task.suggestedLocation,
          isMilestone: task.isMilestone,
          motivationAnchor: task.motivationAnchor,
          scheduledDate: task.scheduledDate,
          phaseId: task.phaseId,
          isCompleted: task.isCompleted,
          completedAt: task.completedAt,
          createdAt: task.createdAt,
        );
      } catch (e) {
        final task = GoalTask.fromFirestore(doc);
        return GoalTask(
          id: doc.id.hashCode,
          goalId: task.goalId,
          title: task.title,
          description: task.description,
          estimatedHours: task.estimatedHours,
          priority: task.priority,
          frequency: task.frequency,
          suggestedTime: task.suggestedTime,
          suggestedLocation: task.suggestedLocation,
          isMilestone: task.isMilestone,
          motivationAnchor: task.motivationAnchor,
          scheduledDate: task.scheduledDate,
          phaseId: task.phaseId,
          isCompleted: task.isCompleted,
          completedAt: task.completedAt,
          createdAt: task.createdAt,
        );
      }
    }).toList();
  }

  /// Get task by ID
  Future<GoalTask?> getTaskById(int taskId) async {
    // Search through all goals to find the task
    final goalsCollection = _firestoreService.goalsCollection;
    if (goalsCollection == null) return null;

    final goals = await goalsCollection.get();
    for (final goalDoc in goals.docs) {
      final tasksCollection = _firestoreService.getTasksCollection(goalDoc.id);
      if (tasksCollection == null) continue;

      final taskDoc = await tasksCollection.doc(taskId.toString()).get();
      if (taskDoc.exists) {
        final task = GoalTask.fromFirestore(taskDoc);
        return GoalTask(
          id: taskId,
          goalId: task.goalId,
          title: task.title,
          description: task.description,
          estimatedHours: task.estimatedHours,
          priority: task.priority,
          frequency: task.frequency,
          suggestedTime: task.suggestedTime,
          suggestedLocation: task.suggestedLocation,
          isMilestone: task.isMilestone,
          motivationAnchor: task.motivationAnchor,
          scheduledDate: task.scheduledDate,
          phaseId: task.phaseId,
          isCompleted: task.isCompleted,
          completedAt: task.completedAt,
          createdAt: task.createdAt,
        );
      }
    }

    return null;
  }

  /// Update task
  Future<int> updateTask(GoalTask task) async {
    final collection = _firestoreService.getTasksCollection(task.goalId.toString());
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(task.id.toString()).update(task.toFirestore());
    return 1;
  }

  /// Delete task
  Future<int> deleteTask(int taskId) async {
    // Find the task first to get its goalId
    final task = await getTaskById(taskId);
    if (task == null) return 0;

    final collection = _firestoreService.getTasksCollection(task.goalId.toString());
    if (collection == null) return 0;

    await collection.doc(taskId.toString()).delete();
    return 1;
  }

  /// Mark task as completed
  Future<int> completeTask(int taskId) async {
    final task = await getTaskById(taskId);
    if (task == null) {
      throw Exception('Task not found: $taskId');
    }

    final collection = _firestoreService.getTasksCollection(task.goalId.toString());
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(taskId.toString()).update({
      'isCompleted': true,
      'completedAt': Timestamp.now(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return taskId;
  }

  /// Mark task as uncompleted
  Future<int> uncompleteTask(int taskId) async {
    final task = await getTaskById(taskId);
    if (task == null) {
      throw Exception('Task not found: $taskId');
    }

    final collection = _firestoreService.getTasksCollection(task.goalId.toString());
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(taskId.toString()).update({
      'isCompleted': false,
      'completedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return taskId;
  }

  /// Get tasks scheduled for a specific date
  Future<List<GoalTask>> getTasksForDate(DateTime date) async {
    final goalsCollection = _firestoreService.goalsCollection;
    if (goalsCollection == null) return [];

    final startOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final endOfDay = Timestamp.fromDate(
      DateTime(date.year, date.month, date.day, 23, 59, 59),
    );

    final allTasks = <GoalTask>[];
    final goals = await goalsCollection.get();

    for (final goalDoc in goals.docs) {
      final tasksCollection = _firestoreService.getTasksCollection(goalDoc.id);
      if (tasksCollection == null) continue;

      final snapshot = await tasksCollection
          .where('scheduledDate', isGreaterThanOrEqualTo: startOfDay)
          .where('scheduledDate', isLessThanOrEqualTo: endOfDay)
          .where('isCompleted', isEqualTo: false)
          .orderBy('scheduledDate', descending: false)
          .get();

      for (final doc in snapshot.docs) {
        try {
          final taskId = int.parse(doc.id);
          final task = GoalTask.fromFirestore(doc);
          allTasks.add(GoalTask(
            id: taskId,
            goalId: task.goalId,
            title: task.title,
            description: task.description,
            estimatedHours: task.estimatedHours,
            priority: task.priority,
            frequency: task.frequency,
            suggestedTime: task.suggestedTime,
            suggestedLocation: task.suggestedLocation,
            isMilestone: task.isMilestone,
            motivationAnchor: task.motivationAnchor,
            scheduledDate: task.scheduledDate,
            phaseId: task.phaseId,
            isCompleted: task.isCompleted,
            completedAt: task.completedAt,
            createdAt: task.createdAt,
          ));
        } catch (e) {
          // Skip if parsing fails
        }
      }
    }

    return allTasks;
  }

  // ==================== Phases ====================

  /// Create a phase for a goal
  Future<int> createPhase(GoalPhase phase) async {
    final collection = _firestoreService.getPhasesCollection(phase.goalId.toString());
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    final phaseId = DateTime.now().millisecondsSinceEpoch.toString();
    await collection.doc(phaseId).set(phase.toFirestore());
    return int.parse(phaseId);
  }

  /// Get all phases for a goal
  Future<List<GoalPhase>> getPhasesForGoal(int goalId) async {
    final collection = _firestoreService.getPhasesCollection(goalId.toString());
    if (collection == null) return [];

    final snapshot = await collection
        .orderBy('orderIndex', descending: false)
        .orderBy('startDate', descending: false)
        .get();

    return snapshot.docs.map((doc) {
      try {
        final phaseId = int.parse(doc.id);
        final phase = GoalPhase.fromFirestore(doc);
        return GoalPhase(
          id: phaseId,
          goalId: phase.goalId,
          name: phase.name,
          description: phase.description,
          startDate: phase.startDate,
          endDate: phase.endDate,
          orderIndex: phase.orderIndex,
          createdAt: phase.createdAt,
        );
      } catch (e) {
        final phase = GoalPhase.fromFirestore(doc);
        return GoalPhase(
          id: doc.id.hashCode,
          goalId: phase.goalId,
          name: phase.name,
          description: phase.description,
          startDate: phase.startDate,
          endDate: phase.endDate,
          orderIndex: phase.orderIndex,
          createdAt: phase.createdAt,
        );
      }
    }).toList();
  }

  /// Get phase by ID
  Future<GoalPhase?> getPhaseById(int phaseId) async {
    final goalsCollection = _firestoreService.goalsCollection;
    if (goalsCollection == null) return null;

    final goals = await goalsCollection.get();
    for (final goalDoc in goals.docs) {
      final phasesCollection = _firestoreService.getPhasesCollection(goalDoc.id);
      if (phasesCollection == null) continue;

      final phaseDoc = await phasesCollection.doc(phaseId.toString()).get();
      if (phaseDoc.exists) {
        final phase = GoalPhase.fromFirestore(phaseDoc);
        return GoalPhase(
          id: phaseId,
          goalId: phase.goalId,
          name: phase.name,
          description: phase.description,
          startDate: phase.startDate,
          endDate: phase.endDate,
          orderIndex: phase.orderIndex,
          createdAt: phase.createdAt,
        );
      }
    }

    return null;
  }

  /// Update phase
  Future<int> updatePhase(GoalPhase phase) async {
    final collection = _firestoreService.getPhasesCollection(phase.goalId.toString());
    if (collection == null) {
      throw Exception('User not authenticated');
    }

    await collection.doc(phase.id.toString()).update(phase.toFirestore());
    return 1;
  }

  /// Delete phase
  Future<int> deletePhase(int phaseId) async {
    final phase = await getPhaseById(phaseId);
    if (phase == null) return 0;

    // Update all tasks in this phase to remove phase_id
    final tasksCollection = _firestoreService.getTasksCollection(phase.goalId.toString());
    if (tasksCollection != null) {
      final tasksSnapshot = await tasksCollection
          .where('phaseId', isEqualTo: phaseId.toString())
          .get();

      final batch = _firestoreService.batch();
      for (final doc in tasksSnapshot.docs) {
        batch.update(doc.reference, {
          'phaseId': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    // Delete the phase
    final phasesCollection = _firestoreService.getPhasesCollection(phase.goalId.toString());
    if (phasesCollection == null) return 0;

    await phasesCollection.doc(phaseId.toString()).delete();
    return 1;
  }
}

