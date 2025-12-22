import 'package:flutter/foundation.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal_phase.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../core/services/sound_service.dart';
import '../../data/models/user_location.dart'; // NEW
import 'package:shared_preferences/shared_preferences.dart'; // NEW
import 'dart:convert'; // NEW

/// Growth state management provider for goals and tasks
class GrowthProvider with ChangeNotifier {
  final FirestoreGrowthRepository _repository;

  // State
  List<Goal> _goals = [];
  Map<int, List<GoalTask>> _tasksByGoal = {}; // goalId -> tasks
  Map<int, List<GoalPhase>> _phasesByGoal = {}; // goalId -> phases
  List<UserLocation> _savedLocations = []; // NEW: Saved Locations
  bool _isLoading = false;
  String? _error;

  GrowthProvider({required FirestoreGrowthRepository repository})
      : _repository = repository;

  // Getters
  List<Goal> get goals => _goals;
  Map<int, List<GoalTask>> get tasksByGoal => _tasksByGoal;
  Map<int, List<GoalPhase>> get phasesByGoal => _phasesByGoal;
  List<UserLocation> get savedLocations => _savedLocations; // NEW
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
        _phasesByGoal[goal.id] = await _repository.getPhasesForGoal(goal.id);
      }

      // Load Saved Locations
      await _loadSavedLocations();

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
    debugPrint('🌱 GrowthProvider: createTask called for "${task.title}" (GoalID: ${task.goalId})');
    try {
      final id = await _repository.createTask(task);
      debugPrint('🌱 GrowthProvider: Task created in repo (ID: $id). Reloading data...');
      await loadGrowthData();
      debugPrint('🌱 GrowthProvider: Data reloaded successfully.');
      return id;
    } catch (e) {
      debugPrint('🛑 GrowthProvider Error: $e');
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

  /// Replace all tasks for a goal
  Future<void> replaceTasksForGoal(int goalId, List<GoalTask> rootTasks) async {
    try {
      await _repository.replaceTasksForGoal(goalId, rootTasks);
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



  /// Uncomplete a task (mark as not completed)
  Future<void> uncompleteTask(int taskId) async {
    try {
      // Uncomplete the task
      await _repository.uncompleteTask(taskId);
      
      // Reload data to sync across screens
      await loadGrowthData();
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

  /// Day Architect: Ensure a daily goal exists for the given date
  Future<int> ensureDailyGoal(DateTime date) async {
    final dateStr = "${date.year}-${date.month}-${date.day}";
    final goalName = "Daily Plan - $dateStr";

    // Check if exists
    try {
      final existing = _goals.firstWhere((g) => g.name == goalName);
      return existing.id;
    } catch (e) {
      // Create new
      return await createGoal(
        goalName,
        targetDeadline: date.add(const Duration(hours: 24)),
        hoursPerDay: 24, // Full day available
      );
    }
  }

  /// Day Architect: Start/Stop timer
  Future<void> toggleTaskTimer(int taskId) async {
    try {
      final taskList = _tasksByGoal.values.expand((l) => l);
      final task = taskList.firstWhere((t) => t.id == taskId);
      final soundService = SoundService();

      if (task.startedAt == null) {
        // Start
        final updated = task.copyWith(startedAt: DateTime.now());
        await updateTask(updated);
        soundService.playStart();
      } else {
        // Stop
        final now = DateTime.now();
        final sessionDuration = now.difference(task.startedAt!);
        final currentActual = task.actualMinutes ?? 0;
        final updated = task.copyWith(
          clearStartedAt: true, // Clear active session
          actualMinutes: currentActual + sessionDuration.inMinutes,
        );
        
        // Use repository directly to avoid full reload if fast toggle
        await _repository.updateTask(updated);
        // We do want to reload to update UI
        await loadGrowthData();
        soundService.playStop();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Complete a task and return motivational message
  Future<String?> completeTask(int taskId) async {
    try {
      // Get task details before completing
      final allTasks = _tasksByGoal.values.expand((list) => list).toList();
      final task = allTasks.firstWhere(
          (t) => t.id == taskId, 
          orElse: () => throw Exception("Task with ID $taskId not found in provider")
      );
      
      final goal = _goals.firstWhere(
          (g) => g.id == task.goalId, 
          orElse: () => Goal(id: task.goalId, name: 'Unknown Goal', createdAt: DateTime.now())
      );
      
      // OPTIMISTIC UPDATE: Update local state immediately for UI responsiveness
      final updatedTask = task.copyWith(
        isCompleted: true, 
        completedAt: DateTime.now()
      );
      
      // Update the subtask in the list (this handles top-level tasks)
      // Note: If it's a subtask, deep update recursive logic would be needed.
      // Assuming flat list for now or top-level. 
      // Actually, _tasksByGoal contains lists of tasks. If 'task' is from there, we can replace it.
      if (_tasksByGoal.containsKey(task.goalId)) {
        final list = _tasksByGoal[task.goalId]!;
        final index = list.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          list[index] = updatedTask;
          notifyListeners(); // Trigger UI update instantly
        }
      }

      // Play Sound
      SoundService().playSuccess();

      // Complete the task in backend
      await _repository.completeTask(taskId);
      
      // Reload data to ensure consistency (background)
      loadGrowthData(); 
      
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

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== Saved Locations ====================

  Future<void> _loadSavedLocations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('saved_locations');
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _savedLocations = decoded.map((e) => UserLocation.fromMap(e)).toList();
      } else {
        _savedLocations = [];
      }
    } catch (e) {
      debugPrint("Error loading locations: $e");
    }
  }

  Future<void> addSavedLocation(UserLocation loc) async {
    _savedLocations.add(loc);
    notifyListeners();
    await _persistSavedLocations();
  }

  Future<void> deleteSavedLocation(String id) async {
    _savedLocations.removeWhere((l) => l.id == id);
    notifyListeners();
    await _persistSavedLocations();
  }

  Future<void> _persistSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(_savedLocations.map((e) => e.toMap()).toList());
    await prefs.setString('saved_locations', jsonStr);
  }
}
