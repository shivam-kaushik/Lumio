import 'package:sqflite/sqflite.dart';
import '../../core/constants/app_constants.dart';
import '../database/database_helper.dart';
import '../models/skill.dart';
import '../models/rep.dart';
import '../models/goal.dart';
import '../models/goal_subtask.dart';

/// Repository for growth-related operations (skills, reps, goals)
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

  /// Delete goal
  Future<int> deleteGoal(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.goalsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Skills ====================

  /// Create a new skill
  Future<int> createSkill(
    String name, {
    int? goalId,
    String? description,
  }) async {
    final db = await _dbHelper.database;
    final skill = Skill(
      id: 0, // Will be set by database
      goalId: goalId,
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
    return await db.insert(
      AppConstants.skillsTable,
      skill.toInsertMap(),
    );
  }

  /// Get all skills
  Future<List<Skill>> getSkills() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.skillsTable,
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Skill.fromMap(map)).toList();
  }

  /// Get skills for a specific goal
  Future<List<Skill>> getSkillsForGoal(int goalId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.skillsTable,
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Skill.fromMap(map)).toList();
  }

  /// Get skill by ID
  Future<Skill?> getSkillById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.skillsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Skill.fromMap(maps.first);
  }

  /// Delete skill
  Future<int> deleteSkill(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.skillsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Reps ====================

  /// Add a rep (skill practice session) and update skill stats
  Future<int> addRep(
    int skillId,
    String notes, {
    int? subtaskId,
    int? durationMinutes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    
    // Create rep
    final rep = Rep(
      id: 0, // Will be set by database
      skillId: skillId,
      subtaskId: subtaskId,
      notes: notes,
      timestamp: now,
      durationMinutes: durationMinutes,
    );
    
    final repId = await db.insert(
      AppConstants.repsTable,
      rep.toInsertMap(),
    );
    
    // Update skill stats
    await _updateSkillStats(skillId, now);
    
    return repId;
  }

  /// Update skill stats (total_reps, current_streak, last_rep_date)
  Future<void> _updateSkillStats(int skillId, DateTime repDate) async {
    final db = await _dbHelper.database;
    
    // Get current skill
    final skillMaps = await db.query(
      AppConstants.skillsTable,
      where: 'id = ?',
      whereArgs: [skillId],
    );
    
    if (skillMaps.isEmpty) return;
    
    final skill = Skill.fromMap(skillMaps.first);
    final repDateOnly = DateTime(repDate.year, repDate.month, repDate.day);
    
    // Calculate new streak
    int newStreak = 1;
    if (skill.lastRepDate != null) {
      final lastRepDateOnly = DateTime(
        skill.lastRepDate!.year,
        skill.lastRepDate!.month,
        skill.lastRepDate!.day,
      );
      final daysDiff = repDateOnly.difference(lastRepDateOnly).inDays;
      
      if (daysDiff == 1) {
        // Consecutive day - increment streak
        newStreak = skill.currentStreak + 1;
      } else if (daysDiff == 0) {
        // Same day - keep current streak
        newStreak = skill.currentStreak;
      }
      // If daysDiff > 1, streak resets to 1 (already set above)
    }
    
    // Update skill
    await db.update(
      AppConstants.skillsTable,
      {
        'total_reps': skill.totalReps + 1,
        'current_streak': newStreak,
        'last_rep_date': repDate.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [skillId],
    );
  }

  /// Get all reps
  Future<List<Rep>> getReps() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.repsTable,
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Rep.fromMap(map)).toList();
  }

  /// Get reps for a specific skill
  Future<List<Rep>> getRepsForSkill(int skillId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.repsTable,
      where: 'skill_id = ?',
      whereArgs: [skillId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Rep.fromMap(map)).toList();
  }

  /// Get rep counts for heatmap (grouped by date)
  Future<Map<DateTime, int>> getRepCountsForHeatmap(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.repsTable,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        start.toIso8601String(),
        end.toIso8601String(),
      ],
    );

    final repCounts = <DateTime, int>{};
    for (var map in maps) {
      final timestamp = DateTime.parse(map['timestamp'] as String);
      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
      repCounts[date] = (repCounts[date] ?? 0) + 1;
    }

    return repCounts;
  }

  /// Calculate current streak (consecutive days with at least one rep)
  Future<int> getStreak() async {
    final db = await _dbHelper.database;
    
    // Get all reps, ordered by timestamp descending
    final maps = await db.query(
      AppConstants.repsTable,
      orderBy: 'timestamp DESC',
    );

    if (maps.isEmpty) return 0;

    // Group reps by date
    final repDates = <DateTime>{};
    for (var map in maps) {
      final timestamp = DateTime.parse(map['timestamp'] as String);
      final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
      repDates.add(date);
    }

    // Calculate streak starting from today
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    int streak = 0;
    DateTime currentDate = todayDate;

    // Check if there's a rep today
    if (!repDates.contains(todayDate)) {
      // If no rep today, start from yesterday
      currentDate = todayDate.subtract(const Duration(days: 1));
    }

    // Count consecutive days backwards
    while (repDates.contains(currentDate)) {
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Delete rep
  Future<int> deleteRep(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.repsTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== Subtasks ====================

  /// Create a subtask for a goal
  Future<int> createSubtask(GoalSubtask subtask) async {
    final db = await _dbHelper.database;
    return await db.insert(
      AppConstants.subtasksTable,
      subtask.toInsertMap(),
    );
  }

  /// Get all subtasks for a goal
  Future<List<GoalSubtask>> getSubtasksForGoal(int goalId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.subtasksTable,
      where: 'goal_id = ?',
      whereArgs: [goalId],
      orderBy: 'scheduled_date ASC, created_at ASC',
    );
    return maps.map((map) => GoalSubtask.fromMap(map)).toList();
  }

  /// Get subtask by ID
  Future<GoalSubtask?> getSubtaskById(int subtaskId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      AppConstants.subtasksTable,
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
    if (maps.isEmpty) return null;
    return GoalSubtask.fromMap(maps.first);
  }

  /// Update subtask
  Future<int> updateSubtask(GoalSubtask subtask) async {
    final db = await _dbHelper.database;
    return await db.update(
      AppConstants.subtasksTable,
      subtask.toMap(),
      where: 'id = ?',
      whereArgs: [subtask.id],
    );
  }

  /// Delete subtask
  Future<int> deleteSubtask(int subtaskId) async {
    final db = await _dbHelper.database;
    return await db.delete(
      AppConstants.subtasksTable,
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
  }

  /// Mark subtask as completed and log rep if linked to skill
  Future<int> completeSubtask(int subtaskId) async {
    final db = await _dbHelper.database;
    
    // Get subtask to check if it has a skillId
    final subtaskMaps = await db.query(
      AppConstants.subtasksTable,
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
    
    if (subtaskMaps.isEmpty) {
      throw Exception('Subtask not found: $subtaskId');
    }
    
    final subtask = GoalSubtask.fromMap(subtaskMaps.first);
    
    // Update subtask as completed
    await db.update(
      AppConstants.subtasksTable,
      {
        'is_completed': 1,
        'completed_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
    
    // If subtask is linked to a skill, log a rep
    if (subtask.skillId != null) {
      await addRep(
        subtask.skillId!,
        subtask.description,
        subtaskId: subtaskId,
      );
    }
    
    return subtaskId;
  }

  /// Get subtasks scheduled for a specific date
  Future<List<GoalSubtask>> getSubtasksForDate(DateTime date) async {
    final db = await _dbHelper.database;
    final dateStr = date.toIso8601String().split('T')[0];
    final maps = await db.rawQuery(
      '''
      SELECT * FROM ${AppConstants.subtasksTable}
      WHERE scheduled_date LIKE ? AND is_completed = 0
      ORDER BY scheduled_date ASC
      ''',
      ['$dateStr%'],
    );
    return maps.map((map) => GoalSubtask.fromMap(map)).toList();
  }
}

