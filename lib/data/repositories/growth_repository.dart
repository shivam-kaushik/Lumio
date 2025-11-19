import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/goal.dart';
import '../models/goal_task.dart';
import '../models/goal_phase.dart';

/// Repository for growth-related operations (goals and tasks)
class GrowthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ==================== Goals ====================

  /// Create a new goal
  Future<int> createGoal(
    String name, {
    DateTime? targetDeadline,
    double? hoursPerDay,
    int? totalEstimatedHours,
  }) async {
    final db = await _dbHelper.database;
    final goal = Goal(
      id: 0, // Will be set by database
      name: name,
      createdAt: DateTime.now(),
      targetDeadline: targetDeadline,
      hoursPerDay: hoursPerDay,
      totalEstimatedHours: totalEstimatedHours,
    );
    return await db.insert(
      AppConstants.goalsTable,
      goal.toInsertMap(),
    );
  }

  /// Get all goals
  Future<List<Goal>> getGoals() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.goalsTable,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Goal.fromMap(map)).toList();
  }

  /// Get goal by ID
  Future<Goal?> getGoal(int goalId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.goalsTable,
      where: 'id = ?',
      whereArgs: [goalId],
    );
    if (maps.isEmpty) return null;
    return Goal.fromMap(maps.first);
  }

  /// Update goal
  Future<int> updateGoal(Goal goal) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.goalsTable,
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  /// Delete goal
  Future<int> deleteGoal(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.goalsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Tasks ====================

  /// Create a task for a goal
  Future<int> createTask(GoalTask task) async {
    final db = await _dbHelper.database;
    return await db.insert(
      AppConstants.tasksTable,
      task.toInsertMap(),
    );
  }

  /// Get all tasks for a goal
  Future<List<GoalTask>> getTasksForGoal(int goalId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tasksTable,
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'scheduled_date ASC, created_at ASC',
    );
    return maps.map((map) => GoalTask.fromMap(map)).toList();
  }

  /// Get task by ID
  Future<GoalTask?> getTaskById(int taskId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.tasksTable,
      where: 'id = ?',
      whereArgs: [taskId],
    );
    if (maps.isEmpty) return null;
    return GoalTask.fromMap(maps.first);
  }

  /// Update task
  Future<int> updateTask(GoalTask task) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.tasksTable,
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  /// Delete task
  Future<int> deleteTask(int taskId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.tasksTable,
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Mark task as completed
  Future<int> completeTask(int taskId) async {
    final db = await _dbHelper.database;
    
    // Get task to verify it exists
    final taskMaps = await db.query(
      AppConstants.tasksTable,
      where: 'id = ?',
      whereArgs: [taskId],
    );
    
    if (taskMaps.isEmpty) {
      throw Exception('Task not found: $taskId');
    }
    
    // Update task as completed
    await db.update(
      AppConstants.tasksTable,
      {
        'is_completed': 1,
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
    
    return taskId;
  }

  /// Get tasks scheduled for a specific date
  Future<List<GoalTask>> getTasksForDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.rawQuery(
      '''
      SELECT * FROM ${AppConstants.tasksTable}
      WHERE scheduled_date LIKE ? AND is_completed = 0
      ORDER BY scheduled_date ASC
      ''',
      ['$dateStr%'],
    );
    return maps.map((map) => GoalTask.fromMap(map)).toList();
  }

  // ==================== Phases ====================

  /// Create a phase for a goal
  Future<int> createPhase(GoalPhase phase) async {
    final db = await _dbHelper.database;
    return await db.insert(
      AppConstants.phasesTable,
      phase.toInsertMap(),
    );
  }

  /// Get all phases for a goal
  Future<List<GoalPhase>> getPhasesForGoal(int goalId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.phasesTable,
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'order_index ASC, start_date ASC',
    );
    return maps.map((map) => GoalPhase.fromMap(map)).toList();
  }

  /// Get phase by ID
  Future<GoalPhase?> getPhaseById(int phaseId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.phasesTable,
      where: 'id = ?',
      whereArgs: [phaseId],
    );
    if (maps.isEmpty) return null;
    return GoalPhase.fromMap(maps.first);
  }

  /// Update phase
  Future<int> updatePhase(GoalPhase phase) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.phasesTable,
      phase.toMap(),
      where: 'id = ?',
      whereArgs: [phase.id],
    );
  }

  /// Delete phase
  Future<int> deletePhase(int phaseId) async {
    final db = await _dbHelper.database;
    // Set phase_id to NULL for all tasks in this phase
    await db.update(
      AppConstants.tasksTable,
      {'phase_id': null},
      where: 'phase_id = ?',
      whereArgs: [phaseId],
    );
    // Delete the phase
    return await db.delete(
      AppConstants.phasesTable,
      where: 'id = ?',
      whereArgs: [phaseId],
    );
  }
}
