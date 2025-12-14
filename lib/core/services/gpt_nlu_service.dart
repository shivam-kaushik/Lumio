import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../data/models/reminder.dart';
import 'premium_service.dart';

/// GPT-powered Natural Language Understanding service for reminder parsing
class GptNluService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-3.5-turbo'; // Fast and cost-effective

  /// Parse reminder text using GPT API with structured output
  /// Returns null if user is not premium (will use fallback parser)
  static Future<ParsedReminderData?> parseReminderText(String text) async {
    try {
      // Check premium status first
      final premiumService = PremiumService();
      final isPremium = await premiumService.isPremium();
      
      if (!isPremium) {
        debugPrint('⚠️ GPT parsing requires premium subscription, using fallback parser');
        return null; // Return null to indicate fallback should be used
      }

      final apiKey = dotenv.env['OPENAI_API_KEY'];

      if (apiKey == null ||
          apiKey.isEmpty ||
          apiKey == 'your_openai_api_key_here') {
        debugPrint(
            '⚠️ OpenAI API key not configured, falling back to basic parser',);
        return null; // Return null to use fallback parser
      }

      final prompt = _buildPrompt(text);

      final response = await http
          .post(
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
                  'content':
                      'You are a reminder parsing assistant. Extract structured data from natural language reminder text. Always respond with valid JSON only, no additional text.',
                },
                {
                  'role': 'user',
                  'content': prompt,
                }
              ],
              'temperature': 0.3, // Low temperature for consistent parsing
              'max_tokens': 500,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;

        // Parse the JSON response
        final parsed = jsonDecode(content.trim());
        return ParsedReminderData.fromJson(parsed);
      } else {
        debugPrint(
            '❌ GPT API error: ${response.statusCode} - ${response.body}',);
        return _fallbackParser(text);
      }
    } catch (e) {
      debugPrint('❌ GPT parsing failed: $e');
      return _fallbackParser(text);
    }
  }

  /// Build the GPT prompt with examples and instructions
  static String _buildPrompt(String text) {
    final now = DateTime.now();
    final today = DateFormat('EEEE, MMMM d, yyyy').format(now);

    return '''
Parse this reminder text and extract all relevant information. Current date/time: $today ${DateFormat('h:mm a').format(now)}.

Reminder text: "$text"

Extract and return ONLY a JSON object with these fields (use null for missing data):

{
  "title": "cleaned reminder title without time/priority/category/location prefixes",
  "dateTime": "ISO 8601 date-time string if specific time mentioned, else null",
  "priority": "Low|Medium|High|Critical or null",
  "category": "Health|Work|Study|Personal|Shopping|Family|Other or null",
  "isRecurring": true/false,
  "repeatInterval": number or null (e.g., 2 for "every 2 hours"),
  "repeatUnit": "minutes|hours|days|weeks|months" or null,
  "repeatEndDate": "ISO 8601 date string or null",
  "repeatOnDays": [1-7 for Mon-Sun] or null (e.g., [1,2,3,4,5] for weekdays),
  "timeRangeStart": "HH:mm" or null (e.g., "09:00"),
  "timeRangeEnd": "HH:mm" or null (e.g., "18:00"),
  "preferredTimeOfDay": "Morning|Afternoon|Evening|Night|LateNight" or null,
  "locationContext": "home|work|gym" or null (if location mentioned),
  "onLeave": true/false (true if "leaving", "when I leave", "before leaving"),
  "onArrive": true/false (true if "arriving", "when I arrive", "when I get to")
}

Examples:

Input: "High priority: Take medicine every 8 hours between 9 AM and 6 PM on weekdays until December 31"
Output: {"title":"Take medicine","dateTime":null,"priority":"High","category":"Health","isRecurring":true,"repeatInterval":8,"repeatUnit":"hours","repeatEndDate":"${now.year}-12-31","repeatOnDays":[1,2,3,4,5],"timeRangeStart":"09:00","timeRangeEnd":"18:00","preferredTimeOfDay":null}

Input: "Urgent: Call doctor tomorrow at 3 PM"
Output: {"title":"Call doctor","dateTime":"${_formatTomorrow(now, 15, 0)}","priority":"Critical","category":"Health","isRecurring":false,"repeatInterval":null,"repeatUnit":null,"repeatEndDate":null,"repeatOnDays":null,"timeRangeStart":null,"timeRangeEnd":null,"preferredTimeOfDay":null}

Input: "Remind me to drink water every 2 hours during work hours"
Output: {"title":"Drink water","dateTime":null,"priority":"Medium","category":"Health","isRecurring":true,"repeatInterval":2,"repeatUnit":"hours","repeatEndDate":null,"repeatOnDays":[1,2,3,4,5],"timeRangeStart":"09:00","timeRangeEnd":"18:00","preferredTimeOfDay":null}

Input: "Team meeting every Monday at 10 AM"
Output: {"title":"Team meeting","dateTime":"${_formatNextMonday(now, 10, 0)}","priority":"Medium","category":"Work","isRecurring":true,"repeatInterval":1,"repeatUnit":"weeks","repeatEndDate":null,"repeatOnDays":[1],"timeRangeStart":null,"timeRangeEnd":null,"preferredTimeOfDay":"Morning","locationContext":null,"onLeave":false,"onArrive":false}

Input: "Remind me to take my keys when leaving home"
Output: {"title":"Take my keys","dateTime":null,"priority":"Medium","category":"Personal","isRecurring":false,"repeatInterval":null,"repeatUnit":null,"repeatEndDate":null,"repeatOnDays":null,"timeRangeStart":null,"timeRangeEnd":null,"preferredTimeOfDay":null,"locationContext":"home","onLeave":true,"onArrive":false}

Input: "Remind me to water plants when I get home"
Output: {"title":"Water plants","dateTime":null,"priority":"Medium","category":"Personal","isRecurring":false,"repeatInterval":null,"repeatUnit":null,"repeatEndDate":null,"repeatOnDays":null,"timeRangeStart":null,"timeRangeEnd":null,"preferredTimeOfDay":null,"locationContext":"home","onLeave":false,"onArrive":true}

Priority keywords: urgent/critical/asap/important → High/Critical, low priority → Low, else Medium
Category keywords: medicine/health/doctor/exercise → Health, meeting/work/project → Work, study/learn/exam → Study, buy/shop/grocery → Shopping, family/mom/dad/kids → Family
Time keywords: morning → Morning (6-12), afternoon → Afternoon (12-17), evening → Evening (17-21), night → Night (21-24), late night → LateNight (0-6)
Repeat keywords: every X minutes/hours/days/weeks/months, daily/weekly/monthly, weekdays → repeatOnDays [1-5]
Location keywords: home/house → home, work/office → work, gym/fitness → gym
Context keywords: leaving/when I leave/before leaving → onLeave=true, arriving/when I arrive/when I get to → onArrive=true

Return ONLY the JSON object, no other text.
''';
  }

  /// Format tomorrow's date at specific time
  static String _formatTomorrow(DateTime now, int hour, int minute) {
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute)
        .toIso8601String();
  }

  /// Format next Monday at specific time
  static String _formatNextMonday(DateTime now, int hour, int minute) {
    int daysUntilMonday = (DateTime.monday - now.weekday) % 7;
    if (daysUntilMonday == 0) {
      daysUntilMonday = 7; // Next week if today is Monday
    }
    final nextMonday = now.add(Duration(days: daysUntilMonday));
    return DateTime(
            nextMonday.year, nextMonday.month, nextMonday.day, hour, minute,)
        .toIso8601String();
  }

  /// Fallback parser using basic regex patterns
  static ParsedReminderData _fallbackParser(String text) {
    debugPrint('📝 Using fallback regex parser');

    // Basic priority detection
    ReminderPriority? priority;
    if (RegExp(r'\b(urgent|critical|asap|emergency)\b', caseSensitive: false)
        .hasMatch(text)) {
      priority = ReminderPriority.critical;
    } else if (RegExp(r'\b(important|high priority)\b', caseSensitive: false)
        .hasMatch(text)) {
      priority = ReminderPriority.high;
    } else if (RegExp(r'\blow priority\b', caseSensitive: false)
        .hasMatch(text)) {
      priority = ReminderPriority.low;
    }

    // Basic category detection
    ReminderCategory? category;
    if (RegExp(r'\b(medicine|health|doctor|exercise|pill|medication)\b',
            caseSensitive: false,)
        .hasMatch(text)) {
      category = ReminderCategory.health;
    } else if (RegExp(r'\b(meeting|work|project|office|deadline)\b',
            caseSensitive: false,)
        .hasMatch(text)) {
      category = ReminderCategory.work;
    } else if (RegExp(r'\b(study|learn|exam|homework|class)\b',
            caseSensitive: false,)
        .hasMatch(text)) {
      category = ReminderCategory.study;
    } else if (RegExp(r'\b(buy|shop|grocery|purchase)\b', caseSensitive: false)
        .hasMatch(text)) {
      category = ReminderCategory.shopping;
    } else if (RegExp(r'\b(family|mom|dad|kids|parents)\b',
            caseSensitive: false,)
        .hasMatch(text)) {
      category = ReminderCategory.family;
    }

    // Check if user wants to start immediately
    bool startImmediately = false;
    final immediatePhrases = [
      r'\b(starting\s+now|start\s+now)\b',
      r'\b(right\s+away|rightaway)\b',
      r'\b(immediately|asap)\b',
      r'\b(from\s+now|begin\s+now)\b',
    ];
    
    for (var pattern in immediatePhrases) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(text)) {
        startImmediately = true;
        debugPrint('   ✅ Detected "starting now" in fallback parser');
        break;
      }
    }

    // Basic recurring detection
    bool isRecurring = false;
    int? repeatInterval;
    String? repeatUnit;
    DateTime? dateTime;

    final recurringMatch = RegExp(r'every (\d+) (minute|hour|day|week|month)s?',
            caseSensitive: false,)
        .firstMatch(text);
    if (recurringMatch != null) {
      isRecurring = true;
      repeatInterval = int.tryParse(recurringMatch.group(1) ?? '1');
      repeatUnit = recurringMatch.group(2)?.toLowerCase();
      if (repeatUnit != null && !repeatUnit.endsWith('s')) {
        repeatUnit = '${repeatUnit}s';
      }
      
      // If "starting now" is detected and it's recurring, set dateTime to 10 seconds from now
      if (startImmediately) {
        dateTime = DateTime.now().add(const Duration(seconds: 10));
        debugPrint('   ✅ Setting dateTime to 10 seconds from now for recurring reminder');
      }
    }

    // Clean title (remove priority/category markers and recurrence phrases)
    String title = text
        .replaceAll(
            RegExp(r'^(urgent|critical|high priority|low priority):\s*',
                caseSensitive: false,),
            '',)
        .replaceAll(
            RegExp(r'\bevery \d+ (minute|hour|day|week|month)s?\b',
                caseSensitive: false,),
            '',)
        .replaceAll(
            RegExp(r'\b(starting\s+now|start\s+now|right\s+away|immediately|from\s+now)\b',
                caseSensitive: false,),
            '',)
        .trim();

    return ParsedReminderData(
      title: title.isEmpty ? text : title,
      dateTime: dateTime,
      priority: priority,
      category: category,
      isRecurring: isRecurring,
      repeatInterval: repeatInterval,
      repeatUnit: repeatUnit,
    );
  }
}

/// Parsed reminder data from NLU
class ParsedReminderData {
  final String title;
  final DateTime? dateTime;
  final ReminderPriority? priority;
  final ReminderCategory? category;
  final bool isRecurring;
  final int? repeatInterval;
  final String? repeatUnit;
  final DateTime? repeatEndDate;
  final List<int>? repeatOnDays; // 1=Mon, 7=Sun
  final String? timeRangeStart; // HH:mm
  final String? timeRangeEnd; // HH:mm
  final TimeOfDay? preferredTimeOfDay;
  final String? locationContext; // home, work, gym
  final bool onLeave; // Trigger when leaving location
  final bool onArrive; // Trigger when arriving at location

  ParsedReminderData({
    required this.title,
    this.dateTime,
    this.priority,
    this.category,
    this.isRecurring = false,
    this.repeatInterval,
    this.repeatUnit,
    this.repeatEndDate,
    this.repeatOnDays,
    this.timeRangeStart,
    this.timeRangeEnd,
    this.preferredTimeOfDay,
    this.locationContext,
    this.onLeave = false,
    this.onArrive = false,
  });

  factory ParsedReminderData.fromJson(Map<String, dynamic> json) {
    return ParsedReminderData(
      title: json['title'] as String,
      dateTime:
          json['dateTime'] != null ? DateTime.parse(json['dateTime']) : null,
      priority: json['priority'] != null
          ? ReminderPriority.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  (json['priority'] as String).toLowerCase(),
              orElse: () => ReminderPriority.medium,
            )
          : null,
      category: json['category'] != null
          ? ReminderCategory.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  (json['category'] as String).toLowerCase(),
              orElse: () => ReminderCategory.other,
            )
          : null,
      isRecurring: json['isRecurring'] as bool? ?? false,
      repeatInterval: json['repeatInterval'] as int?,
      repeatUnit: json['repeatUnit'] as String?,
      repeatEndDate: json['repeatEndDate'] != null
          ? DateTime.parse(json['repeatEndDate'])
          : null,
      repeatOnDays: (json['repeatOnDays'] as List?)?.cast<int>(),
      timeRangeStart: json['timeRangeStart'] as String?,
      timeRangeEnd: json['timeRangeEnd'] as String?,
      preferredTimeOfDay: json['preferredTimeOfDay'] != null
          ? TimeOfDay.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  (json['preferredTimeOfDay'] as String).toLowerCase(),
              orElse: () => TimeOfDay.morning,
            )
          : null,
      locationContext: json['locationContext'] as String?,
      onLeave: json['onLeave'] as bool? ?? false,
      onArrive: json['onArrive'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'ParsedReminderData(title: $title, dateTime: $dateTime, priority: $priority, '
        'category: $category, isRecurring: $isRecurring, repeatInterval: $repeatInterval, '
        'repeatUnit: $repeatUnit, repeatEndDate: $repeatEndDate, repeatOnDays: $repeatOnDays, '
        'timeRange: $timeRangeStart-$timeRangeEnd, preferredTimeOfDay: $preferredTimeOfDay, '
        'locationContext: $locationContext, onLeave: $onLeave, onArrive: $onArrive)';
  }
}
