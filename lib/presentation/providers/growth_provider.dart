import 'package:flutter/foundation.dart';
import '../../data/models/skill.dart';
import '../../data/models/rep.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_subtask.dart';
import '../../data/repositories/growth_repository.dart';
import '../../core/services/privacy_gpt_service.dart';

/// Growth state management provider for skills, reps, and goals
class GrowthProvider with ChangeNotifier {
  final GrowthRepository _repository;

  // State
  List<Goal> _goals = [];
  List<Skill> _skills = [];
  List<Rep> _reps = [];
  Map<int, List<GoalSubtask>> _subtasksByGoal = {}; // goalId -> subtasks
  int _streakCount = 0;
  Map<DateTime, int> _heatmapData = {};
  bool _isLoading = false;
  String? _error;

  GrowthProvider({required GrowthRepository repository})
      : _repository = repository;

  // Getters
  List<Goal> get goals => _goals;
  List<Skill> get skills => _skills;
  List<Rep> get reps => _reps;
  Map<int, List<GoalSubtask>> get subtasksByGoal => _subtasksByGoal;
  int get streakCount => _streakCount;
  Map<DateTime, int> get heatmapData => _heatmapData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<GoalSubtask> getSubtasksForGoal(int goalId) {
    return _subtasksByGoal[goalId] ?? [];
  }

  /// Get skills for a specific goal
  List<Skill> getSkillsForGoal(int goalId) {
    return _skills.where((s) => s.goalId == goalId).toList();
  }

  /// Get reps for a specific skill
  List<Rep> getRepsForSkill(int skillId) {
    return _reps.where((r) => r.skillId == skillId).toList();
  }

  /// Load all growth data
  Future<void> loadGrowthData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _goals = await _repository.getGoals();
      _skills = await _repository.getSkills();
      _reps = await _repository.getReps();
      _streakCount = await _repository.getStreak();

      // Load heatmap data (last 90 days)
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 90));
      _heatmapData = await _repository.getRepCountsForHeatmap(
        startDate,
        endDate,
      );

      // Load subtasks for all goals
      _subtasksByGoal.clear();
      for (var goal in _goals) {
        _subtasksByGoal[goal.id] = await _repository.getSubtasksForGoal(goal.id);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      debugPrint('Error loading growth data: $e');
      notifyListeners();
    }
  }

  /// Create a new goal
  Future<int> createGoal(
    String name, {
    DateTime? targetDeadline,
    double? hoursPerDay,
    int? totalEstimatedHours,
  }) async {
    try {
      final id = await _repository.createGoal(
        name,
        targetDeadline: targetDeadline,
        hoursPerDay: hoursPerDay,
        totalEstimatedHours: totalEstimatedHours,
      );
      await loadGrowthData(); // Reload to get updated list
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Create a new skill
  Future<int> createSkill(
    String name, {
    int? goalId,
    String? description,
  }) async {
    try {
      final id = await _repository.createSkill(
        name,
        goalId: goalId,
        description: description,
      );
      await loadGrowthData(); // Reload to get updated list
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Add a rep (skill practice session)
  Future<int> addRep(int skillId, String notes, {int? durationMinutes}) async {
    try {
      final id = await _repository.addRep(
        skillId,
        notes,
        durationMinutes: durationMinutes,
      );
      
      // Reload data to update streak and heatmap
      await loadGrowthData();
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete goal
  Future<void> deleteGoal(int id) async {
    try {
      await _repository.deleteGoal(id);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete skill
  Future<void> deleteSkill(int id) async {
    try {
      await _repository.deleteSkill(id);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete rep
  Future<void> deleteRep(int id) async {
    try {
      await _repository.deleteRep(id);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Create a subtask
  Future<int> createSubtask(GoalSubtask subtask) async {
    try {
      final id = await _repository.createSubtask(subtask);
      await loadGrowthData();
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update a subtask
  Future<void> updateSubtask(GoalSubtask subtask) async {
    try {
      await _repository.updateSubtask(subtask);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a subtask
  Future<void> deleteSubtask(int subtaskId) async {
    try {
      await _repository.deleteSubtask(subtaskId);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Complete a subtask and return motivational message
  Future<String?> completeSubtask(int subtaskId) async {
    try {
      // Get subtask details before completing
      final subtask = _subtasksByGoal.values
          .expand((list) => list)
          .firstWhere((s) => s.id == subtaskId);
      
      final goal = _goals.firstWhere((g) => g.id == subtask.goalId);
      Skill? skill;
      if (subtask.skillId != null) {
        skill = _skills.firstWhere((s) => s.id == subtask.skillId);
      }
      
      // Complete the subtask (this will log the rep)
      await _repository.completeSubtask(subtaskId);
      
      // Reload data to get updated skill stats
      await loadGrowthData();
      
      // Generate motivational message
      if (skill != null) {
        final reps = getRepsForSkill(skill.id);
        final privacyGpt = PrivacyGptService();
        final message = await privacyGpt.generateMotivationalMessage(
          goalName: goal.name,
          taskDescription: subtask.description,
          skillName: skill.name,
          streakCount: skill.currentStreak,
          totalReps: skill.totalReps,
          motivationAnchor: subtask.motivationAnchor,
        );
        return message;
      }
      
      return null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Load subtasks for a specific goal
  Future<void> loadSubtasksForGoal(int goalId) async {
    try {
      _subtasksByGoal[goalId] = await _repository.getSubtasksForGoal(goalId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading subtasks: $e');
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

