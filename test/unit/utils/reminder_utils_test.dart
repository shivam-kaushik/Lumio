import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/data/models/reminder.dart';
import 'package:lumio/core/utils/date_time_utils.dart';

void main() {
  group('ReminderUtils Tests', () {
    final now = DateTime(2025, 6, 15, 14, 30);

    Reminder _makeReminder({
      String text = 'Test',
      DateTime? timeAt,
      String? geofenceId,
      double? geofenceLat,
      int? repeatInterval,
      String? repeatUnit,
      bool enabled = true,
    }) {
      return Reminder(
        id: 'id-${text.hashCode}',
        text: text,
        timeAt: timeAt,
        geofenceId: geofenceId,
        geofenceLat: geofenceLat,
        repeatInterval: repeatInterval,
        repeatUnit: repeatUnit,
        enabled: enabled,
        createdAt: now,
      );
    }

    group('groupByContext', () {
      test('categorizes time-based reminders within next hour as Relevant Now', () {
        final reminders = [
          _makeReminder(
            text: 'Soon',
            timeAt: now.add(const Duration(minutes: 30)),
          ),
        ];

        final groups = ReminderUtils.groupByContext(reminders, currentTime: now);
        expect(groups['Relevant Now'], isNotNull);
        expect(groups['Relevant Now']!.length, 1);
      });

      test('categorizes future time-based reminders as Time-Based', () {
        final reminders = [
          _makeReminder(
            text: 'Later',
            timeAt: now.add(const Duration(hours: 3)),
          ),
        ];

        final groups = ReminderUtils.groupByContext(reminders, currentTime: now);
        expect(groups['Time-Based'], isNotNull);
        expect(groups['Time-Based']!.length, 1);
      });

      test('categorizes recurring reminders as Recurring', () {
        final reminders = [
          _makeReminder(
            text: 'Recurring',
            repeatInterval: 1,
            repeatUnit: 'days',
          ),
        ];

        final groups = ReminderUtils.groupByContext(reminders, currentTime: now);
        expect(groups['Recurring'], isNotNull);
        expect(groups['Recurring']!.length, 1);
      });

      test('categorizes location-based reminders as Location-Based', () {
        final reminders = [
          _makeReminder(
            text: 'Location',
            geofenceId: 'geo-1',
          ),
        ];

        final groups = ReminderUtils.groupByContext(reminders, currentTime: now);
        expect(groups['Location-Based'], isNotNull);
        expect(groups['Location-Based']!.length, 1);
      });

      test('disabled reminders are excluded', () {
        final reminders = [
          _makeReminder(
            text: 'Disabled',
            timeAt: now.add(const Duration(minutes: 10)),
            enabled: false,
          ),
        ];

        final groups = ReminderUtils.groupByContext(reminders, currentTime: now);
        expect(groups.isEmpty, true);
      });

      test('mixed reminders correctly categorized', () {
        final reminders = [
          _makeReminder(text: 'Soon', timeAt: now.add(const Duration(minutes: 15))),
          _makeReminder(text: 'Later', timeAt: now.add(const Duration(hours: 5))),
          _makeReminder(text: 'Geo', geofenceId: 'geo-1'),
          _makeReminder(text: 'Repeat', repeatInterval: 2, repeatUnit: 'hours'),
          _makeReminder(text: 'Other'),
        ];

        final groups = ReminderUtils.groupByContext(reminders, currentTime: now);
        expect(groups['Relevant Now']!.length, 1);
        expect(groups['Time-Based']!.length, 1);
        expect(groups['Location-Based']!.length, 1);
        expect(groups['Recurring']!.length, 1);
        expect(groups['Other']!.length, 1);
      });
    });

    group('getRelevantReminders', () {
      test('only returns reminders within next hour', () {
        final reminders = [
          _makeReminder(text: 'Soon', timeAt: now.add(const Duration(minutes: 20))),
          _makeReminder(text: 'Later', timeAt: now.add(const Duration(hours: 3))),
          _makeReminder(text: 'Other'),
        ];

        final relevant = ReminderUtils.getRelevantReminders(reminders, currentTime: now);
        expect(relevant.length, 1);
        expect(relevant[0].text, 'Soon');
      });
    });

    group('groupByLocation', () {
      test('groups by geofenceId', () {
        final reminders = [
          _makeReminder(text: 'Home 1', geofenceId: 'home'),
          _makeReminder(text: 'Home 2', geofenceId: 'home'),
          _makeReminder(text: 'Office', geofenceId: 'office'),
          _makeReminder(text: 'No Location'),
        ];

        final groups = ReminderUtils.groupByLocation(reminders);
        expect(groups['home']!.length, 2);
        expect(groups['office']!.length, 1);
        expect(groups['Other']!.length, 1);
      });
    });

    group('getContextDescription and getContextIcon', () {
      test('Relevant Now description', () {
        final reminders = [_makeReminder(text: 'A')];
        expect(
          ReminderUtils.getContextDescription('Relevant Now', reminders),
          '1 task ready',
        );
      });

      test('Relevant Now with multiple', () {
        final reminders = [_makeReminder(text: 'A'), _makeReminder(text: 'B')];
        expect(
          ReminderUtils.getContextDescription('Relevant Now', reminders),
          '2 tasks ready',
        );
      });

      test('Time-Based description', () {
        final reminders = [_makeReminder(text: 'A'), _makeReminder(text: 'B')];
        expect(
          ReminderUtils.getContextDescription('Time-Based', reminders),
          '2 upcoming',
        );
      });

      test('getContextIcon returns correct icons', () {
        expect(ReminderUtils.getContextIcon('Relevant Now'), '🔔');
        expect(ReminderUtils.getContextIcon('Time-Based'), '⏰');
        expect(ReminderUtils.getContextIcon('Location-Based'), '📍');
        expect(ReminderUtils.getContextIcon('Recurring'), '🔄');
        expect(ReminderUtils.getContextIcon('Unknown'), '📌');
      });

      test('empty reminders returns empty string', () {
        expect(ReminderUtils.getContextDescription('Relevant Now', []), '');
      });
    });
  });
}
