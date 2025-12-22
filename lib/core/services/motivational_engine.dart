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

  Future<void> checkAndSchedule({bool debug = false}) async {
    debugPrint('🚀 MotivationalEngine: Starting check... (Debug: $debug)');
    
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

      if (!debug && quietMode && (hour < wakeTime || hour >= sleepTime)) {
        debugPrint('🌙 MotivationalEngine: Quiet hours. Skipping.');
        return;
      }

      // 2. Filter Active Goals (since Goal model doesn't have isCompleted/status)
      // We'll consider a goal "active" if it has tasks and not all are completed.
      // This is expensive (N+1 queries), but okay for background task with few goals.
      List<Goal> activeGoals = [];
      for (var g in goals) {
         final tasks = await _repository.getTasksForGoal(g.id);
         final isCompleted = tasks.isNotEmpty && tasks.every((t) => t.isCompleted);
         // Also filter out if no tasks (nothing to motivate) ? Or motivate to add tasks?
         // Let's keep goals that are NOT completed.
         if (!isCompleted) {
           activeGoals.add(g);
         }
      }

      // A. Morning Kickstart
      if (debug || hour == wakeTime) {
        debugPrint('☀️ Checking Morning Kickstart...');
        await _checkMorningKickstart(activeGoals);
      }
      
      // B. Deadline Nudges
      if (debug || (hour > wakeTime && hour < sleepTime)) {
        debugPrint('⏳ Checking Deadline Nudges...');
        await _checkDeadlineNudges(activeGoals);
      }

      // C. Consistency Check
      if (debug || hour == (sleepTime - 2)) {
        debugPrint('🌙 Checking Consistency...');
        await _checkConsistency(activeGoals);
      }
      
    } catch (e) {
      debugPrint('❌ MotivationalEngine Error: $e');
    }
  }

  Future<void> _checkMorningKickstart(List<Goal> goals) async {
    if (goals.isEmpty) return;

    // Pick a goal to focus on
    final focusGoal = goals[Random().nextInt(goals.length)];
    int streak = 0; // Placeholder for streak logic
    
    // Generate Content
    String title = "Good Morning! ☀️";
    String body = "Ready to crush '${focusGoal.name}'? Let's make today count.";

    if (await _premiumService.isPremium()) {
       // AI Generation (Premium)
       final prompt = "Generate a short morning motivation (MAX 15 words) for a user working on goal '${focusGoal.name}'. Streak: $streak days.";
       final aiResponse = await _gptService.generateContextAwareMessage(
          systemInstruction: 'You are a motivational coach. Keep messages under 15 words.',
          userPrompt: prompt, 
          maxTokens: 30, // Reduced tokens
       );
       if (aiResponse != null) body = aiResponse;
    } else {
       // Template (Free)
       body = _TemplateEngine.getKickstart(focusGoal.name, streak);
    }

    _schedule(1001, title, body);
  }

  Future<void> _checkDeadlineNudges(List<Goal> goals) async {
    final now = DateTime.now();

    for (var goal in goals) {
      if (goal.targetDeadline == null) continue;

      final deadline = goal.targetDeadline!;
      final difference = deadline.difference(now);
      final daysLeft = difference.inDays;

      // Nudge at 48h and 24h
      if (daysLeft == 1 || daysLeft == 2) {
         String title = "Deadline Approaching ⏳";
         String body = "Only $daysLeft days left for '${goal.name}'. You got this!";

         if (await _premiumService.isPremium()) {
             final prompt = "User's goal '${goal.name}' is due in $daysLeft days. Write a urgent nudge (MAX 15 words).";
             final aiResponse = await _gptService.generateContextAwareMessage(
                systemInstruction: 'You are a motivational coach. Keep messages under 15 words.',
                userPrompt: prompt, 
                maxTokens: 30,
             );
             if (aiResponse != null) body = aiResponse;
         } else {
             body = _TemplateEngine.getDeadlineNudge(goal.name, daysLeft);
         }

         _schedule(2000 + goal.id, title, body);
      }
    }
  }

  Future<void> _checkConsistency(List<Goal> goals) async {
    if (goals.isEmpty) return;
    
    final goal = goals.first;
    
    String title = "End the day strong 🌙";
    String body = "Any unfinished tasks for '${goal.name}'? 15 mins is all it takes.";

    if (await _premiumService.isPremium()) {
         final prompt = "It's evening. User might have unfinished tasks for '${goal.name}'. Write a gentle nudge (MAX 15 words).";
         final aiResponse = await _gptService.generateContextAwareMessage(
             systemInstruction: 'You are a gentle accountability partner. Keep messages under 15 words.',
             userPrompt: prompt, 
             maxTokens: 30,
         );
         if (aiResponse != null) body = aiResponse;
    } else {
         body = _TemplateEngine.getConsistency(goal.name);
    }

    _schedule(3001, title, body);
  }

  void _schedule(int id, String title, String body) {
    _notifications.showNotification(
      id: id,
      title: title,
      body: body,
      payload: '{"type": "motivational"}',
    );
  }
}

/// Helper for Free Tier Templates
class _TemplateEngine {
  static String getKickstart(String goalName, int streak) {
    final templates = [
      "Rise and shine! ⚡ Time to work on '$goalName'.",
      "New day, new progress on '$goalName'. Let's go!",
      "You're doing great! Keep the momentum going on '$goalName'.",
    ];
    if (streak > 2) {
      templates.add("You're on a $streak-day streak! Don't break it now!");
    }
    return templates[Random().nextInt(templates.length)];
  }

  static String getDeadlineNudge(String goalName, int daysLeft) {
    return [
      "Crunch time! '$goalName' is due in $daysLeft days.",
      "Just $daysLeft days left for '$goalName'. Finish strong!",
      "Almost there! '$goalName' needs you.",
    ][Random().nextInt(3)];
  }

  static String getConsistency(String goalName) {
    return [
      "Still up? Review your progress on '$goalName'.",
      "Small steps matter. Do one thing for '$goalName' tonight.",
      "Set yourself up for success tomorrow by checking '$goalName' now.",
    ][Random().nextInt(3)];
  }
}
