import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/conversation_models.dart';
import 'premium_service.dart';

/// Privacy-preserving GPT service
/// Anonymizes data before sending to GPT API
/// Requires premium subscription for AI-powered features
class PrivacyGptService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-3.5-turbo'; // Fast and cost-effective
  final PremiumService _premiumService = PremiumService();

  /// Ask clarifying question using GPT with privacy protection
  /// Returns fallback response if user is not premium
  Future<GptResponse> askClarifyingQuestion({
    required Map<String, dynamic> localExtracted,
    required List<String> missingFields,
    required String conversationContext,
  }) async {
    try {
      // Check premium status first
      final premiumService = PremiumService();
      final isPremium = await premiumService.isPremium();
      
      if (!isPremium) {
        debugPrint('⚠️ GPT clarifying questions require premium subscription');
        return _fallbackQuestion(missingFields);
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];

      if (apiKey == null ||
          apiKey.isEmpty ||
          apiKey == 'your_openai_api_key_here') {
        debugPrint('⚠️ OpenAI API key not configured');
        return _fallbackQuestion(missingFields);
      }

      // 1. Anonymize sensitive data
      final anonymized = _anonymizeData(localExtracted);

      // 2. Build privacy-focused prompt
      final prompt = _buildPrivacyPrompt(
        anonymized: anonymized,
        missingFields: missingFields,
        context: conversationContext,
      );

      // 3. Call GPT API
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': _buildSystemInstructions(),
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 150,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content =
            data['choices'][0]['message']['content'] as String;

        // Parse JSON response
        try {
          final parsed = jsonDecode(content.trim());
          return GptResponse(
            question: parsed['question'] as String? ?? _fallbackQuestion(missingFields).question,
            field: parsed['field'] as String?,
            extractedData: parsed['extractedData'] as Map<String, dynamic>?,
          );
        } catch (e) {
          // If not JSON, use as plain text
          return GptResponse(
            question: content.trim(),
            field: missingFields.isNotEmpty ? missingFields.first : null,
          );
        }
      } else {
        debugPrint(
          '❌ GPT API error: ${response.statusCode} - ${response.body}',
        );
        return _fallbackQuestion(missingFields);
      }
    } catch (e) {
      debugPrint('❌ GPT service error: $e');
      return _fallbackQuestion(missingFields);
    }
  }

  /// Build system instructions for GPT
  String _buildSystemInstructions() {
    return '''You are Lumio, a privacy-focused reminder assistant.

CRITICAL RULES:
1. ONLY ask about REQUIRED fields - never ask about optional fields
2. Ask ONE question at a time
3. If user gives a time, assume it's for TODAY unless they specify a date
4. If user doesn't mention recurring, assume it's ONE-TIME
5. NEVER ask about: priority, category, reason, intent (unless completely unclear)
6. Extract as much as possible from the user's message

Required fields ONLY:
- text: What to remind about (ALWAYS required)
- trigger: When/how (time OR location OR activity - at least one required)
  - If time-based: need time (date defaults to today)
  - If location-based: need location name + arrive/leave trigger
  - If recurring: need interval + unit (ONLY if user mentions recurring)

Optional fields (NEVER ask - use defaults):
- priority: Always defaults to Medium
- category: Always defaults to Other
- recurring: Always defaults to one-time unless user says "every", "daily", etc.

Inference rules:
- "8 pm" or "3 PM" → time for TODAY
- "call Mom" → text is "call Mom", infer time-based if no location mentioned
- "when I leave home" → location-based, onLeave=true
- "every day" → recurring, interval=1, unit=days

Privacy rules:
- Don't ask for personal details
- Use generic location types (home, work, gym)
- Keep questions minimal and focused

Always respond with JSON:
{
  "question": "Your question here",
  "field": "field_name"
}

Example good questions:
- "What time should I remind you?" (if text exists but no time)
- "Which location? Home, work, or another place?" (if location-based but no location)
- "When should I remind you? At a specific time or when you reach a location?" (if intent unclear)

Example BAD questions (NEVER ask these):
- "What's the priority?" ❌
- "What category?" ❌
- "What's the reason?" ❌
- "Is this recurring?" ❌ (unless user mentioned recurring)
- "Is this for today?" ❌ (assume today if time given)
''';
  }

  /// Anonymize personal data
  Map<String, dynamic> _anonymizeData(Map<String, dynamic> data) {
    final anonymized = Map<String, dynamic>.from(data);

    // Replace personal names with placeholders
    if (anonymized['text'] != null) {
      anonymized['text'] = _replacePersonalNames(
        anonymized['text'] as String,
      );
    }

    // Remove exact addresses (keep location type only)
    if (anonymized['location'] != null) {
      final loc = anonymized['location'] as String;
      anonymized['location'] = _normalizeLocation(loc);
    }

    // Remove exact coordinates if present
    anonymized.remove('geofenceLat');
    anonymized.remove('geofenceLng');

    return anonymized;
  }

  /// Replace personal names with placeholders
  String _replacePersonalNames(String text) {
    // Common name patterns (simple heuristic)
    // In production, use a more sophisticated approach
    final namePatterns = [
      RegExp(r'\b([A-Z][a-z]+)\s+([A-Z][a-z]+)\b'), // First Last
    ];

    String result = text;
    for (var pattern in namePatterns) {
      result = result.replaceAll(pattern, '[Person]');
    }

    return result;
  }

  /// Normalize location (keep type only)
  String _normalizeLocation(String location) {
    final lower = location.toLowerCase();

    // Map to generic types
    if (lower.contains('home') || lower.contains('house') || lower.contains('residence')) {
      return 'home';
    }
    if (lower.contains('work') || lower.contains('office')) {
      return 'work';
    }
    if (lower.contains('gym') || lower.contains('fitness')) {
      return 'gym';
    }
    if (lower.contains('school') || lower.contains('university')) {
      return 'school';
    }

    // If it looks like an address (contains numbers), return generic
    if (RegExp(r'\d').hasMatch(location)) {
      return '[Location]';
    }

    return location;
  }

  /// Build privacy-focused prompt
  String _buildPrivacyPrompt({
    required Map<String, dynamic> anonymized,
    required List<String> missingFields,
    required String context,
  }) {
    return '''User provided:
- Reminder text: ${anonymized['text'] ?? 'Not provided'}
- Intent: ${anonymized['intent'] ?? 'Not clear'}
- Time: ${anonymized['time'] ?? 'Not provided'}
- Location: ${anonymized['location'] ?? 'Not provided'}
- Recurrence: ${anonymized['repeatInterval'] != null && anonymized['repeatUnit'] != null ? 'Every ${anonymized['repeatInterval']} ${anonymized['repeatUnit']}' : 'Not provided (one-time)'}

Missing REQUIRED fields ONLY: ${missingFields.join(', ')}

Conversation context:
$context

CRITICAL: Ask ONLY ONE question about the most critical missing REQUIRED field.
- NEVER ask about priority, category, reason, or recurring (unless user explicitly mentioned recurring)
- If time is missing, ask "What time should I remind you?"
- If location is missing and intent is location-based, ask "Which location? Home, work, or another place?"
- Keep it SHORT and DIRECT

Return JSON:
{
  "question": "Your question here",
  "field": "field_name"
}
''';
  }

  /// Generate detailed business roadmap with deadline and capacity (Solopreneur Execution Assistant)
  /// Returns fallback roadmap if user is not premium
  Future<Map<String, dynamic>?> generateDetailedRoadmap(
    String goalDescription, {
    required DateTime targetDeadline,
    required double hoursPerDay,
  }) async {
    try {
      // Check premium status first
      final premiumService = PremiumService();
      final isPremium = await premiumService.isPremium();
      
      if (!isPremium) {
        debugPrint('⚠️ AI roadmap generation requires premium subscription');
        return _fallbackDetailedRoadmap(goalDescription, targetDeadline, hoursPerDay);
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];

      if (apiKey == null ||
          apiKey.isEmpty ||
          apiKey == 'your_openai_api_key_here') {
        debugPrint('⚠️ OpenAI API key not configured');
        return _fallbackDetailedRoadmap(goalDescription, targetDeadline, hoursPerDay);
      }

      final daysUntilDeadline = targetDeadline.difference(DateTime.now()).inDays;
      final totalAvailableHours = daysUntilDeadline * hoursPerDay;

      final prompt = '''
Goal: "$goalDescription"
Deadline: ${targetDeadline.toString().split(' ')[0]} ($daysUntilDeadline days away)

Break this goal into 4-7 actionable tasks. Each task needs 2-3 concrete subtasks.

Return ONLY valid JSON, no markdown:
{
  "tasks": [
    {
      "title": "Task name",
      "description": "What to do",
      "priority": "high",
      "subtasks": [
        {"title": "Subtask", "description": "Specific action"},
        {"title": "Subtask", "description": "Specific action"}
      ]
    }
  ]
}
''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a business execution assistant for solopreneurs. Create realistic, actionable business plans. Always return valid JSON. Be empathetic and practical.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 900,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        try {
          String jsonContent = content.trim();
          if (jsonContent.contains('```json')) {
            jsonContent = jsonContent.split('```json')[1].split('```')[0].trim();
          } else if (jsonContent.contains('```')) {
            jsonContent = jsonContent.split('```')[1].split('```')[0].trim();
          }

          final parsed = jsonDecode(jsonContent) as Map<String, dynamic>;
          
          // Add deadline and capacity to response
          parsed['targetDeadline'] = targetDeadline.toIso8601String();
          parsed['hoursPerDay'] = hoursPerDay;
          
          return parsed;
        } catch (e) {
          debugPrint('❌ Error parsing GPT roadmap response: $e');
          debugPrint('Response content: $content');
          return _fallbackDetailedRoadmap(goalDescription, targetDeadline, hoursPerDay);
        }
      } else {
        debugPrint('❌ GPT API error: ${response.statusCode} - ${response.body}');
        return _fallbackDetailedRoadmap(goalDescription, targetDeadline, hoursPerDay);
      }
    } catch (e) {
      debugPrint('❌ GPT service error generating detailed roadmap: $e');
      return _fallbackDetailedRoadmap(goalDescription, targetDeadline, hoursPerDay);
    }
  }

  /// Fallback detailed roadmap when GPT is unavailable
  Map<String, dynamic> _fallbackDetailedRoadmap(
    String goalDescription,
    DateTime targetDeadline,
    double hoursPerDay,
  ) {
    final daysUntilDeadline = targetDeadline.difference(DateTime.now()).inDays;
    return {
      'goal': goalDescription,
      'targetDeadline': targetDeadline.toIso8601String(),
      'hoursPerDay': hoursPerDay,
      'totalEstimatedHours': (daysUntilDeadline * hoursPerDay * 0.7).round(), // 70% utilization
      'tasks': [
        {
          'title': 'Research and plan',
          'description': 'Research and create a detailed plan for achieving this goal',
          'estimatedHours': 8.0,
          'priority': 'high',
          'dependencies': [],
          'isMilestone': true,
          'motivationAnchor': 'A solid plan is the foundation of successful execution',
          'estimatedFrequency': 'one-time',
          'suggestedTime': 'morning',
          'subtasks': [
            {'title': 'Define success criteria', 'description': 'Write down what done looks like in measurable terms', 'estimatedHours': 1.0},
            {'title': 'Research existing approaches', 'description': 'Look up how others have achieved similar goals', 'estimatedHours': 3.0},
            {'title': 'Create action plan document', 'description': 'Write your step-by-step strategy with timelines', 'estimatedHours': 2.0},
            {'title': 'Identify required resources', 'description': 'List tools, skills, or help you will need', 'estimatedHours': 1.0},
          ],
        },
        {
          'title': 'Execute core tasks',
          'description': 'Work on the main tasks required to achieve your goal',
          'estimatedHours': (daysUntilDeadline * hoursPerDay * 0.5).toDouble(),
          'priority': 'high',
          'dependencies': ['Research and plan'],
          'isMilestone': false,
          'motivationAnchor': 'Consistent daily action compounds into significant progress',
          'estimatedFrequency': 'daily',
          'suggestedTime': 'any',
          'subtasks': [
            {'title': 'Complete first milestone', 'description': 'Focus on the first concrete deliverable', 'estimatedHours': (daysUntilDeadline * hoursPerDay * 0.15).toDouble()},
            {'title': 'Build on momentum', 'description': 'Continue executing with daily focus sessions', 'estimatedHours': (daysUntilDeadline * hoursPerDay * 0.2).toDouble()},
            {'title': 'Reach halfway checkpoint', 'description': 'Verify progress and adjust approach if needed', 'estimatedHours': (daysUntilDeadline * hoursPerDay * 0.1).toDouble()},
          ],
        },
        {
          'title': 'Review and adjust',
          'description': 'Weekly review and adjustment of your approach',
          'estimatedHours': (daysUntilDeadline / 7 * 2).toDouble(),
          'priority': 'medium',
          'dependencies': [],
          'isMilestone': false,
          'motivationAnchor': 'Regular reviews keep you on track and allow course correction',
          'estimatedFrequency': 'weekly',
          'suggestedTime': 'evening',
          'subtasks': [
            {'title': 'Review completed work', 'description': 'Assess quality and completeness of what you have done', 'estimatedHours': 1.0},
            {'title': 'Identify blockers', 'description': 'Note anything slowing you down and brainstorm solutions', 'estimatedHours': 0.5},
            {'title': 'Update plan for next week', 'description': 'Revise tasks and priorities based on current progress', 'estimatedHours': 0.5},
          ],
        },
      ],
      'weeklyGoals': [
        'Week 1: Complete initial research and planning',
        'Week 2: Begin core execution tasks',
        'Week 3: Continue execution and review progress',
      ],
      'riskAlerts': [
        'Risk: Underestimating time needed. Mitigation: Add buffer time to estimates.',
        'Risk: Losing momentum. Mitigation: Set daily reminders and track progress.',
      ],
    };
  }

  /// Generate subtasks for a goal (MVP: Goal breakdown) - Legacy method
  Future<Map<String, dynamic>?> generateSubtasks(String goalDescription) async {
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];

      if (apiKey == null ||
          apiKey.isEmpty ||
          apiKey == 'your_openai_api_key_here') {
        debugPrint('⚠️ OpenAI API key not configured');
        return _fallbackSubtasks(goalDescription);
      }

      final prompt = '''
Break this business goal into 5-8 actionable subtasks that an entrepreneur can work on daily or weekly.

Goal: $goalDescription

For each subtask, provide:
- title: Short, actionable task name
- description: What to do
- estimatedFrequency: "daily", "weekly", "monthly", or "one-time"
- suggestedTime: "morning", "afternoon", "evening", or "any"
- priority: "high", "medium", or "low"

Return ONLY valid JSON in this format:
{
  "goal": "goal name",
  "subtasks": [
    {
      "title": "subtask name",
      "description": "what to do",
      "estimatedFrequency": "daily",
      "suggestedTime": "morning",
      "priority": "high"
    }
  ]
}
''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a business goal breakdown assistant. Break goals into actionable subtasks. Always return valid JSON.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.7,
          'max_tokens': 1000,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Parse JSON response
        try {
          // Extract JSON from markdown code blocks if present
          String jsonContent = content.trim();
          if (jsonContent.contains('```json')) {
            jsonContent = jsonContent.split('```json')[1].split('```')[0].trim();
          } else if (jsonContent.contains('```')) {
            jsonContent = jsonContent.split('```')[1].split('```')[0].trim();
          }

          final parsed = jsonDecode(jsonContent) as Map<String, dynamic>;
          return parsed;
        } catch (e) {
          debugPrint('❌ Error parsing GPT subtask response: $e');
          debugPrint('Response content: $content');
          return _fallbackSubtasks(goalDescription);
        }
      } else {
        debugPrint(
          '❌ GPT API error: ${response.statusCode} - ${response.body}',
        );
        return _fallbackSubtasks(goalDescription);
      }
    } catch (e) {
      debugPrint('❌ GPT service error generating subtasks: $e');
      return _fallbackSubtasks(goalDescription);
    }
  }

  /// Fallback subtasks when GPT is unavailable
  Map<String, dynamic> _fallbackSubtasks(String goalDescription) {
    return {
      'goal': goalDescription,
      'subtasks': [
        {
          'title': 'Research and plan',
          'description': 'Research and create a plan for achieving this goal',
          'estimatedFrequency': 'weekly',
          'suggestedTime': 'morning',
          'priority': 'high',
        },
        {
          'title': 'Take action',
          'description': 'Work on tasks related to this goal',
          'estimatedFrequency': 'daily',
          'suggestedTime': 'any',
          'priority': 'high',
        },
        {
          'title': 'Review progress',
          'description': 'Review and adjust your approach',
          'estimatedFrequency': 'weekly',
          'suggestedTime': 'evening',
          'priority': 'medium',
        },
      ],
    };
  }

  /// Generate subtasks for a specific task using AI
  Future<List<Map<String, dynamic>>> generateSubtasksForTask(
    String goalName,
    String taskTitle, {
    String? taskDescription,
  }) async {
    try {
      final premiumService = PremiumService();
      final isPremium = await premiumService.isPremium();

      if (!isPremium) {
        return _fallbackSubtasksForTask(taskTitle);
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty || apiKey == 'your_openai_api_key_here') {
        return _fallbackSubtasksForTask(taskTitle);
      }

      final prompt = '''
Break this task into 3-5 concrete, actionable subtasks.

Goal: $goalName
Task: $taskTitle
${taskDescription != null && taskDescription.isNotEmpty ? 'Context: $taskDescription' : ''}

For each subtask provide:
- title: Short, action-verb name (e.g. "Write intro paragraph")
- description: One sentence on what to do specifically

Return ONLY a valid JSON array:
[
  {"title": "subtask name", "description": "what to do"},
  {"title": "subtask name", "description": "what to do"}
]
''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a productivity assistant. Break tasks into actionable subtasks. Return only valid JSON.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.6,
          'max_tokens': 600,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        try {
          String jsonContent = content.trim();
          if (jsonContent.contains('```json')) {
            jsonContent = jsonContent.split('```json')[1].split('```')[0].trim();
          } else if (jsonContent.contains('```')) {
            jsonContent = jsonContent.split('```')[1].split('```')[0].trim();
          }
          final parsed = jsonDecode(jsonContent) as List;
          return parsed.cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('❌ Error parsing subtasks for task response: $e');
          return _fallbackSubtasksForTask(taskTitle);
        }
      } else {
        return _fallbackSubtasksForTask(taskTitle);
      }
    } catch (e) {
      debugPrint('❌ Error generating subtasks for task: $e');
      return _fallbackSubtasksForTask(taskTitle);
    }
  }

  List<Map<String, dynamic>> _fallbackSubtasksForTask(String taskTitle) {
    return [
      {'title': 'Plan approach', 'description': 'Define the steps and strategy needed to complete $taskTitle'},
      {'title': 'Gather resources', 'description': 'Collect any tools, materials, or information required'},
      {'title': 'Execute main work', 'description': 'Complete the core work for this task'},
      {'title': 'Review and wrap up', 'description': 'Check quality and finalize the output'},
    ];
  }

  /// Generate motivational message for reminder (Solopreneur Execution Assistant)
  /// Returns fallback message if user is not premium
  Future<String?> generateMotivationalMessage({
    required String goalName,
    required String taskDescription,
    String? skillName, // Deprecated, kept for compatibility
    int streakCount = 0, // Deprecated, kept for compatibility
    int totalReps = 0, // Deprecated, kept for compatibility
    String? motivationAnchor,
    String? personaPrompt, // NEW: Persona System Prompt
  }) async {
    try {
      // Check premium status first
      final premiumService = PremiumService();
      final isPremium = await premiumService.isPremium();
      
      if (!isPremium) {
        debugPrint('⚠️ AI motivational messages require premium subscription');
        return _fallbackMotivationalMessage(
          goalName: goalName,
          taskDescription: taskDescription,
          // skillName deprecated
          motivationAnchor: motivationAnchor,
        );
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];

      if (apiKey == null ||
          apiKey.isEmpty ||
          apiKey == 'your_openai_api_key_here') {
        return _fallbackMotivationalMessage(
          goalName: goalName,
          taskDescription: taskDescription,
          // skillName deprecated
          motivationAnchor: motivationAnchor,
        );
      }

      final prompt = '''
You are Lumio, a private execution assistant for solopreneurs. Generate a short, motivational reminder message (max 60 words) that:

1. Acknowledges the task: "$taskDescription"
2. Connects it to the bigger goal: "$goalName"
${motivationAnchor != null ? '3. Reinforces why it matters: "$motivationAnchor"' : ''}

Tone: Empathetic, encouraging, non-judgmental. Focus on progress and momentum, not pressure.
Style: Personal, like a supportive business partner.

Return ONLY the message text, no quotes, no JSON, just the motivational message.
''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': personaPrompt ?? 'You are a motivational assistant for entrepreneurs. Generate short, encouraging messages that help users stay motivated. Be empathetic and practical.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': 0.8,
          'max_tokens': 100,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim().replaceAll('"', '').replaceAll('\n', ' ');
      } else {
        return _fallbackMotivationalMessage(
          goalName: goalName,
          taskDescription: taskDescription,
          motivationAnchor: motivationAnchor,
          personaPrompt: personaPrompt,
        );
      }
    } catch (e) {
      debugPrint('❌ Error generating motivational message: $e');
      return _fallbackMotivationalMessage(
        goalName: goalName,
        taskDescription: taskDescription,
        motivationAnchor: motivationAnchor,
        personaPrompt: personaPrompt,
      );
    }
  }

  /// Generate generic context-aware message (Flexible endpoint for MotivationalEngine)
  /// Returns null if API call fails or user not premium
  Future<String?> generateContextAwareMessage({
    required String systemInstruction,
    required String userPrompt,
    int maxTokens = 60,
  }) async {
    try {
      // Check premium status
      if (!await _premiumService.isPremium()) return null;

      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty || apiKey == 'your_openai_api_key_here') {
        return null;
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemInstruction},
            {'role': 'user', 'content': userPrompt}
          ],
          'temperature': 0.8,
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        return content.trim().replaceAll('"', '').replaceAll('\n', ' ');
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error generating context-aware message: $e');
      return null;
    }
  }

  /// Fallback motivational message when GPT is unavailable
  String _fallbackMotivationalMessage({
    required String goalName,
    required String taskDescription,
    String? motivationAnchor,
    String? personaPrompt,
  }) {
    final parts = <String>[];
    
    if (motivationAnchor != null) {
      parts.add(motivationAnchor);
    } else {
      parts.add('This task moves you closer to "$goalName"');
    }
    
    parts.add('Let\'s keep the momentum going.');
    
    return parts.join('. ') + ' 💪';
  }

  /// Fallback question when GPT is unavailable
  GptResponse _fallbackQuestion(List<String> missingFields) {
    if (missingFields.isEmpty) {
      return GptResponse(
        question: 'Is there anything else you\'d like to add to this reminder?',
      );
    }

    final nextField = missingFields.first;
    String question;

    switch (nextField) {
      case 'text':
        question = 'What would you like to be reminded about?';
        break;
      case 'time':
        question = 'When should I remind you? Please specify a time or date.';
        break;
      case 'location':
        question = 'Which location should I use? Home, work, or another place?';
        break;
      case 'locationTrigger':
        question =
            'Should I remind you when you arrive, when you leave, or both?';
        break;
      case 'recurrence':
        question =
            'How often should this repeat? For example, "every day", "every week", "every 2 hours".';
        break;
      case 'repeatInterval':
        question =
            'What interval? For example, "every 2 hours" means interval is 2.';
        break;
      case 'repeatUnit':
        question = 'What unit? Minutes, hours, days, weeks, or months?';
        break;
      case 'intent':
        question =
            'How should I remind you? At a specific time, when you reach a location, or based on activity?';
        break;
      default:
        question = 'I need a bit more information. Could you clarify?';
    }

    return GptResponse(
      question: question,
      field: nextField,
    );
  }
  /// Continue a conversation (Session-based) for Hands-Free mode
  Future<ConversationResponse?> continueConversation(List<Map<String, String>> history) async {
    try {
      // Check premium status
      final premiumService = PremiumService();
      final isPremium = await premiumService.isPremium();
      
      if (!isPremium) {
        // Simple fallback logic for non-premium
        return _fallbackConversationLogic(history);
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return _fallbackConversationLogic(history);
      }

      // Convert history to OpenAI format
      final messages = [
        {
          'role': 'system',
          'content': _buildConversationalSystemPrompt(),
        },
        ...history.map((m) => {
          'role': m['role'] == 'user' ? 'user' : 'assistant', 
          'content': m['content'],
        }),
      ];

      // STRONG STEER: Check if last message is a "stop" phrase
      if (history.isNotEmpty && history.last['role'] == 'user') {
        final lastMsg = history.last['content']!.toLowerCase().trim();
        final stopPhrases = ['no', 'nope', 'nothing else', 'that\'s it', 'done', 'nothing', 'stop', 'finished', 'no more'];
        final isStop = stopPhrases.any((phrase) => lastMsg.contains(phrase));
        
        if (isStop) {
           debugPrint('🛑 User signaled stop. Forcing plan generation.');
           messages.add({
             'role': 'system',
             'content': 'USER INSTRUCTION: I am done providing information. STOP asking questions. GENERATE the valid JSON Action Plan NOW. Use rational defaults (deadline: 30 days, effort: 2 hours/day) for missing fields.',
           });
        }
      }

      debugPrint('🚀 Sending request to GPT...');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1000, 
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        debugPrint('📥 GPT Raw Response: $content');
        return _parseGptResponse(content);
      } else {
        debugPrint('❌ GPT Error: ${response.statusCode} ${response.body}');
        return _fallbackConversationLogic(history);
      }
    } catch (e) {
      debugPrint('GPT Conversation Error: $e');
      return _fallbackConversationLogic(history);
    }
  }

  String _buildConversationalSystemPrompt() {
    return '''
You are Lumio, a proactive execution assistant. Your goal is to Identify User Intent and Help them Execute.

INTENTS:
1. **CREATE_RELINDER/TASK**: User wants to do something simple (e.g., "Call Mom", "Buy milk").
   - Action: Create a task immediately.
   - Required: Title. (Date/Time defaults to Today/Now if missing).
   
2. **CREATE_GOAL**: User has a big objective (e.g., "Run a marathon", "Start a business", "I want to create a goal").
   - Action: Create a detailed plan.
   - Required: Goal Name, Deadline, Effort (Hours/Week).
   - **CRITICAL**: If User says "I want to create a goal" but doesn't say WHAT, ASK: "What is the goal you want to achieve?"
   - If User provides Goal Name but no Deadline, ASK: "When do you want to achieve [Goal Name] by?"

3. **PLAN_DAY**: User wants to organize their schedule (e.g., "Plan my day", "Here is my dump...").
   - Action: Generate a Daily Schedule.
   - Required: List of tasks (user input).

STATE MACHINE RULES:
- **NEVER** reply with generic phrases like "Okay, I've noted that down. Anything else?" for Goal/Task completion.
- If info is missing (e.g. Goal Title), response type MUST be "question".
- If info is sufficient, response type MUST be "action".

OUTPUT FORMAT (JSON ONLY):

Type 1: QUESTION (Need more info)
{
  "type": "question",
  "text": "What is the specific goal you want to work on?",
  "intent": "CREATE_GOAL" // Optional context
}

Type 2: ACTION (Ready to execute)
{
  "type": "action",
  "text": "I've created your goal 'Run Marathon'. Let's do this!",
  "action_type": "CREATE_GOAL", 
  "action_data": {
     "goal": "Run Marathon",
     "deadline": "2025-06-01...",
     "tasks": [...]
  }
}

Type 3: TASK_ACTION (Simple Task)
{
  "type": "action",
  "text": "Added 'Buy Milk' to your list.",
  "action_type": "CREATE_TASK",
  "action_data": {
     "title": "Buy Milk"
  }
}

Keep questions SHORT, DIRECT, and CONVERSATIONAL (spoken by TTS).
''';
  }

  ConversationResponse _parseGptResponse(String content) {
    try {
      String jsonStr = content.trim();
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
         jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final data = jsonDecode(jsonStr);
      return ConversationResponse(
        responseText: data['text'],
        isAction: data['type'] == 'action',
        actionType: data['action_type'],
        actionData: data['action_data'],
      );
    } catch (e) {
      // If parsing fails, treat entire content as a question
      return ConversationResponse(
        responseText: content,
        isAction: false,
      );
    }
  }

  Future<List<Map<String, dynamic>>> breakDownTask(String taskTitle) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      // Fallback
      return [
        {'title': 'Step 1 for $taskTitle', 'description': 'First sub-step'},
        {'title': 'Step 2 for $taskTitle', 'description': 'Second sub-step'},
      ];
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a task decomposition expert. Break down the user\'s task into 3-5 actionable subtasks. Return JSON: {"subtasks": [{"title": "...", "description": "..."}]}'
            },
            {
              'role': 'user',
              'content': 'Break down this task: "$taskTitle"'
            }
          ],
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final content = jsonDecode(response.body)['choices'][0]['message']['content'];
        String jsonStr = content.trim();
        if (jsonStr.contains('```json')) {
             jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
             jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        final data = jsonDecode(jsonStr);
        return List<Map<String, dynamic>>.from(data['subtasks']);
      }
    } catch (e) {
      debugPrint("GPT Subtask Error: $e");
    }
    
    // Fallback if error
    return [
       {'title': 'Research $taskTitle', 'description': 'Look into details'},
       {'title': 'Plan $taskTitle', 'description': 'Outline steps'},
    ];
  }

  ConversationResponse _fallbackConversationLogic(List<Map<String, String>> history) {
    String lastUserMsg = '';
    if (history.isNotEmpty && history.last['role'] == 'user') {
      lastUserMsg = history.last['content']?.toLowerCase().trim() ?? '';
    }
    
    // Check for stop signals
    final stopPhrases = ['no', 'nope', 'nothing else', 'that\'s it', 'done', 'nothing', 'stop', 'finished', 'no more'];
    final isStop = stopPhrases.any((phrase) => lastUserMsg.contains(phrase));

    if (isStop) {
       // ... (Keep existing Logic for "Creating Plan" if stop is said) ...
       String goalName = "New Goal";
       if (history.isNotEmpty) {
           final firstUserMsg = history.firstWhere((m) => m['role'] == 'user', orElse: () => {'content': 'New Goal'});
           goalName = firstUserMsg['content'] ?? "New Goal";
           if (goalName.length > 50) goalName = goalName.substring(0, 47) + "...";
       }

       return ConversationResponse(
        responseText: "Understood. Creating your plan now.",
        isAction: true,
        actionType: 'CREATE_GOAL',
        actionData: {
          'goal': goalName,
          'deadline': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'tasks': [
             {'title': 'Review Goal', 'description': 'Review $goalName details', 'priority': 'high'},
             {'title': 'First Step', 'description': 'Identify the immediate next step', 'priority': 'medium'},
          ]
        },
      );
    }
    
    // 1. Intelligent Fallback: Goal Creation Intent
    // If user says "create a goal" or "new goal" but hasn't given details
    if (lastUserMsg.contains('goal') && (lastUserMsg.contains('create') || lastUserMsg.contains('new') || lastUserMsg.contains('want to'))) {
        return ConversationResponse(
            responseText: "What is the specific goal you want to achieve?",
            isAction: false,
        );
    }

    // 2. Intelligent Fallback: Task Creation Intent (Simple Regex)
    // Matches "Remind me to [X]", "Buy [X]", "Call [X]"
    final taskRegex = RegExp(r'^(remind me to|buy|call|email|text|check) (.+)', caseSensitive: false);
    final match = taskRegex.firstMatch(lastUserMsg);
    if (match != null) {
        final taskTitle = match.group(2)?.trim() ?? lastUserMsg; // content after verb
        // Capitalize
        final formattedTitle = taskTitle.length > 0 
            ? '${taskTitle[0].toUpperCase()}${taskTitle.substring(1)}'
            : taskTitle;

        final verb = match.group(1)?.toLowerCase();

        return ConversationResponse(
            responseText: "I've added '$formattedTitle' to your tasks.",
            isAction: true,
            actionType: 'CREATE_TASK',
            actionData: {
                'title': '$verb $formattedTitle', // e.g. "call Mom"
            }
        );
    }
    
    // 4. Context-Aware Fallback (Answering a Question)
    // Check if the PREVIOUS message (Assistant) was asking for a goal
    if (history.length >= 2) {
        final lastAssistantMsg = history[history.length - 2]['content']?.toLowerCase() ?? '';
        if (history[history.length - 2]['role'] == 'assistant') {
             if (lastAssistantMsg.contains('specific goal') || lastAssistantMsg.contains('what is the goal')) {
                  // User is answering the goal question!
                  // Treat current message as the Goal Title
                  final goalName = lastUserMsg.length > 50 
                      ? lastUserMsg.substring(0, 47) + "..." 
                      : lastUserMsg;
                  
                  // Capitalize
                  final formattedGoal = goalName.length > 0 
                      ? '${goalName[0].toUpperCase()}${goalName.substring(1)}'
                      : goalName;

                  return ConversationResponse(
                      responseText: "I've drafted a plan for '$formattedGoal'. Check it out!",
                      isAction: true,
                      actionType: 'CREATE_GOAL',
                      actionData: {
                          'goal': formattedGoal,
                          'deadline': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
                          'tasks': [
                              {'title': 'Research $formattedGoal', 'description': 'Initial research phase', 'priority': 'high'},
                              {'title': 'Draft Plan', 'description': 'Outline key milestones', 'priority': 'medium'},
                              {'title': 'Execute First Step', 'description': 'Start working on the first task', 'priority': 'medium'},
                          ]
                      }
                  );
             }
        }
    }

    // 5. Generic Fallback
    if (history.length < 2) {
      return ConversationResponse(
        responseText: "Got it. When would you like to finish this by?",
        isAction: false,
      );
    } else {
      return ConversationResponse(
        responseText: "I've noted that. Anything else?",
        isAction: false,
      );
    }
  }
  /// Generate a daily schedule from unstructured text (Day Architect)
  Future<List<Map<String, dynamic>>> generateDailySchedule(String rawText) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return _fallbackDailySchedule(rawText);
    }

    try {
      final prompt = '''
You are a Daily Planning Architect. Convert the user's unstructured brain dump into a structured daily schedule.

User Input: "$rawText"
Current Time: ${DateTime.now().toLocal()}

CRITICAL RULES:
1. Extract every distinct task mentioned.
2. Estimate duration in MINUTES for each task (be realistic).
3. Assign a priority (high/medium/low).
4. If the user mentions specific times (e.g., "call at 2pm"), use them.
5. If no times mentioned, suggest a logical order.

6. Extract specific time to 'specificTime' field (HH:MM 24h format). Handle "3.30pm" as "15:30", "3:30" as "03:30". Normalize all separators to colon.

Return ONLY a JSON Array:
[
  {
    "title": "Task Name",
    "description": "Brief details",
    "estimatedMinutes": 60,
    "priority": "high",
    "suggestedTime": "morning", // or afternoon, evening
    "specificTime": "14:30" // Optional: HH:MM 24h formt if user specified time
  }
]
''';

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a scheduling assistant. Return valid JSON arrays only.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'temperature': 0.5,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final content = jsonDecode(response.body)['choices'][0]['message']['content'];
        String jsonStr = content.trim();
        if (jsonStr.contains('```json')) {
            jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
        } else if (jsonStr.contains('```')) {
            jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
        }
        
        final List<dynamic> list = jsonDecode(jsonStr);
        return List<Map<String, dynamic>>.from(list);
      }
    } catch (e) {
      debugPrint("GPT Daily Schedule Error: $e");
    }

    return _fallbackDailySchedule(rawText);
  }

  List<Map<String, dynamic>> _fallbackDailySchedule(String rawText) {
    // Simple fallback: split by commas or periods if possible, else return one big task
    return [
      {
        'title': 'Process: $rawText',
        'description': 'Manual breakdown required',
        'estimatedMinutes': 60,
        'priority': 'medium',
        'suggestedTime': 'any'
      }
    ];
  }
}

