import 'package:flutter/foundation.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal_phase.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../core/services/motivational_engine.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/notification_service.dart'; // NEW
import '../../data/models/user_location.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import 'dart:convert';

/// Growth state management provider for goals and tasks
class GrowthProvider with ChangeNotifier {
  final FirestoreGrowthRepository _repository;
  final NotificationService _notificationService;

  // State
  List<Goal> _goals = [];
  Map<int, List<GoalTask>> _tasksByGoal = {}; // goalId -> tasks
  Map<int, List<GoalPhase>> _phasesByGoal = {}; // goalId -> phases
  List<UserLocation> _savedLocations = []; // NEW: Saved Locations
  bool _isLoading = false;
  String? _error;

  GrowthProvider({
    required FirestoreGrowthRepository repository,
    NotificationService? notificationService,
  })  : _repository = repository,
        _notificationService = notificationService ?? NotificationService();

  // Getters
  List<Goal> get goals => _goals;
  Map<int, List<GoalTask>> get tasksByGoal => _tasksByGoal;
  Map<int, List<GoalPhase>> get phasesByGoal => _phasesByGoal;
  List<UserLocation> get savedLocations => _savedLocations; // NEW
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Helper to get all tasks flat
  List<GoalTask> get allTasks => _tasksByGoal.values.expand((l) => l).toList();
  List<GoalTask> getAllTasksFlat() => allTasks; // Alias for compatibility

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

      // Load tasks and phases for all goals in parallel
      _tasksByGoal.clear();
      _phasesByGoal.clear();
      
      await Future.wait(_goals.map((goal) async {
        final tasks = await _repository.getTasksForGoal(goal.id);
        final phases = await _repository.getPhasesForGoal(goal.id);
        
        // Use lock or synchronized access if needed, but Dart is single-threaded event loop, 
        // so map assignment is atomic enough if not awaited locally.
        _tasksByGoal[goal.id] = tasks;
        _phasesByGoal[goal.id] = phases;
      }));

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

  Future<void> _persistSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonStr = jsonEncode(_savedLocations.map((e) => e.toMap()).toList());
    await prefs.setString('saved_locations', jsonStr);
  }

  // ==================== Notifications ====================
  
  Future<void> _scheduleTaskNotification(GoalTask task) async {
    // 1. Recursive Helper
    Future<void> scheduleRecursive(GoalTask currentTask) async {
       // A. If completed or no date, cancel/skip
       if (currentTask.isCompleted || currentTask.scheduledDate == null) {
          // Try to cancel (id collision risk is low with modulo, but good hygiene)
          await _notificationService.cancelNotification(currentTask.id % 2147483647);
       } else {
          // B. Determine Trigger Time
          DateTime triggerTime = currentTask.scheduledDate!;
          
          // If time is midnight (00:00), it implies "Any time this day"
          if (triggerTime.hour == 0 && triggerTime.minute == 0) {
             int hour = 9; // Default 'any' or 'morning'
             if (currentTask.suggestedTime == 'afternoon') hour = 14;
             else if (currentTask.suggestedTime == 'evening') hour = 18;
             else if (currentTask.suggestedTime == 'morning') hour = 9;
             
             triggerTime = DateTime(
               triggerTime.year, 
               triggerTime.month, 
               triggerTime.day, 
               hour, 
               0
             );
          }
           
          // C. Schedule if in future
          if (triggerTime.isAfter(DateTime.now())) {
            final notificationId = currentTask.id % 2147483647;
            

            // Find Goal Name directly from provider state
            final goal = _goals.firstWhere(
                (g) => g.id == currentTask.goalId, 
                orElse: () => Goal(id: 0, name: 'Goal', createdAt: DateTime.now())
            );

            String body;
            if (currentTask.priority == 'high') {
                body = "🔥 High Priority: ${currentTask.title}. Do it for '${goal.name}'!";
            } else {
                body = TemplateEngine.getTaskReminder(currentTask.title, goal.name);
            }
            
            await _notificationService.scheduleNotification(
              id: notificationId,
              title: "Time for: ${currentTask.title}",
              body: body,
              scheduledTime: triggerTime,
              payload: jsonEncode({
                   'action': 'open_task',
                   'task_id': currentTask.id,
                   'goal_id': currentTask.goalId,
              }),
            );
          }
       }
       
       // Recurse for subtasks
       for (var sub in currentTask.subtasks) {
         await scheduleRecursive(sub);
       }
    }

    // 2. Start recursion
    await scheduleRecursive(task);
  }

  @override
  Future<int> createTask(GoalTask task) async {
    debugPrint('🌱 GrowthProvider: createTask called for "${task.title}" (GoalID: ${task.goalId})');
    
    // 1. Optimistic Update
    final tempId = -DateTime.now().millisecondsSinceEpoch; 
    final tempTask = task.copyWith(id: tempId);
    
    if (!_tasksByGoal.containsKey(task.goalId)) {
      _tasksByGoal[task.goalId] = [];
    }
    _tasksByGoal[task.goalId]!.add(tempTask);
    notifyListeners(); 
    
    try {
      // 2. Perform actual creation
      final id = await _repository.createTask(task);
      
      // 3. Schedule Notification
      await _scheduleTaskNotification(task.copyWith(id: id));

      await loadGrowthData(); 
      return id;
    } catch (e) {
      _tasksByGoal[task.goalId]?.removeWhere((t) => t.id == tempId);
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> updateTask(GoalTask task) async {
    try {
      await _repository.updateTask(task);
      
      // Update Notification
      await _scheduleTaskNotification(task);
      
      await loadGrowthData();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> deleteTask(int taskId) async {
    // 1. Optimistic Update: Remove locally first
    int? goalId;
    GoalTask? deletedTask;

    for (var key in _tasksByGoal.keys) {
      final list = _tasksByGoal[key];
      if (list != null) {
        final index = list.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          goalId = key;
          deletedTask = list[index];
          list.removeAt(index);
          break;
        }
      }
    }

    if (deletedTask != null) {
      notifyListeners(); // Trigger UI rebuild immediately
    }

    try {
      // 2. Perform actual delete
      await _repository.deleteTask(taskId);
      
      // Cancel Notification
      await _notificationService.cancelNotification(taskId % 2147483647);
      
      await loadGrowthData();
    } catch (e) {
      // 3. Rollback on error
      if (goalId != null && deletedTask != null) {
        _tasksByGoal[goalId]?.add(deletedTask!);
        // Sort might be needed here ideally, but simple add is enough for rollback
        notifyListeners();
      }
      
      _error = e.toString();
      rethrow;
    }
  }

  @override
  Future<String?> completeTask(int taskId) async {
    try {
      // Get task details before completing to pass to message gen
      final allTasks = _tasksByGoal.values.expand((list) => list).toList();
      final task = allTasks.firstWhere(
          (t) => t.id == taskId, 
          orElse: () => throw Exception("Task with ID $taskId not found in provider")
      );
      
      final goal = _goals.firstWhere(
          (g) => g.id == task.goalId, 
          orElse: () => Goal(id: task.goalId, name: 'Unknown Goal', createdAt: DateTime.now())
      );
      
      // Optimistic Update
      final updatedTask = task.copyWith(
        isCompleted: true, 
        completedAt: DateTime.now()
      );
      
      // Update local state
      if (_tasksByGoal.containsKey(task.goalId)) {
        final list = _tasksByGoal[task.goalId]!;
        final index = list.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          list[index] = updatedTask;
          notifyListeners(); 
        }
      }

      SoundService().playSuccess();

      await _repository.completeTask(taskId);
      
      // Cancel Notification
      await _notificationService.cancelNotification(taskId % 2147483647);

      // --- Recurrence Logic ---
      if (task.frequency != 'one-time' && task.scheduledDate != null) {
        DateTime? nextDate;
        final d = task.scheduledDate!;
        
        if (task.frequency == 'daily') {
          nextDate = d.add(const Duration(days: 1));
        } else if (task.frequency == 'weekly') {
          nextDate = d.add(const Duration(days: 7));
        } else if (task.frequency == 'monthly') {
          // Careful with month overflow (e.g. Jan 31 -> Feb 28/29)
          // DateTime handles overflow by moving to next valid date (March 3 usually)
          // Simple addition is acceptable for MVP
          nextDate = DateTime(d.year, d.month + 1, d.day, d.hour, d.minute);
        }

        if (nextDate != null) {
          debugPrint('🔄 Creating recurring task for ${task.frequency}: $nextDate');
          final newTask = task.copyWith(
            id: 0, // Reset ID for creation
            scheduledDate: nextDate,
            isCompleted: false,
            completedAt: null,
            startedAt: null,
            clearStartedAt: true,
            actualMinutes: 0,
            // Keep original frequency to continue chain
          );
          // Use provider's createTask to handle notifications and state
          await createTask(newTask);
        }
      }
      
      loadGrowthData(); 
      
      final privacyGpt = PrivacyGptService();
      final message = await privacyGpt.generateMotivationalMessage(
        goalName: goal.name,
        taskDescription: task.description,
        skillName: null, 
        streakCount: 0, 
        totalReps: 0, 
        motivationAnchor: task.motivationAnchor,
      );
      
      return message;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> uncompleteTask(int taskId) async {
    try {
      await _repository.uncompleteTask(taskId);
      
      final task = allTasks.firstWhere((t) => t.id == taskId);
      await _scheduleTaskNotification(task.copyWith(isCompleted: false)); // Re-arm

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

  /// Reset task progress
  Future<void> restartTask(int taskId) async {
    try {
      final taskList = _tasksByGoal.values.expand((l) => l);
      final task = taskList.firstWhere((t) => t.id == taskId);
      
      // Reset actual minutes and clear start time
      final updated = task.copyWith(
        clearStartedAt: true,
        actualMinutes: 0,
      );
      
      await updateTask(updated);
    } catch (e) {
      debugPrint("Error restarting task: $e");
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
}
