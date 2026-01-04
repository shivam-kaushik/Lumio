import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/models/goal.dart';
import '../../data/models/goal_task.dart';
import '../../data/repositories/firestore_growth_repository.dart';
import 'notification_service.dart';
import 'privacy_gpt_service.dart';
import 'premium_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Engine to drive "Context-Aware Motivation"
/// Runs in background via Workmanager
class MotivationalEngine {
  final FirestoreGrowthRepository _repository;
  final NotificationService _notifications;
  final PrivacyGptService _gptService;
  final PremiumService _premiumService;

  MotivationalEngine({
    FirestoreGrowthRepository? repository,
    NotificationService? notifications,
    PrivacyGptService? gptService,
    PremiumService? premiumService,
  })  : _repository = repository ?? FirestoreGrowthRepository(),
        _notifications = notifications ?? NotificationService(),
        _gptService = gptService ?? PrivacyGptService(),
        _premiumService = premiumService ?? PremiumService();

  Future<void> checkAndSchedule({bool debug = false, bool force = false}) async {
    debugPrint('🚀 MotivationalEngine: Starting check... (Debug: $debug, Force: $force)');
    
    try {
      // 1. Load User Context
      final goals = await _repository.getGoals();
      final prefs = await SharedPreferences.getInstance();
      
      final now = DateTime.now();
      final hour = now.hour;
      
      // Load settings (with defaults)
      final wakeTime = prefs.getInt('setting_wake_time') ?? 8; // 8 AM
      final sleepTime = prefs.getInt('setting_sleep_time') ?? 22; // 10 PM
      final quietMode = prefs.getBool('setting_quiet_mode') ?? false;

      // Skip if quiet hours (unless forced or debug)
      if (!force && !debug && quietMode && (hour < wakeTime || hour >= sleepTime)) {
        debugPrint('🌙 MotivationalEngine: Quiet hours. Skipping.');
        return;
      }

      // 2. Data Gathering: Flatten all pending items (Goals and Subtasks)
      List<_PendingItem> allPendingItems = [];

      for (var goal in goals) {
         if (goal.name == 'Inbox' || goal.name.startsWith('Daily Plan')) continue;
         
         // Add the goal itself if active
         // We consider it active if we are processing it (filtering happens by checking tasks later)
         // or we can assume all non-archived goals are active for now.
         
         // Add pending tasks (Goal itself doesn't need to be in the list as "goal_*",
         // effective motivation comes from specific tasks usually. 
         // But if we want generic goal motivation, we can keep it without the progress check).
         allPendingItems.add(_PendingItem(
              id: "goal_${goal.id}", 
              title: goal.name, 
              type: _ItemType.goal, 
              deadline: goal.targetDeadline,
              parentGoalName: goal.name,
              priority: 1, // Base priority
            ));

         // Add its pending tasks recursively
         final tasks = await _repository.getTasksForGoal(goal.id);
         allPendingItems.addAll(_getPendingTasksRecursive(tasks, goal.name));
      }

      if (allPendingItems.isEmpty) {
        debugPrint('⚠️ MotivationalEngine: No pending items to motivate.');
        return;
      }

      debugPrint('📋 Found ${allPendingItems.length} pending items (Goals + Subtasks)');

      // A. Morning Kickstart (Wake Time +/- 1 hour, or Force)
      if (force || debug || hour == wakeTime) {
        debugPrint('☀️ Checking Morning Kickstart...');
        await _checkMorningKickstart(allPendingItems);
        if (force) return; 
      }
      
      // B. Deadline Nudges
      if (!force && (hour > wakeTime && hour < sleepTime)) {
        debugPrint('⏳ Checking Deadline Nudges...');
        await _checkDeadlineNudges(allPendingItems);
      }

      // C. Consistency Check
      if (!force && hour == (sleepTime - 2)) {
        debugPrint('🌙 Checking Consistency...');
        await _checkConsistency(allPendingItems);
      }
      
    } catch (e) {
      debugPrint('❌ MotivationalEngine Error: $e');
    }
  }

  /// Recursively flatten tasks into _PendingItem list
  List<_PendingItem> _getPendingTasksRecursive(List<GoalTask> tasks, String parentGoalName) {
    List<_PendingItem> pending = [];
    for (var task in tasks) {
      if (task.isCompleted) continue;

      // Map priority string to int for simple sorting
      int priorityVal = 1;
      if (task.priority == 'high') priorityVal = 3;
      if (task.priority == 'medium') priorityVal = 2;

      pending.add(_PendingItem(
        id: "task_${task.id}",
        title: task.title,
        type: _ItemType.task,
        deadline: task.scheduledDate,
        parentGoalName: parentGoalName,
        priority: priorityVal,
      ));

      // Recurse
      if (task.subtasks.isNotEmpty) {
        pending.addAll(_getPendingTasksRecursive(task.subtasks, parentGoalName));
      }
    }
    return pending;
  }


  Future<void> _checkMorningKickstart(List<_PendingItem> items) async {
    // Pick high priority item
    final highPriorityItems = items.where((i) => i.priority >= 2).toList();
    final focusItem = highPriorityItems.isNotEmpty 
        ? highPriorityItems[Random().nextInt(highPriorityItems.length)]
        : items[Random().nextInt(items.length)];
    
    // Generate Content
    String title = "Morning Focus ☀️";
    String body = "Let's tackle '${focusItem.title}' today. Small steps!";

    if (focusItem.type == _ItemType.task) {
       body = "Today's mission: '${focusItem.title}' for your '${focusItem.parentGoalName}' goal.";
    }

    try {
      if (await _premiumService.isPremium()) {
         final prompt = "Morning motivation for task '${focusItem.title}' (part of goal '${focusItem.parentGoalName}'). User needs to start. Max 15 words.";
         final aiResponse = await _gptService.generateContextAwareMessage(
            systemInstruction: 'You are a concise motivational coach.',
            userPrompt: prompt, 
            maxTokens: 35,
         );
         if (aiResponse != null) body = aiResponse;
      } else {
         body = TemplateEngine.getKickstart(focusItem.title, focusItem.parentGoalName);
      }
    } catch (e) {
      // Fallback
      body = TemplateEngine.getKickstart(focusItem.title, focusItem.parentGoalName);
    }

    _schedule(1001, title, body, payload: '{"reminder_id": "${focusItem.id}"}');
  }

  Future<void> _checkDeadlineNudges(List<_PendingItem> items) async {
    final now = DateTime.now();

    for (var item in items) {
      if (item.deadline == null) continue;

      final deadline = item.deadline!;
      final difference = deadline.difference(now);
      final daysLeft = difference.inDays;
      final hoursLeft = difference.inHours;

      // Nudge at < 24h and < 48h
      bool urgent = hoursLeft > 0 && hoursLeft < 24;
      bool upcoming = daysLeft >= 1 && daysLeft <= 2;

      if (urgent || upcoming) {
         String title = urgent ? "Due Today! ⏰" : "Coming Up ⏳";
         String timeString = urgent ? "today" : "in $daysLeft days";
         String body = "Don't forget '${item.title}' is due $timeString.";

         if (await _premiumService.isPremium()) {
             final prompt = "Task '${item.title}' is due $timeString. Write a short urgent notification. Max 15 words.";
             final aiResponse = await _gptService.generateContextAwareMessage(
                systemInstruction: 'You are a helpful reminder assistant.',
                userPrompt: prompt, 
                maxTokens: 30,
             );
             if (aiResponse != null) body = aiResponse;
         } else {
             body = TemplateEngine.getDeadlineNudge(item.title, timeString);
         }

    _schedule(2000 + (item.id.hashCode.abs() % 100000), title, body, payload: '{"reminder_id": "${item.id}"}');
      }
    }
  }

  Future<void> _checkConsistency(List<_PendingItem> items) async {
    // Pick a random pending item
    if (items.isEmpty) return;
    final item = items[Random().nextInt(items.length)];
    
    String title = "Daily Check-in 🌙";
    String body = "Did you make progress on '${item.title}' today?";

    if (await _premiumService.isPremium()) {
         final prompt = "Evening check-in. Ask if user made progress on '${item.title}'. Gentle tone. Max 15 words.";
         final aiResponse = await _gptService.generateContextAwareMessage(
             systemInstruction: 'You are a gentle accountability partner.',
             userPrompt: prompt, 
             maxTokens: 30,
         );
         if (aiResponse != null) body = aiResponse;
    } else {
         body = TemplateEngine.getConsistency(item.title);
    }

    _schedule(3001, title, body, payload: '{"reminder_id": "${item.id}"}');
  }

  void _schedule(int id, String title, String body, {String? payload}) {
    // Merge title/body into payload if not already there
    String finalPayload = payload ?? '{}';
    try {
      if (payload != null) {
         // If payload exists, define structure or append
         final cleanPayload = payload.trim();
         if (cleanPayload.startsWith('{') && cleanPayload.endsWith('}')) {
             // It's JSON, inject title/body
             final content = cleanPayload.substring(1, cleanPayload.length - 1);
             finalPayload = '{"title": "$title", "body": "$body", $content}'; 
         }
      } else {
         finalPayload = '{"type": "motivational", "title": "$title", "body": "$body"}';
      }
    } catch (_) {
       finalPayload = '{"type": "motivational", "title": "$title", "body": "$body"}';
    }

    _notifications.showNotification(
      id: id,
      title: title,
      body: body,
      payload: finalPayload,
    );
  }
}

enum _ItemType { goal, task }

class _PendingItem {
  final String id;
  final String title;
  final _ItemType type;
  final DateTime? deadline;
  final String parentGoalName;
  final int priority;

  _PendingItem({
    required this.id,
    required this.title,
    required this.type,
    this.deadline,
    required this.parentGoalName,
    this.priority = 1,
  });
}

/// Helper for Free Tier Templates
class TemplateEngine {
  static final List<String> _quotes = [
    "The secret of getting ahead is getting started.",
    "It always seems impossible until it’s done.",
    "Don’t watch the clock; do what it does. Keep going.",
    "Quality is not an act, it is a habit.",
    "Believe you can and you're halfway there.",
  ];
  
  static String getRandomQuote() => _quotes[Random().nextInt(_quotes.length)];

  static String getKickstart(String title, String context) {
    if (Random().nextBool()) return getRandomQuote();
    
    final templates = [
      "Ready to tackle '$title'? Let's move '$context' forward!",
      "Focus time: '$title'. You got this.",
      "Make today count. Start with '$title'.",
    ];
    return templates[Random().nextInt(templates.length)];
  }

  static String getDeadlineNudge(String title, String timeString) {
    return [
      "Heads up! '$title' is due $timeString.",
      "Finish strong! '$title' needs your attention $timeString.",
      "Deadline approaching for '$title'.",
    ][Random().nextInt(3)];
  }

  static String getConsistency(String title) {
    return [
      "How did it go with '$title' today?",
      "Small progress on '$title' is still progress.",
      "Ready for tomorrow? Review '$title' status.",
    ][Random().nextInt(3)];
  }

  static String getTaskReminder(String taskTitle, String goalName) {
    if (Random().nextBool()) return getRandomQuote();

    final templates = [
      "Time for '$taskTitle'. One step closer to '$goalName'!",
      "Let's crush '$taskTitle' for your '$goalName' goal.",
      "Focus time: '$taskTitle'. You got this!",
      "Making progress on '$goalName' starts with '$taskTitle'.",
      "Don't put off '$taskTitle'. Do it for '$goalName'.",
    ];
    return templates[Random().nextInt(templates.length)];
  }
}
