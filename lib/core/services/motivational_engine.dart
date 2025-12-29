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

      // 2. Filter Active Goals
      List<Goal> activeGoals = [];
      for (var g in goals) {
         // Filter out system goals
         if (g.name == 'Inbox' || g.name.startsWith('Daily Plan')) continue;
         
         final tasks = await _repository.getTasksForGoal(g.id);
         final isCompleted = tasks.isNotEmpty && tasks.every((t) => t.isCompleted);
         
         if (!isCompleted && tasks.isNotEmpty) {
           activeGoals.add(g);
         }
      }

      if (activeGoals.isEmpty) {
        debugPrint('⚠️ MotivationalEngine: No active goals to motivate.');
        return;
      }

      // A. Morning Kickstart (Wake Time +/- 1 hour, or Force)
      if (force || debug || hour == wakeTime) {
        debugPrint('☀️ Checking Morning Kickstart...');
        await _checkMorningKickstart(activeGoals);
        if (force) return; // If forced, just do one
      }
      
      // B. Deadline Nudges
      if (!force && (hour > wakeTime && hour < sleepTime)) {
        debugPrint('⏳ Checking Deadline Nudges...');
        await _checkDeadlineNudges(activeGoals);
      }

      // C. Consistency Check
      if (!force && hour == (sleepTime - 2)) {
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
    // Verify streak (mock for now, or fetch from goal metadata if available)
    int streak = 0; 
    
    // Generate Content
    String title = "Good Morning! ☀️";
    String body = "Ready to crush '${focusGoal.name}'? Let's make today count.";

    try {
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
         body = TemplateEngine.getKickstart(focusGoal.name, streak);
      }
    } catch (e) {
      // Fallback to template if AI/Premium fails
      body = TemplateEngine.getKickstart(focusGoal.name, streak);
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
             body = TemplateEngine.getDeadlineNudge(goal.name, daysLeft);
         }

         // Use modulo to prevent 32-bit integer overflow with timestamp-based Goal IDs
         _schedule(2000 + (goal.id % 2000000000), title, body);
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
         body = TemplateEngine.getConsistency(goal.name);
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
class TemplateEngine {
  static final List<String> _quotes = [
    "The only way to do great work is to love what you do.",
    "Believe you can and you're halfway there.",
    "Your limitation—it's only your imagination.",
    "Push yourself, because no one else is going to do it for you.",
    "Great things never come from comfort zones.",
    "Dream it. Wish it. Do it.",
    "Success doesn’t just find you. You have to go out and get it.",
    "The harder you work for something, the greater you’ll feel when you achieve it.",
    "Dream bigger. Do bigger.",
    "Don’t stop when you’re tired. Stop when you’re done.",
    "Wake up with determination. Go to bed with satisfaction.",
    "Do something today that your future self will thank you for.",
    "Little things make big days.",
    "It’s going to be hard, but hard does not mean impossible.",
    "Don’t wait for opportunity. Create it.",
    "Sometimes we’re tested not to show our weaknesses, but to discover our strengths.",
    "The key to success is to focus on goals, not obstacles.",
    "Dream it. Believe it. Build it.",
    "Discipline is doing what needs to be done, even if you don't want to do it.",
    "Success is the sum of small efforts, repeated day-in and day-out.",
    "The future depends on what you do today.",
    "You don’t have to be great to start, but you have to start to be great.",
    "Action is the foundational key to all success.",
    "Don’t watch the clock; do what it does. Keep going.",
    "The secret of getting ahead is getting started.",
    "It always seems impossible until it’s done.",
    "Quality is not an act, it is a habit.",
    "Start where you are. Use what you have. Do what you can.",
    "If you can dream it, you can do it.",
    "A year from now you may wish you had started today.",
    "Everything you’ve ever wanted is on the other side of fear.",
    "Your time is limited, don't waste it living someone else's life.",
    "Pain is temporary. Quitting lasts forever.",
    "The pain you feel today will be the strength you feel tomorrow.",
    "Don't count the days, make the days count.",
    "Success is not final, failure is not fatal: it is the courage to continue that counts.",
    "What you get by achieving your goals is not as important as what you become by achieving your goals.",
    "Believe in yourself and all that you are.",
    "If it doesn’t challenge you, it won’t change you.",
    "Don't let yesterday take up too much of today.",
    "You are never too old to set another goal or to dream a new dream.",
    "Goals are dreams with deadlines.",
    "A goal without a plan is just a wish.",
    "Be stubborn about your goals and flexible about your methods.",
    "The only limit to our realization of tomorrow will be our doubts of today.",
    "Do what you can, with what you have, where you are.",
    "Focus on being productive instead of busy.",
    "You don't need to see the whole staircase, just take the first step.",
    "Success is walking from failure to failure with no loss of enthusiasm.",
    "The only place where success comes before work is in the dictionary."
  ];

  static String getKickstart(String goalName, int streak) {
    if (Random().nextBool()) {
        // 50% chance for a quote
        return _getRandomQuote();
    }
    
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
    if (Random().nextBool()) {
        return _getRandomQuote();
    }

    return [
      "Crunch time! '$goalName' is due in $daysLeft days.",
      "Just $daysLeft days left for '$goalName'. Finish strong!",
      "Almost there! '$goalName' needs you.",
    ][Random().nextInt(3)];
  }

  static String getConsistency(String goalName) {
     if (Random().nextBool()) {
        return _getRandomQuote();
    }

    return [
      "Still up? Review your progress on '$goalName'.",
      "Small steps matter. Do one thing for '$goalName' tonight.",
      "Set yourself up for success tomorrow by checking '$goalName' now.",
    ][Random().nextInt(3)];
  }
  
  static String _getRandomQuote() {
     return _quotes[Random().nextInt(_quotes.length)];
  }
}
