import 'package:flutter/foundation.dart';
import '../models/conversation_models.dart';
import '../constants/app_constants.dart';
import '../utils/date_time_utils.dart';
import '../../data/models/reminder.dart';

/// Local NLU Preprocessor - Privacy-first local parsing
/// Handles 80%+ of cases locally before sending to GPT
class LocalNluPreprocessor {
  /// Preprocess user input and extract structured data locally
  Future<LocalParseResult> preprocess(String userInput) async {
    debugPrint('🔍 LocalNluPreprocessor: Processing "$userInput"');

    final lowerText = userInput.toLowerCase();
    final extracted = <String, dynamic>{};

    // IMPORTANT: Extract time BEFORE extracting text (text extraction might remove time phrases)
    // 1. Extract time first (before text cleaning)
    final time = _extractTime(lowerText);
    
    // 2. Extract reminder text (required) - but preserve original for time extraction
    final text = _extractReminderText(userInput);
    extracted['text'] = text;

    // 3. Detect intent type
    final intent = _detectIntent(lowerText);
    extracted['intent'] = intent?.name;
    debugPrint('   Intent detected: $intent');

    // 4. Extract date first (if mentioned)
    DateTime? targetDate;
    final now = DateTime.now();
    
    if (lowerText.contains('today') || lowerText.contains('now')) {
      targetDate = DateTime(now.year, now.month, now.day);
    } else if (lowerText.contains('tomorrow')) {
      targetDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    } else {
      // Try to extract date from text like "Nov 3", "November 3", "11/3", etc.
      final dateMatch = RegExp(r'(nov|dec|jan|feb|mar|apr|may|jun|jul|aug|sep|oct)\s*(\d{1,2})', caseSensitive: false).firstMatch(lowerText);
      if (dateMatch != null) {
        final monthStr = dateMatch.group(1)!.toLowerCase();
        final dayStr = dateMatch.group(2);
        if (dayStr != null) {
          final day = int.tryParse(dayStr);
          if (day != null) {
            final monthMap = {
              'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
              'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
            };
            final month = monthMap[monthStr];
            if (month != null) {
              final year = now.year;
              // If date is in the past this year, assume next year
              final candidateDate = DateTime(year, month, day);
              targetDate = candidateDate.isBefore(now) ? DateTime(year + 1, month, day) : candidateDate;
            }
          }
        }
      }
    }
    
    // 5. Use the time we extracted earlier (before text cleaning)
    if (time != null) {
      DateTime timeAt;
      
      if (targetDate != null) {
        // Use extracted/mentioned date
        timeAt = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          time.hour,
          time.minute,
        );
      } else {
        // No date mentioned - assume today, but if time has passed, assume tomorrow
        timeAt = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
        if (timeAt.isBefore(now)) {
          timeAt = timeAt.add(const Duration(days: 1));
        }
      }
      
      extracted['time'] = timeAt.toIso8601String();
      extracted['timeAt'] = timeAt.toIso8601String();
      debugPrint('   ✅ Time extracted: $timeAt (from "$time"${targetDate != null ? ", date: $targetDate" : ""})');
    } else if (targetDate != null) {
      // Date mentioned but no time - don't set timeAt here, let merge logic preserve existing time
      // If there's already a time in the draft, we'll use that date with existing time
      // Otherwise, we'll need to ask for time
      debugPrint('   📅 Date extracted: $targetDate (no time provided - will preserve existing time or ask)');
      // Don't set timeAt - let the conversation flow handle it
    }

    // 4. Extract location - but check for explicit "no location" first
    if (lowerText.contains('no location') || 
        lowerText.contains('no place') ||
        lowerText.contains('not location') ||
        (lowerText.contains('specific time') && !lowerText.contains('location'))) {
      // User explicitly said no location - mark intent as time-based
      extracted['intent'] = IntentType.timeBased.name;
      extracted['geofenceId'] = null; // Explicitly clear location
    } else {
      final locationInfo = _extractLocation(lowerText);
      if (locationInfo['location'] != null) {
        extracted['location'] = locationInfo['location'];
        extracted['geofenceId'] = locationInfo['location'];
      }
      if (locationInfo['leaving'] == true) {
        extracted['onLeaveContext'] = true;
      }
      if (locationInfo['arriving'] == true) {
        extracted['onArriveContext'] = true;
      }
    }

    // 7. Extract recurrence
    final recurrenceInfo = _extractRecurrence(lowerText);
    if (recurrenceInfo['interval'] != null) {
      extracted['repeatInterval'] = recurrenceInfo['interval'];
      extracted['repeatUnit'] = recurrenceInfo['unit'];
    }

    // 8. Extract priority
    final priority = _extractPriority(userInput);
    extracted['priority'] = priority.name;

    // 9. Extract category (basic)
    final category = _extractCategory(lowerText);
    extracted['category'] = category?.name;

    // 10. Extract weather condition
    if (_hasWeatherIntent(lowerText)) {
      extracted['weatherCondition'] = 'rain';
      extracted['intent'] = IntentType.weatherBased.name;
    }

    // 11. Extract activity type
    final activity = _extractActivity(lowerText);
    if (activity != null) {
      extracted['activityType'] = activity;
      extracted['intent'] = IntentType.activityBased.name;
    }

    // 12. Calculate confidence
    final confidence = _calculateConfidence(extracted, intent);

    // 13. Identify missing required fields
    final missingFields = _identifyMissingFields(extracted, intent);

    // 14. Determine if GPT needed
    final needsGpt = confidence < 0.8 ||
        _hasAmbiguity(extracted) ||
        missingFields.contains('intent');

    debugPrint('   Confidence: $confidence');
    debugPrint('   Missing fields: $missingFields');
    debugPrint('   Needs GPT: $needsGpt');

    return LocalParseResult(
      extracted: extracted,
      confidence: confidence,
      needsGpt: needsGpt,
      missingFields: missingFields,
      intent: intent,
    );
  }

  /// Extract reminder text (clean version)
  /// IMPORTANT: Don't extract time/date phrases as reminder text
  String _extractReminderText(String text) {
    // Remove common prefixes
    String cleaned = text;
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*remind\s+me\s+to\s+', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*i\s+need\s+to\s+', caseSensitive: false),
      '',
    );
    
    // Remove time patterns (e.g., "8 pm", "3:00 PM", "at 8 pm")
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(at|by|before|after)\s+\d{1,2}(?::\d{2})?\s*(am|pm|AM|PM)\b', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\b\d{1,2}(?::\d{2})?\s*(am|pm|AM|PM)\b', caseSensitive: false),
      '',
    );
    
    // Remove date patterns (e.g., "today", "tomorrow", "Nov 3")
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(today|tomorrow|now)\b', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\b(nov|dec|jan|feb|mar|apr|may|jun|jul|aug|sep|oct)\s*\d{1,2}\b', caseSensitive: false),
      '',
    );
    
    // Remove location phrases if they're just confirmation
    if (RegExp(r'^(no\s+location|specific\s+time|today|tomorrow|8\s+pm|3\s+pm)', caseSensitive: false).hasMatch(cleaned.trim())) {
      // If the cleaned text is just a time/date phrase, return empty (will preserve existing text)
      return '';
    }
    
    cleaned = cleaned.trim();
    // If after cleaning it's just whitespace or empty, return empty (preserve existing)
    return cleaned.isEmpty ? '' : cleaned;
  }

  /// Detect intent type
  IntentType? _detectIntent(String text) {
    // Check for location keywords
    final hasLocation = AppConstants.locationKeywords.any(
      (keyword) => text.contains(keyword),
    );
    final hasLeave = AppConstants.leaveKeywords.any(
      (keyword) => text.contains(keyword),
    );
    final hasArrive = AppConstants.arriveKeywords.any(
      (keyword) => text.contains(keyword),
    );

    if (hasLocation || hasLeave || hasArrive) {
      return IntentType.locationBased;
    }

    // Check for recurrence keywords
    final hasRecurrence = RegExp(
          r'\b(every|daily|weekly|monthly|repeat)\s*\d*\s*(minute|hour|day|week|month)?',
          caseSensitive: false,
        ).hasMatch(text);
    
    if (hasRecurrence) {
      return IntentType.recurring;
    }

    // Check for time keywords or explicit time
    final hasTimeKeyword = RegExp(r'\b(at|by|before|after|when)\s+\d', caseSensitive: false)
        .hasMatch(text);
    final hasTimePattern = RegExp(r'\d{1,2}\s*(am|pm|:\d{2})', caseSensitive: false)
        .hasMatch(text);
    
    if (hasTimeKeyword || hasTimePattern) {
      return IntentType.timeBased;
    }

    // Check for weather
    if (_hasWeatherIntent(text)) {
      return IntentType.weatherBased;
    }

    // Check for activity
    if (_extractActivity(text) != null) {
      return IntentType.activityBased;
    }

    // Default: If no location/activity mentioned, assume time-based
    // (most common case - user wants reminder at a specific time)
    return IntentType.timeBased;
  }

  /// Extract time from text
  DateTime? _extractTime(String text) {
    debugPrint('   🕐 Extracting time from: "$text"');
    
    final timePatterns = [
      // "at 8:30 PM", "by 3:00 pm"
      RegExp(
        r'(?:at|by|before|after)\s+(\d{1,2}:\d{2}\s*(?:am|pm|AM|PM))',
        caseSensitive: false,
      ),
      // "at 8 PM", "by 3 pm"
      RegExp(
        r'(?:at|by|before|after)\s+(\d{1,2}\s*(?:am|pm|AM|PM))',
        caseSensitive: false,
      ),
      // Standalone "8:30 PM", "3:00 pm"
      RegExp(r'\b(\d{1,2}:\d{2}\s*(?:am|pm|AM|PM))', caseSensitive: false),
      // Standalone "8 PM", "3 pm", "8pm" - THIS IS THE KEY ONE FOR "8 pm today"
      RegExp(r'(\d{1,2})\s*(am|pm|AM|PM)\b', caseSensitive: false),
    ];

    for (var i = 0; i < timePatterns.length; i++) {
      final pattern = timePatterns[i];
      final match = pattern.firstMatch(text);
      if (match != null) {
        String? timeStr;
        // For the last pattern (group 1 = hour, group 2 = am/pm), combine them
        if (i == timePatterns.length - 1 && match.groupCount >= 2) {
          final hour = match.group(1);
          final amPm = match.group(2);
          if (hour != null && amPm != null) {
            timeStr = '$hour $amPm';
          }
        } else {
          timeStr = match.group(1);
        }
        
        if (timeStr != null) {
          debugPrint('   🕐 Found time pattern $i: "$timeStr"');
          final parsedTime = DateTimeUtils.parseTime(timeStr.trim());
          if (parsedTime != null) {
            debugPrint('   ✅ Parsed time: $parsedTime');
            return parsedTime;
          } else {
            debugPrint('   ❌ Failed to parse time: "$timeStr"');
          }
        }
      }
    }
    
    debugPrint('   ❌ No time pattern matched');

    // Named times
    if (text.contains('morning')) {
      return DateTime.now().copyWith(hour: 8, minute: 0, second: 0);
    } else if (text.contains('afternoon')) {
      return DateTime.now().copyWith(hour: 14, minute: 0, second: 0);
    } else if (text.contains('evening')) {
      return DateTime.now().copyWith(hour: 18, minute: 0, second: 0);
    } else if (text.contains('night')) {
      return DateTime.now().copyWith(hour: 21, minute: 0, second: 0);
    }

    return null;
  }

  /// Extract location and movement context
  Map<String, dynamic> _extractLocation(String text) {
    String? location;
    bool leaving = false;
    bool arriving = false;

    // Check for leaving keywords
    for (var keyword in AppConstants.leaveKeywords) {
      if (text.contains(keyword)) {
        leaving = true;
        break;
      }
    }

    // Check for arriving keywords
    for (var keyword in AppConstants.arriveKeywords) {
      if (text.contains(keyword)) {
        arriving = true;
        break;
      }
    }

    // Extract location name
    for (var locationKeyword in AppConstants.locationKeywords) {
      if (text.contains(locationKeyword)) {
        location = locationKeyword;
        break;
      }
    }

    // Custom location patterns
    final customLocationPattern = RegExp(
      r'(?:at|to|from)\s+([a-z\s]+?)(?:\s+at|\s+when|\s+by|$)',
      caseSensitive: false,
    );
    final match = customLocationPattern.firstMatch(text);
    if (match != null && location == null) {
      location = match.group(1)?.trim();
    }

    return {'location': location, 'leaving': leaving, 'arriving': arriving};
  }

  /// Extract recurrence information
  Map<String, dynamic> _extractRecurrence(String text) {
    final patterns = [
      RegExp(
        r'every\s+(\d+)\s*(minute|minutes|min|mins|hour|hours|hr|hrs|day|days|week|weeks|month|months)',
        caseSensitive: false,
      ),
      RegExp(
        r'every\s+(minute|minutes|min|hour|hours|hr|day|days|week|weeks|month|months)',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(daily|weekly|monthly|biweekly|bi-weekly)\b',
        caseSensitive: false,
      ),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        int interval = 1;
        String? unit;

        if (match.groupCount >= 2 && match.group(1) != null) {
          interval = int.tryParse(match.group(1)!) ?? 1;
          unit = match.group(2);
        } else {
          unit = match.group(1);

          if (unit?.toLowerCase() == 'daily') {
            unit = 'days';
            interval = 1;
          } else if (unit?.toLowerCase() == 'weekly') {
            unit = 'weeks';
            interval = 1;
          } else if (unit?.toLowerCase() == 'monthly') {
            unit = 'months';
            interval = 1;
          } else if (unit?.toLowerCase() == 'biweekly' ||
              unit?.toLowerCase() == 'bi-weekly') {
            unit = 'weeks';
            interval = 2;
          }
        }

        // Normalize unit
        if (unit != null) {
          if (unit.startsWith('min')) {
            unit = 'minutes';
          } else if (unit.startsWith('hour') || unit.startsWith('hr')) {
            unit = 'hours';
          } else if (unit.startsWith('day')) {
            unit = 'days';
          } else if (unit.startsWith('week')) {
            unit = 'weeks';
          } else if (unit.startsWith('month')) {
            unit = 'months';
          }

          return {'interval': interval, 'unit': unit};
        }
      }
    }

    return {'interval': null, 'unit': null};
  }

  /// Extract priority
  ReminderPriority _extractPriority(String text) {
    final lowerText = text.toLowerCase();

    if (RegExp(
          r'\b(urgent|critical|asap|immediately|emergency|important|now)\b',
          caseSensitive: false,
        ).hasMatch(lowerText)) {
      return ReminderPriority.high;
    }

    if (RegExp(
          r'\b(whenever|eventually|someday|maybe|sometime)\b',
          caseSensitive: false,
        ).hasMatch(lowerText)) {
      return ReminderPriority.low;
    }

    return ReminderPriority.medium;
  }

  /// Extract category (basic)
  ReminderCategory? _extractCategory(String text) {
    if (RegExp(r'\b(health|medicine|doctor|hospital|vitamin)\b',
            caseSensitive: false)
        .hasMatch(text)) {
      return ReminderCategory.health;
    }
    if (RegExp(r'\b(work|office|meeting|project|task)\b', caseSensitive: false)
        .hasMatch(text)) {
      return ReminderCategory.work;
    }
    if (RegExp(r'\b(study|homework|exam|class)\b', caseSensitive: false)
        .hasMatch(text)) {
      return ReminderCategory.study;
    }
    if (RegExp(r'\b(shopping|buy|purchase|store|grocery)\b',
            caseSensitive: false)
        .hasMatch(text)) {
      return ReminderCategory.shopping;
    }
    if (RegExp(r'\b(family|mom|dad|parent|child|kid)\b', caseSensitive: false)
        .hasMatch(text)) {
      return ReminderCategory.family;
    }

    return null;
  }

  /// Check for weather intent
  bool _hasWeatherIntent(String text) {
    return text.contains("when it's raining") ||
        text.contains('when its raining') ||
        text.contains('when raining') ||
        text.contains('if raining') ||
        text.contains('when it rains') ||
        text.contains('if it rains') ||
        (text.contains('umbrella') &&
            (text.contains('rain') || text.contains('raining')));
  }

  /// Extract activity type
  String? _extractActivity(String text) {
    if (text.contains('walking') || text.contains('walk')) {
      return 'walking';
    }
    if (text.contains('running') || text.contains('run')) {
      return 'running';
    }
    if (text.contains('cycling') || text.contains('bike')) {
      return 'onBicycle';
    }
    if (text.contains('driving') || text.contains('car')) {
      return 'inVehicle';
    }
    if (text.contains('still') || text.contains('stationary')) {
      return 'still';
    }
    return null;
  }

  /// Calculate confidence score (0.0 to 1.0)
  double _calculateConfidence(
    Map<String, dynamic> extracted,
    IntentType? intent,
  ) {
    double score = 0.0;

    // Text extraction (required)
    if (extracted['text'] != null &&
        (extracted['text'] as String).isNotEmpty) {
      score += 0.3;
    }

    // Intent detection
    if (intent != null && intent != IntentType.ambiguous) {
      score += 0.2;
    }

    // Time extraction
    if (extracted['time'] != null) {
      score += 0.15;
    }

    // Location extraction
    if (extracted['location'] != null) {
      score += 0.15;
    }

    // Recurrence extraction
    if (extracted['repeatInterval'] != null &&
        extracted['repeatUnit'] != null) {
      score += 0.1;
    }

    // Priority/category extraction
    if (extracted['priority'] != null || extracted['category'] != null) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Check for ambiguity
  bool _hasAmbiguity(Map<String, dynamic> extracted) {
    // Ambiguous if multiple intents are possible
    final hasTime = extracted['time'] != null;
    final hasLocation = extracted['location'] != null;
    final hasRecurrence =
        extracted['repeatInterval'] != null && extracted['repeatUnit'] != null;

    final intentCount = [hasTime, hasLocation, hasRecurrence]
        .where((e) => e == true)
        .length;

    // Ambiguous if multiple triggers or unclear intent
    return intentCount > 1 || extracted['intent'] == null;
  }

  /// Identify missing required fields
  List<String> _identifyMissingFields(
    Map<String, dynamic> extracted,
    IntentType? intent,
  ) {
    final missing = <String>[];

    // Text is always required
    if (extracted['text'] == null ||
        (extracted['text'] as String).isEmpty) {
      missing.add('text');
    }

    // Conditional requirements based on intent
    switch (intent) {
      case IntentType.timeBased:
        if (extracted['time'] == null) {
          missing.add('time');
        }
        break;

      case IntentType.locationBased:
        if (extracted['location'] == null) {
          missing.add('location');
        }
        if (extracted['onLeaveContext'] != true &&
            extracted['onArriveContext'] != true) {
          missing.add('locationTrigger');
        }
        break;

      case IntentType.recurring:
        if (extracted['repeatInterval'] == null ||
            extracted['repeatUnit'] == null) {
          missing.add('recurrence');
        }
        break;

      case IntentType.activityBased:
        if (extracted['activityType'] == null) {
          missing.add('activity');
        }
        break;

      case IntentType.weatherBased:
        if (extracted['weatherCondition'] == null) {
          missing.add('weather');
        }
        break;

      case IntentType.ambiguous:
      case null:
        // Need to determine intent first
        missing.add('intent');
        break;
    }

    return missing;
  }
}
