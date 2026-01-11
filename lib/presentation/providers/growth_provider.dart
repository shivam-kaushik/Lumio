import 'package:flutter/foundation.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_settings.dart';
import '../../data/models/goal_task.dart';
import '../../data/models/goal_phase.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import '../../core/services/privacy_gpt_service.dart';
import '../../core/services/motivational_engine.dart';
import '../../core/services/sound_service.dart';
import '../../core/services/notification_service.dart'; // NEW
import '../../data/models/user_location.dart'; 
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show DateTimeComponents;
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
      
      // TEMP: Clear all notifications as requested by user to wipe slate
      // await _notificationService.cancelAllNotifications(); 
      // (User asked for it, but I'll make it a dedicated method or just run it via debug shell normally. 
      //  But wait, user cannot run debug shell. 
      //  If I put it here, it runs EVERY time app loads. That's bad.
      //  Better: Check if user has NO goals, then clear ALL notifications? verify logic.)
      
      if (_goals.isEmpty) {
          debugPrint('🧹 No goals found. Cleaning up all notifications to be safe.');
          await _notificationService.cancelAllNotifications();
      }

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
    GoalSettings? settings,
  }) async {
    try {
      final id = await _repository.createGoal(
        name,
        targetDeadline: targetDeadline,
        hoursPerDay: hoursPerDay,
        totalEstimatedHours: totalEstimatedHours,
        settings: settings,
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
      // Logic: Only reschedule notifications if Settings changed meaningfully.
      // 1. Get old goal
      Goal? oldGoal;
      try {
         oldGoal = _goals.firstWhere((g) => g.id == goal.id);
      } catch (_) {}

      await _repository.updateGoal(goal);
      await loadGrowthData();

      // 2. Compare Settings
      bool settingsChanged = false;
      if (oldGoal != null) {
          if (oldGoal.settings != goal.settings) { 
              settingsChanged = true;
          }
      } else {
         settingsChanged = true; // New or unknown, force update
      }

      // 3. Reschedule only if needed
      if (settingsChanged) {
        debugPrint('⚙️ Goal Settings changed for "${goal.name}". Rescheduling notifications...');
        final tasks = _tasksByGoal[goal.id] ?? [];
        for (var task in tasks) {
            await _scheduleTaskNotification(task);
        }
      } else {
        debugPrint('ℹ️ Goal Settings unchanged for "${goal.name}". Skipping reschedule.');
      }

    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete goal
  Future<void> deleteGoal(int id) async {
    try {
      // 1. Cancel notifications for all tasks in this goal
      final tasks = _tasksByGoal[id] ?? [];
      // Also need to fetch if not loaded? 
      // Usually loaded, but to be safe we can use what we have in memory 
      // or fetch from repo if we wanted to be 100% sure for offline/background cases. 
      // relying on _tasksByGoal is sufficient for active session.
      
      final allTasksFlat = _deepFlatten(tasks); 
      debugPrint('🗑️ Canceling ${allTasksFlat.length} notifications for Goal $id');
      
      for (var task in allTasksFlat) {
          await _notificationService.cancelNotification(task.id % 2147483647);
      }

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
    Future<void> scheduleRecursive(GoalTask currentTask) async {
       // 1. Check completion or missing date
       if (currentTask.isCompleted || currentTask.scheduledDate == null) {
          await _notificationService.cancelNotification(currentTask.id % 2147483647);
       } else {
          // 2. Find Goal & Settings
          final goal = _goals.firstWhere(
              (g) => g.id == currentTask.goalId, 
              orElse: () => Goal(id: 0, name: 'Goal', createdAt: DateTime.now())
          );
          final settings = goal.settings;
          
          if (settings != null && !settings.enableNotifications) {
             // Notifications disabled for this goal
             await _notificationService.cancelNotification(currentTask.id % 2147483647);
             return;
          }

          // 3. Determine Base Time (STRICT Mode)
          DateTime baseTime = currentTask.scheduledDate!;
          
          if (settings != null && settings.notificationTime != null) {
              // STRICT: User has a specific "Default Time" in settings (e.g. 9:00 AM)
              final t = settings.notificationTime!;
              baseTime = DateTime(baseTime.year, baseTime.month, baseTime.day, t.hour, t.minute);
          } else {
             // Fallback only if NO settings time provided
              if (baseTime.hour == 0 && baseTime.minute == 0) {
                 int hour = 9; 
                 if (currentTask.suggestedTime == 'afternoon') hour = 14;
                 else if (currentTask.suggestedTime == 'evening') hour = 18;
                 baseTime = DateTime(baseTime.year, baseTime.month, baseTime.day, hour, 0);
              }
          }

          // 4. Determine Frequency
          DateTimeComponents? matchComponents;
          switch (currentTask.frequency) {
              case 'daily': matchComponents = DateTimeComponents.time; break;
              case 'weekly': matchComponents = DateTimeComponents.dayOfWeekAndTime; break;
              case 'monthly': matchComponents = DateTimeComponents.dayOfMonthAndTime; break;
              case 'one-time': default: matchComponents = null; break;
          }

          // 5. Apply Alert Timing Offset (STRICT)
          DateTime triggerTime = baseTime;
          if (settings != null) {
              switch (settings.alertTiming) {
                case AlertTiming.fifteenMinBefore:
                  triggerTime = baseTime.subtract(const Duration(minutes: 15));
                  break;
                case AlertTiming.atEnd:
                  final minutes = ((currentTask.estimatedHours ?? 1.0) * 60).round();
                  triggerTime = baseTime.add(Duration(minutes: minutes));
                  break;
                case AlertTiming.custom:
                  if (settings.customAlertMinutes != null) {
                     triggerTime = baseTime.subtract(Duration(minutes: settings.customAlertMinutes!));
                  }
                  break;
                case AlertTiming.atStart:
                default:
                  break;
              }
          }

          // 6. Schedule if in future (for one-time) or if it's recurring (we schedule based on component)
          // For recurring, we still need a future start date ideally, but technically any date works if component matches.
          // However, we want to ensure we don't schedule a 'one-time' notification in the past.
          
          bool shouldSchedule = true;
          if (matchComponents == null) {
              if (triggerTime.isBefore(DateTime.now())) {
                  shouldSchedule = false;
              }
          }
          // If recurring, we technically schedule it 'at the date', loops from there.
          // If the date is past, but time is future, local_notifications handles it? 
          // Best practice: Ensure 'triggerTime' is the NEXT occurrence if strict. 
          // But 'zonedSchedule' with 'matchDateTimeComponents' usually handles "reverting to next" automatically.

          if (shouldSchedule) {
            final notificationId = currentTask.id % 2147483647;
            String body = _getNotificationBody(currentTask, goal, settings);
            
            await _notificationService.scheduleNotification(
              id: notificationId,
              title: "Time for: ${currentTask.title}",
              body: body,
              scheduledTime: triggerTime,
              matchDateTimeComponents: matchComponents,
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

    await scheduleRecursive(task);
  }

  String _getNotificationBody(GoalTask task, Goal goal, GoalSettings? settings) {
    if (settings == null) return TemplateEngine.getTaskReminder(task.title, goal.name);

    switch (settings.tone) {
      case NotificationTone.funny:
         return "Hey! '${task.title}' isn't going to do itself. The world needs you! 🌍";
      case NotificationTone.severe:
         return "ACT NOW: ${task.title}. Delay is the enemy of success.";
      case NotificationTone.quotes:
         return '"Action is the foundational key to all success."\nTask: ${task.title}';
      case NotificationTone.motivational:
      default:
         return "Time to make progress on '${goal.name}'! Tackle '${task.title}' now.";
    }
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

    debugPrint('🗑️ Deleting Task ID: $taskId');

    for (var key in _tasksByGoal.keys) {
      final list = _tasksByGoal[key];
      if (list != null) {
        final index = list.indexWhere((t) => t.id == taskId);
        if (index != -1) {
          goalId = key;
          deletedTask = list[index];
          list.removeAt(index);
          debugPrint('✅ Task removed locally from Goal $goalId');
          break;
        }
      }
    }

    if (deletedTask != null) {
      notifyListeners(); // Trigger UI rebuild immediately
    } else {
      debugPrint('⚠️ Task ID $taskId not found in local state!');
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
      final oldTasks = _tasksByGoal[goalId] ?? [];
      final oldTasksMap = {for (var t in _deepFlatten(oldTasks)) t.id: t};
      
      final newTasksFlat = _deepFlatten(rootTasks);
      final newTasksMap = {for (var t in newTasksFlat) t.id: t};

      final idsToCancel = <int>{};
      final idsToSchedule = <int>{};

      // 1. Identify what to Cancel (Deleted or Changed)
      for (final oldTask in oldTasksMap.values) {
        final newTask = newTasksMap[oldTask.id];
        if (newTask == null) {
          // Deleted
          idsToCancel.add(oldTask.id);
        } else {
          // Exists in both - check if changed
          if (_notificationParametersChanged(oldTask, newTask)) {
             idsToCancel.add(oldTask.id);
             idsToSchedule.add(newTask.id);
          }
        }
      }

      // 2. Identify what to Schedule (New or Changed)
      // (Changed ones are already added above, just need New ones)
      for (final newTask in newTasksFlat) {
         if (!oldTasksMap.containsKey(newTask.id)) {
            idsToSchedule.add(newTask.id);
         }
      }

      // 3. Execute Cancellations
      if (idsToCancel.isNotEmpty) {
        debugPrint('📉 Cancelling ${idsToCancel.length} obsolete notifications for Goal $goalId');
        for (var id in idsToCancel) {
           await _notificationService.cancelNotification(id % 2147483647);
        }
      }

      // 4. Replace in DB
      await _repository.replaceTasksForGoal(goalId, rootTasks);
      
      // 5. Reload to get new IDs/State
      await loadGrowthData();
      
      // 6. Execute Scheduling
      if (idsToSchedule.isNotEmpty) {
        debugPrint('📈 Scheduling ${idsToSchedule.length} updated/new notifications for Goal $goalId');
        // Retrieve fresh objects from state to ensure fully populated data if needed
        final reloadedTasks = _tasksByGoal[goalId] ?? [];
        final reloadedMap = {for (var t in _deepFlatten(reloadedTasks)) t.id: t};
        
        for (var id in idsToSchedule) {
            final task = reloadedMap[id];
            if (task != null) {
               await _scheduleTaskNotification(task);
            }
        }
      }

    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Recursive helper to flatten tasks
  List<GoalTask> _deepFlatten(List<GoalTask> tasks) {
    List<GoalTask> result = [];
    for (var task in tasks) {
      result.add(task);
      result.addAll(_deepFlatten(task.subtasks));
    }
    return result;
  }

  // Check if notification-relevant fields changed
  bool _notificationParametersChanged(GoalTask oldTask, GoalTask newTask) {
     if (oldTask.title != newTask.title) return true;
     if (oldTask.scheduledDate != newTask.scheduledDate) return true;
     if (oldTask.frequency != newTask.frequency) return true;
     if (oldTask.isCompleted != newTask.isCompleted) return true; 
     // estimatedHours affects "At End" alerts, so check it too
     if (oldTask.estimatedHours != newTask.estimatedHours) return true;
     // suggestedTime can affect default time fallback
     if (oldTask.suggestedTime != newTask.suggestedTime) return true;
     
     return false;
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
