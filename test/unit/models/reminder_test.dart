import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/models/reminder.dart';

void main() {
  group('Reminder Model Tests', () {
    final now = DateTime(2025, 6, 15, 14, 30);

    Map<String, dynamic> _fullMap() => {
          'id': 'abc-123',
          'text': 'Take medication',
          'timeAt': now.toIso8601String(),
          'geofenceId': 'geo-1',
          'geofenceLat': 37.7749,
          'geofenceLng': -122.4194,
          'geofenceRadius': 100.0,
          'wifiSsid': 'HomeWifi',
          'onLeaveContext': 1,
          'onArriveContext': 0,
          'weatherCondition': 'rain',
          'enabled': 1,
          'createdAt': now.toIso8601String(),
          'lastTriggeredAt': now.toIso8601String(),
          'triggerCount': 5,
          'repeatInterval': 2,
          'repeatUnit': 'hours',
          'repeatEndDate': now.add(const Duration(days: 30)).toIso8601String(),
          'repeatOnDays': '1,3,5',
          'timeRangeStart': now.toIso8601String(),
          'timeRangeEnd':
              now.add(const Duration(hours: 4)).toIso8601String(),
          'preferredTimeOfDay': 'afternoon',
          'priority': 'high',
          'category': 'health',
          'isPaused': 0,
          'skipCount': 2,
          'keepRemindingUntilCompleted': 1,
          'activityType': 'walking',
          'useSmartTiming': 1,
          'linked_goal_id': 42,
        };

    test('round-trip serialization toMap → fromMap preserves all fields', () {
      final reminder = Reminder.fromMap(_fullMap());
      final restoredMap = reminder.toMap();
      final restored = Reminder.fromMap(restoredMap);

      expect(restored.id, 'abc-123');
      expect(restored.text, 'Take medication');
      expect(restored.timeAt, now);
      expect(restored.geofenceId, 'geo-1');
      expect(restored.geofenceLat, 37.7749);
      expect(restored.geofenceLng, -122.4194);
      expect(restored.geofenceRadius, 100.0);
      expect(restored.wifiSsid, 'HomeWifi');
      expect(restored.onLeaveContext, true);
      expect(restored.onArriveContext, false);
      expect(restored.weatherCondition, 'rain');
      expect(restored.enabled, true);
      expect(restored.triggerCount, 5);
      expect(restored.repeatInterval, 2);
      expect(restored.repeatUnit, 'hours');
      expect(restored.repeatOnDays, [1, 3, 5]);
      expect(restored.priority, ReminderPriority.high);
      expect(restored.category, ReminderCategory.health);
      expect(restored.keepRemindingUntilCompleted, true);
      expect(restored.linkedGoalId, 42);
    });

    test('enum parsing with valid ReminderPriority values', () {
      for (final p in ReminderPriority.values) {
        final map = _fullMap();
        map['priority'] = p.name;
        final reminder = Reminder.fromMap(map);
        expect(reminder.priority, p);
      }
    });

    test('enum parsing with valid ReminderCategory values', () {
      for (final c in ReminderCategory.values) {
        final map = _fullMap();
        map['category'] = c.name;
        final reminder = Reminder.fromMap(map);
        expect(reminder.category, c);
      }
    });

    test('enum parsing with valid TimeOfDay values', () {
      for (final t in TimeOfDay.values) {
        final map = _fullMap();
        map['preferredTimeOfDay'] = t.name;
        final reminder = Reminder.fromMap(map);
        expect(reminder.preferredTimeOfDay, t);
      }
    });

    test('repeatOnDays parses comma-separated string', () {
      final map = _fullMap();
      map['repeatOnDays'] = '1,2,3,4,5';
      final reminder = Reminder.fromMap(map);
      expect(reminder.repeatOnDays, [1, 2, 3, 4, 5]);
    });

    test('repeatOnDays round-trips through toMap (joins to string)', () {
      final reminder = Reminder.fromMap(_fullMap());
      final map = reminder.toMap();
      expect(map['repeatOnDays'], '1,3,5');

      final restored = Reminder.fromMap(map);
      expect(restored.repeatOnDays, [1, 3, 5]);
    });

    test('getContextIcons returns correct icons', () {
      final reminder = Reminder.fromMap(_fullMap());
      final icons = reminder.getContextIcons();

      expect(icons, contains('⏰')); // timeAt is set
      expect(icons, contains('📍')); // geofenceId is set
      expect(icons, contains('📶')); // wifiSsid is set
      expect(icons, contains('🚪')); // onLeaveContext is true
    });

    test('getContextIcons returns empty for minimal reminder', () {
      final reminder = Reminder(
        id: 'min',
        text: 'Simple',
        createdAt: now,
      );
      expect(reminder.getContextIcons(), isEmpty);
    });

    test('getContextDescription includes priority and recurrence', () {
      final reminder = Reminder.fromMap(_fullMap());
      final desc = reminder.getContextDescription();

      expect(desc, contains('High'));
      expect(desc, contains('Every 2 hours'));
    });

    test('isRecurring getter returns true when both interval and unit set', () {
      final recurring = Reminder(
        text: 'Recurring',
        repeatInterval: 1,
        repeatUnit: 'days',
        createdAt: now,
      );
      expect(recurring.isRecurring, true);
    });

    test('isRecurring getter returns false when interval or unit missing', () {
      final noInterval = Reminder(
        text: 'Not recurring',
        repeatUnit: 'days',
        createdAt: now,
      );
      expect(noInterval.isRecurring, false);

      final noUnit = Reminder(
        text: 'Not recurring',
        repeatInterval: 1,
        createdAt: now,
      );
      expect(noUnit.isRecurring, false);
    });

    test('location-based fields parse correctly', () {
      final reminder = Reminder.fromMap(_fullMap());
      expect(reminder.geofenceLat, 37.7749);
      expect(reminder.geofenceLng, -122.4194);
      expect(reminder.geofenceRadius, 100.0);
      expect(reminder.geofenceId, 'geo-1');
    });

    test('copyWith preserves and overrides values', () {
      final reminder = Reminder.fromMap(_fullMap());
      final copy = reminder.copyWith(
        text: 'Updated text',
        priority: ReminderPriority.critical,
      );

      expect(copy.text, 'Updated text');
      expect(copy.priority, ReminderPriority.critical);
      expect(copy.id, reminder.id); // preserved
      expect(copy.geofenceId, reminder.geofenceId); // preserved
      expect(copy.category, reminder.category); // preserved
      expect(copy.createdAt, reminder.createdAt); // preserved
    });

    test('constructor generates UUID if id not provided', () {
      final r1 = Reminder(text: 'No ID 1', createdAt: now);
      final r2 = Reminder(text: 'No ID 2', createdAt: now);

      expect(r1.id, isNotEmpty);
      expect(r2.id, isNotEmpty);
      expect(r1.id, isNot(equals(r2.id)));
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 'test-id',
        'text': 'Minimal',
        'timeAt': null,
        'geofenceId': null,
        'geofenceLat': null,
        'geofenceLng': null,
        'geofenceRadius': null,
        'wifiSsid': null,
        'onLeaveContext': 0,
        'onArriveContext': 0,
        'weatherCondition': null,
        'enabled': 1,
        'createdAt': now.toIso8601String(),
        'lastTriggeredAt': null,
        'repeatInterval': null,
        'repeatUnit': null,
        'repeatEndDate': null,
        'repeatOnDays': null,
        'timeRangeStart': null,
        'timeRangeEnd': null,
        'preferredTimeOfDay': null,
        'priority': 'medium',
        'category': 'other',
        'isPaused': 0,
        'skipCount': 0,
        'keepRemindingUntilCompleted': 0,
        'activityType': null,
        'useSmartTiming': 0,
        'linked_goal_id': null,
      };

      final reminder = Reminder.fromMap(map);
      expect(reminder.timeAt, isNull);
      expect(reminder.geofenceId, isNull);
      expect(reminder.repeatOnDays, isNull);
      expect(reminder.preferredTimeOfDay, isNull);
      expect(reminder.linkedGoalId, isNull);
    });
  });
}
