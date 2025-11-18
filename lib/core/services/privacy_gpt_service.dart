import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/conversation_models.dart';

/// Privacy-preserving GPT service
/// Anonymizes data before sending to GPT API
class PrivacyGptService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-3.5-turbo'; // Fast and cost-effective

  /// Ask clarifying question using GPT with privacy protection
  Future<GptResponse> askClarifyingQuestion({
    required Map<String, dynamic> localExtracted,
    required List<String> missingFields,
    required String conversationContext,
  }) async {
    try {
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
  Future<Map<String, dynamic>?> generateDetailedRoadmap(
    String goalDescription, {
    required DateTime targetDeadline,
    required double hoursPerDay,
  }) async {
    try {
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
You are Lumio, a private, hands-free execution assistant for solopreneurs. Your purpose is to help entrepreneurs turn spoken intentions into structured business roadmaps.

Goal: $goalDescription
Target Deadline: ${targetDeadline.toString().split(' ')[0]} (${daysUntilDeadline} days from now)
Available Hours Per Day: $hoursPerDay hours
Total Available Hours: ~${totalAvailableHours.toStringAsFixed(0)} hours

Create a COMPLETE business execution plan with:

1. **Task Breakdown** (5-12 tasks):
   - Each task must have:
     - title: Short, actionable name
     - description: What to do (specific and clear)
     - estimatedHours: Realistic hours needed (consider complexity)
     - priority: "high", "medium", or "low"
     - dependencies: Array of task titles this depends on (empty if none)
     - isMilestone: true if this is a major checkpoint
     - motivationAnchor: Why this task matters for the goal (1 sentence)
     - estimatedFrequency: "daily", "weekly", "monthly", or "one-time"
     - suggestedTime: "morning", "afternoon", "evening", or "any"
     - suggestedLocation: "home", "office", "coffee_shop", or "any"

3. **Weekly Goals** (3-5 weekly milestones):
   - What should be accomplished each week
   - Realistic progress markers

4. **Risk Alerts** (2-4 potential issues):
   - What could derail this plan
   - How to mitigate risks

5. **Total Estimated Hours**: Sum of all subtask hours

CRITICAL RULES:
- Total estimated hours MUST fit within available hours (${totalAvailableHours.toStringAsFixed(0)} hours)
- If it doesn't fit, prioritize and reduce scope realistically
- Distribute tasks evenly across the timeline
- Include buffer time (20% of total)
- Make tasks specific and actionable
- Consider dependencies (some tasks must come before others)
- Include milestone checkpoints
- Each task should have a clear "why" (motivationAnchor)

Return ONLY valid JSON:
{
  "goal": "goal name",
  "totalEstimatedHours": 120,
  "tasks": [
    {
      "title": "task name",
      "description": "what to do",
      "estimatedHours": 8.0,
      "priority": "high",
      "dependencies": [],
      "isMilestone": false,
      "motivationAnchor": "This moves you closer to launching because...",
      "estimatedFrequency": "weekly",
      "suggestedTime": "morning",
      "suggestedLocation": "office"
    }
  ],
  "weeklyGoals": [
    "Week 1: Complete market research and validate idea",
    "Week 2: Design core features and create wireframes"
  ],
  "riskAlerts": [
    "Risk: Scope creep could delay launch. Mitigation: Stick to MVP features only.",
    "Risk: Underestimating development time. Mitigation: Add 20% buffer to estimates."
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
          'max_tokens': 2000,
        }),
      ).timeout(const Duration(seconds: 20));

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
          'suggestedLocation': 'any',
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
          'suggestedLocation': 'any',
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
          'suggestedLocation': 'any',
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
- suggestedLocation: "home", "office", "coffee_shop", or "any"
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
      "suggestedLocation": "office",
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
          'suggestedLocation': 'any',
          'priority': 'high',
        },
        {
          'title': 'Take action',
          'description': 'Work on tasks related to this goal',
          'estimatedFrequency': 'daily',
          'suggestedTime': 'any',
          'suggestedLocation': 'any',
          'priority': 'high',
        },
        {
          'title': 'Review progress',
          'description': 'Review and adjust your approach',
          'estimatedFrequency': 'weekly',
          'suggestedTime': 'evening',
          'suggestedLocation': 'any',
          'priority': 'medium',
        },
      ],
    };
  }

  /// Generate motivational message for reminder (Solopreneur Execution Assistant)
  Future<String?> generateMotivationalMessage({
    required String goalName,
    required String taskDescription,
    String? skillName, // Deprecated, kept for compatibility
    int streakCount = 0, // Deprecated, kept for compatibility
    int totalReps = 0, // Deprecated, kept for compatibility
    String? motivationAnchor,
  }) async {
    try {
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
              'content': 'You are a motivational assistant for entrepreneurs. Generate short, encouraging messages that help users stay motivated. Be empathetic and practical.',
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
        );
      }
    } catch (e) {
      debugPrint('❌ Error generating motivational message: $e');
      return _fallbackMotivationalMessage(
        goalName: goalName,
        taskDescription: taskDescription,
        motivationAnchor: motivationAnchor,
      );
    }
  }

  /// Fallback motivational message when GPT is unavailable
  String _fallbackMotivationalMessage({
    required String goalName,
    required String taskDescription,
    String? motivationAnchor,
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
}
