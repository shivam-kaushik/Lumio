import 'package:flutter/foundation.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_time_utils.dart';
import '../../data/models/reminder.dart';

/// Natural Language Understanding parser for reminder text
/// Extracts intent, context, and parameters from user input
class NLUParser {
  /// Parse reminder text and extract context information
  /// Returns a Reminder object with parsed fields
  static Reminder parseReminderText(String text) {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('🔍 NLU PARSER: Parsing reminder text');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('📝 Original text: "$text"');
    
    final lowerText = text.toLowerCase();
    debugPrint('📝 Lowercase text: "$lowerText"');

    DateTime? timeAt;
    String? locationName;
    bool onLeaveContext = false;
    bool onArriveContext = false;
    int? repeatInterval;
    String? repeatUnit;

    // Extract recurrence first (e.g., "every 2 minutes", "every hour")
    debugPrint('');
    debugPrint('🔄 Extracting recurrence...');
    final recurrenceInfo = _extractRecurrence(lowerText);
    repeatInterval = recurrenceInfo['interval'];
    repeatUnit = recurrenceInfo['unit'];
    debugPrint('   RepeatInterval: $repeatInterval');
    debugPrint('   RepeatUnit: $repeatUnit');

    // Extract time context
    debugPrint('');
    debugPrint('🕐 Extracting time...');
    timeAt = _extractTime(lowerText);
    debugPrint('   Extracted timeAt: $timeAt');
    
    // Check if user wants to start immediately ("starting now", "start now", "right away", etc.)
    debugPrint('');
    debugPrint('⚡ Checking for "starting now"...');
    final startImmediately = _shouldStartImmediately(lowerText);
    debugPrint('   startImmediately: $startImmediately');
    
    // If recurring and we have days of week, extract them now for better calculation
    final daysOfWeek = _extractDaysOfWeek(lowerText);
    debugPrint('   DaysOfWeek: $daysOfWeek');

    // Handle recurring reminders
    debugPrint('');
    debugPrint('🔁 Processing recurring reminder logic...');
    if (repeatInterval != null && repeatUnit != null) {
      debugPrint('   ✅ Is recurring (interval=$repeatInterval, unit=$repeatUnit)');
      
      if (startImmediately) {
        // User wants to start immediately - set first occurrence to very soon (10 seconds)
        // This allows time for dialog interaction but starts as quickly as possible
        debugPrint('   ⚡ startImmediately=true, setting timeAt to 10 seconds from now');
        timeAt = DateTime.now().add(const Duration(seconds: 10));
        debugPrint('   ✅ timeAt set to: $timeAt');
      } else if (timeAt == null) {
        // No specific time mentioned, calculate first occurrence based on interval
        debugPrint('   ⏰ timeAt is null, calculating first occurrence...');
        timeAt = _calculateFirstOccurrence(repeatInterval, repeatUnit, text: lowerText, daysOfWeek: daysOfWeek);
        debugPrint('   ✅ Calculated first occurrence: $timeAt');
      } else if (daysOfWeek != null && daysOfWeek.isNotEmpty) {
        // Recurring with specific time and days - calculate next occurrence
        debugPrint('   📅 Has daysOfWeek, calculating next occurrence...');
        final currentTime = timeAt;
        timeAt = _calculateNextOccurrenceForDays(DateTime.now(), daysOfWeek, currentTime);
        debugPrint('   ✅ Calculated next occurrence: $timeAt');
      } else {
        debugPrint('   ⚠️ Recurring but timeAt already set and no daysOfWeek - keeping existing timeAt: $timeAt');
      }
    } else {
      debugPrint('   ❌ Not recurring (interval=$repeatInterval, unit=$repeatUnit)');
    }

    // Extract location and movement context
    final locationInfo = _extractLocation(lowerText);
    locationName = locationInfo['location'];
    onLeaveContext = locationInfo['leaving'] ?? false;
    onArriveContext = locationInfo['arriving'] ?? false;

    // Extract priority from text
    final priority = _extractPriority(text);

    // Clean the reminder text (remove context phrases)
    debugPrint('');
    debugPrint('🧹 Cleaning reminder text...');
    final cleanText = _cleanReminderText(text);
    debugPrint('   Clean text: "$cleanText"');

    // Weather intent parsing
    debugPrint('');
    debugPrint('🌦️ Detecting weather intents...');
    String? weatherCondition;
    if (lowerText.contains("when it's raining") ||
        lowerText.contains('when its raining') ||
        lowerText.contains('when raining') ||
        lowerText.contains('if raining') ||
        lowerText.contains('when it rains') ||
        lowerText.contains('if it rains') ||
        (lowerText.contains('umbrella') && (lowerText.contains('rain') || lowerText.contains("raining")))) {
      weatherCondition = 'rain';
      // If user didn't specify movement, default to leaving home
      if (!onLeaveContext && !onArriveContext) {
        onLeaveContext = true;
        locationName ??= 'home';
      }
      debugPrint('   ✅ Weather condition detected: rain');
    } else {
      debugPrint('   ❌ No weather condition detected');
    }

    debugPrint('');
    debugPrint('📦 Creating Reminder object...');
    debugPrint('   text: "$cleanText"');
    debugPrint('   timeAt: $timeAt');
    debugPrint('   repeatInterval: $repeatInterval');
    debugPrint('   repeatUnit: $repeatUnit');
    debugPrint('   isRecurring: ${repeatInterval != null && repeatUnit != null}');
    debugPrint('═══════════════════════════════════════════════════');
    debugPrint('');

    return Reminder(
      text: cleanText,
      timeAt: timeAt,
      geofenceId: locationName,
      onLeaveContext: onLeaveContext,
      onArriveContext: onArriveContext,
      weatherCondition: weatherCondition,
      repeatInterval: repeatInterval,
      repeatUnit: repeatUnit,
      repeatOnDays: daysOfWeek,
      priority: priority,
    );
  }

  /// Extract recurrence information from text
  /// Examples: "every 2 minutes", "every hour", "every Monday", "daily at 9am"
  static Map<String, dynamic> _extractRecurrence(String text) {
    // Pattern: "every <number> <unit>" or "every <unit>"
    final patterns = [
      // "every 2 minutes", "every 2 weeks"
      RegExp(
        r'every\s+(\d+)\s*(minute|minutes|min|mins|hour|hours|hr|hrs|day|days|week|weeks|month|months)',
        caseSensitive: false,
      ),
      // "every minute", "every week"
      RegExp(
        r'every\s+(minute|minutes|min|hour|hours|hr|day|days|week|weeks|month|months)',
        caseSensitive: false,
      ),
      // "daily", "weekly", "monthly"
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
          // "every 2 minutes" case
          interval = int.tryParse(match.group(1)!) ?? 1;
          unit = match.group(2);
        } else {
          // "every minute" or "daily" case
          unit = match.group(1);
          
          // Handle special cases
          if (unit?.toLowerCase() == 'daily') {
            unit = 'days';
            interval = 1;
          } else if (unit?.toLowerCase() == 'weekly') {
            unit = 'weeks';
            interval = 1;
          } else if (unit?.toLowerCase() == 'monthly') {
            unit = 'months';
            interval = 1;
          } else if (unit?.toLowerCase() == 'biweekly' || unit?.toLowerCase() == 'bi-weekly') {
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

  /// Extract priority from text
  /// Keywords: "urgent", "important", "asap", "critical" → high
  /// Keywords: "whenever", "eventually", "someday" → low
  static ReminderPriority _extractPriority(String text) {
    final lowerText = text.toLowerCase();
    
    // High priority keywords
    if (RegExp(r'\b(urgent|critical|asap|immediately|emergency|important|now)\b', caseSensitive: false).hasMatch(lowerText)) {
      return ReminderPriority.high;
    }
    
    // Low priority keywords
    if (RegExp(r'\b(whenever|eventually|someday|maybe|sometime)\b', caseSensitive: false).hasMatch(lowerText)) {
      return ReminderPriority.low;
    }
    
    return ReminderPriority.medium;
  }

  /// Extract days of week from text
  /// Examples: "every Monday", "every weekday", "on Fridays"
  /// Returns list of day numbers (1=Monday, 7=Sunday)
  static List<int>? _extractDaysOfWeek(String text) {
    final dayMap = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
      'mon': 1,
      'tue': 2,
      'wed': 3,
      'thu': 4,
      'fri': 5,
      'sat': 6,
      'sun': 7,
    };

    // Check for weekday/weekend patterns
    if (text.contains('weekday')) {
      return [1, 2, 3, 4, 5]; // Monday to Friday
    }
    if (text.contains('weekend')) {
      return [6, 7]; // Saturday and Sunday
    }

    // Extract specific days
    final days = <int>[];
    for (var entry in dayMap.entries) {
      final pattern = RegExp(r'\b' + entry.key + r'\b', caseSensitive: false);
      if (pattern.hasMatch(text)) {
        if (!days.contains(entry.value)) {
          days.add(entry.value);
        }
      }
    }

    if (days.isEmpty) return null;
    days.sort();
    return days;
  }

  /// Calculate first occurrence time for recurring reminder
  /// If no date is specified, starts from today
  static DateTime _calculateFirstOccurrence(int interval, String unit, {String? text, List<int>? daysOfWeek}) {
    final now = DateTime.now();
    
    // If we have a specific time in the text and days of week, calculate next occurrence
    if (text != null && daysOfWeek != null && daysOfWeek.isNotEmpty) {
      final time = _extractTime(text);
      if (time != null) {
        // Find next matching day with the specified time
        return _calculateNextOccurrenceForDays(now, daysOfWeek, time);
      }
    }
    
    // Extract time from text if available
    final extractedTime = text != null ? _extractTime(text) : null;
    
    Duration duration;
    switch (unit) {
      case 'minutes':
        duration = Duration(minutes: interval);
        break;
      case 'hours':
        duration = Duration(hours: interval);
        break;
      case 'days':
        duration = Duration(days: interval);
        break;
      case 'weeks':
        duration = Duration(days: interval * 7);
        break;
      case 'months':
        // Approximate months (30 days)
        duration = Duration(days: interval * 30);
        break;
      default:
        duration = Duration(minutes: interval);
    }

    // If a time was extracted from text, use it with today's date
    if (extractedTime != null) {
      final todayWithTime = DateTime(
        now.year,
        now.month,
        now.day,
        extractedTime.hour,
        extractedTime.minute,
      );
      
      // If the time has already passed today, add the interval
      if (todayWithTime.isBefore(now)) {
        return todayWithTime.add(duration);
      }
      
      return todayWithTime;
    }

    // No time specified - start from now with the interval
    return now.add(duration);
  }

  /// Check if user wants reminder to start immediately
  /// Detects phrases like "starting now", "start now", "right away", "immediately", "from now"
  static bool _shouldStartImmediately(String text) {
    final immediatePhrases = [
      r'\b(starting\s+now|start\s+now)\b',
      r'\b(right\s+away|rightaway)\b',
      r'\b(immediately|asap)\b',
      r'\b(from\s+now|begin\s+now)\b',
      r'\b(begin\s+immediately)\b',
      r'\b(start\s+immediately)\b',
    ];

    for (var pattern in immediatePhrases) {
      final regex = RegExp(pattern, caseSensitive: false);
      if (regex.hasMatch(text)) {
        debugPrint('      ✅ Matched pattern: "$pattern"');
        return true;
      }
    }

    debugPrint('      ❌ No match found for "starting now" phrases');
    return false;
  }

  /// Calculate next occurrence for specific days of week with time
  static DateTime _calculateNextOccurrenceForDays(DateTime now, List<int> daysOfWeek, DateTime targetTime) {
    final currentDay = now.weekday; // 1=Monday, 7=Sunday
    
    // Find next matching day
    for (var day in daysOfWeek) {
      int daysToAdd = day - currentDay;
      if (daysToAdd < 0) {
        daysToAdd += 7; // Next week
      } else if (daysToAdd == 0 && now.hour * 60 + now.minute >= targetTime.hour * 60 + targetTime.minute) {
        daysToAdd = 7; // Same day but time has passed, move to next week
      }
      
      final nextDate = now.add(Duration(days: daysToAdd));
      return DateTime(
        nextDate.year,
        nextDate.month,
        nextDate.day,
        targetTime.hour,
        targetTime.minute,
        0,
      );
    }
    
    // Fallback
    return now.add(Duration(days: 1));
  }

  /// Extract time from text
  /// Examples: "at 8 PM", "at 8:30", "by 3:00 PM"
  static DateTime? _extractTime(String text) {
    // Pattern: "at|by|before|after <time>"
    final timePatterns = [
      RegExp(
        r'(?:at|by|before|after)\s+(\d{1,2}:\d{2}\s*(?:am|pm)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:at|by|before|after)\s+(\d{1,2}\s*(?:am|pm))',
        caseSensitive: false,
      ),
      RegExp(r'(\d{1,2}:\d{2}\s*(?:am|pm)?)', caseSensitive: false),
      RegExp(r'(\d{1,2}\s*(?:am|pm))', caseSensitive: false),
    ];

    for (var pattern in timePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final timeStr = match.group(1);
        if (timeStr != null) {
          final parsedTime = DateTimeUtils.parseTime(timeStr);
          if (parsedTime != null) {
            return parsedTime;
          }
        }
      }
    }

    // Named times
    if (text.contains('morning')) {
      return DateTime.now().copyWith(hour: 8, minute: 0, second: 0);
    } else if (text.contains('afternoon')) {
      return DateTime.now().copyWith(hour: 14, minute: 0, second: 0);
    } else if (text.contains('evening')) {
      return DateTime.now().copyWith(hour: 18, minute: 0, second: 0);
    } else if (text.contains('night')) {
      return DateTime.now().copyWith(hour: 21, minute: 0, second: 0);
    } else if (text.contains('wake up') || text.contains('waking up')) {
      return DateTime.now().copyWith(hour: 7, minute: 0, second: 0);
    } else if (text.contains('bedtime') || text.contains('sleep')) {
      return DateTime.now().copyWith(hour: 22, minute: 0, second: 0);
    }

    return null;
  }

  /// Extract location and movement context
  static Map<String, dynamic> _extractLocation(String text) {
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

  /// Clean reminder text by removing context phrases
  static String _cleanReminderText(String text) {
    String cleaned = text;

    // Remove recurrence phrases (including "every 2 mins", "every hour", etc.)
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*every\s+\d*\s*(?:minute|minutes|min|mins|hour|hours|hr|hrs|day|days|week|weeks|month|months)\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    
    // Also remove standalone recurrence words
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(daily|weekly|monthly|biweekly|bi-weekly)\b\s*',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove time phrases
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*(?:at|by|before|after)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?\s*',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove location phrases
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*(?:when|while)\s+(?:leaving|arriving|at|to|from)\s+\w+\s*',
        caseSensitive: false,
      ),
      ' ',
    );

    // Remove "remind me to" prefix
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s*remind\s+me\s+to\s+', caseSensitive: false),
      '',
    );

    // Remove "starting now" and similar immediate start phrases
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\s*(?:starting\s+now|start\s+now|right\s+away|rightaway|immediately|asap|from\s+now|begin\s+now|begin\s+immediately|start\s+immediately)\s*',
        caseSensitive: false,
      ),
      ' ',
    );

    // Clean up extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned.isEmpty ? text : cleaned;
  }

  /// Validate if text contains actionable intent
  static bool hasValidIntent(String text) {
    if (text.trim().length < 3) return false;

    // Check for action verbs
    final actionVerbs = [
      'take',
      'carry',
      'bring',
      'call',
      'text',
      'send',
      'buy',
      'pick',
      'drop',
      'turn',
      'check',
      'drink',
      'eat',
      'exercise',
      'study',
      'read',
      'write',
      'clean',
      'wash',
      'feed',
      'water',
    ];

    final lowerText = text.toLowerCase();
    for (var verb in actionVerbs) {
      if (lowerText.contains(verb)) return true;
    }

    // If no specific verb, still valid if it's a reasonable length
    return text.trim().split(' ').length >= 2;
  }

  /// Get suggested reminders based on input
  static List<String> getSuggestions(String input) {
    if (input.isEmpty) {
      return AppConstants.samplePhrases;
    }

    // Filter sample phrases that match input
    final lowerInput = input.toLowerCase();
    return AppConstants.samplePhrases
        .where((phrase) => phrase.toLowerCase().contains(lowerInput))
        .toList();
  }
}
