import 'package:flutter/foundation.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal_phase.dart';
import '../../data/repositories/growth_repository.dart';
import '../../core/services/privacy_gpt_service.dart';

/// Growth state management provider for goals and tasks
class GrowthProvider with ChangeNotifier {
  final GrowthRepository _repository;

  // State
  List<Goal> _goals = [];
  Map<int, List<GoalTask>> _tasksByGoal = {}; // goalId -> tasks
  Map<int, List<GoalPhase>> _phasesByGoal = {}; // goalId -> phases
  bool _isLoading = false;
  String? _error;

  GrowthProvider({required GrowthRepository repository})
      : _repository = repository;

  // Getters
  List<Goal> get goals => _goals;
  Map<int, List<GoalTask>> get tasksByGoal => _tasksByGoal;
  Map<int, List<GoalPhase>> get phasesByGoal => _phasesByGoal;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<GoalTask> getTasksForGoal(int goalId) {
    return _tasksByGoal[goalId] ?? [];
  }

  List<GoalPhase> getPhasesForGoal(int goalId) {
    return _phasesByGoal[goalId] ?? [];
  }

  /// Load all growth data
  Future<void> loadGrowthData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _goals = await _repository.getGoals();

      // Load tasks and phases for all goals
      _tasksByGoal.clear();
      _phasesByGoal.clear();
      for (var goal in _goals) {
        _tasksByGoal[goal.id] = await _repository.getTasksForGoal(goal.id);
        _phasesByGoal[goal.id] = await _repository.getPhasesForGoal(goal.id);
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

  /// Update goal
  Future<void> updateGoal(Goal goal) async {
    try {
      await _repository.updateGoal(goal);
      await loadGrowthData();
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

  /// Create a task
  Future<int> createTask(GoalTask task) async {
    try {
      final id = await _repository.createTask(task);
      await loadGrowthData();
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update a task
  Future<void> updateTask(GoalTask task) async {
    try {
      await _repository.updateTask(task);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a task
  Future<void> deleteTask(int taskId) async {
    try {
      await _repository.deleteTask(taskId);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Complete a task and return motivational message
  Future<String?> completeTask(int taskId) async {
    try {
      // Get task details before completing
      final task = _tasksByGoal.values
          .expand((list) => list)
          .firstWhere((t) => t.id == taskId);
      
      final goal = _goals.firstWhere((g) => g.id == task.goalId);
      
      // Complete the task
      await _repository.completeTask(taskId);
      
      // Reload data
      await loadGrowthData();
      
      // Generate motivational message
      final privacyGpt = PrivacyGptService();
      final message = await privacyGpt.generateMotivationalMessage(
        goalName: goal.name,
        taskDescription: task.description,
        skillName: null, // No skills anymore
        streakCount: 0, // No streaks anymore
        totalReps: 0, // No reps anymore
        motivationAnchor: task.motivationAnchor,
      );
      
      return message;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Load tasks for a specific goal
  Future<void> loadTasksForGoal(int goalId) async {
    try {
      _tasksByGoal[goalId] = await _repository.getTasksForGoal(goalId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading tasks: $e');
      notifyListeners();
    }
  }

  // ==================== Phases ====================

  /// Create a phase
  Future<int> createPhase(GoalPhase phase) async {
    try {
      final id = await _repository.createPhase(phase);
      await loadGrowthData();
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Update a phase
  Future<void> updatePhase(GoalPhase phase) async {
    try {
      await _repository.updatePhase(phase);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a phase
  Future<void> deletePhase(int phaseId) async {
    try {
      await _repository.deletePhase(phaseId);
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
