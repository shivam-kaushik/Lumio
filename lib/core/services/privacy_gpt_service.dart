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
    return '''You are Awarely, a privacy-focused reminder assistant.

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
