import 'package:flutter_test/flutter_test.dart';
import 'package:lumio/core/utils/date_time_utils.dart';

void main() {
  group('DateTimeUtils Tests', () {
    group('parseTime', () {
      test('"8 PM" → hour 20', () {
        final result = DateTimeUtils.parseTime('8 PM');
        expect(result, isNotNull);
        expect(result!.hour, 20);
        expect(result.minute, 0);
      });

      test('"8:30 PM" → hour 20, minute 30', () {
        final result = DateTimeUtils.parseTime('8:30 PM');
        expect(result, isNotNull);
        expect(result!.hour, 20);
        expect(result.minute, 30);
      });

      test('"20:00" → hour 20', () {
        final result = DateTimeUtils.parseTime('20:00');
        expect(result, isNotNull);
        expect(result!.hour, 20);
        expect(result.minute, 0);
      });

      test('"8:30" → hour 8, minute 30', () {
        final result = DateTimeUtils.parseTime('8:30');
        expect(result, isNotNull);
        expect(result!.hour, 8);
        expect(result.minute, 30);
      });

      test('"12 AM" → hour 0 (midnight)', () {
        final result = DateTimeUtils.parseTime('12 AM');
        expect(result, isNotNull);
        expect(result!.hour, 0);
      });

      test('"12 PM" → hour 12 (noon)', () {
        final result = DateTimeUtils.parseTime('12 PM');
        expect(result, isNotNull);
        expect(result!.hour, 12);
      });

      test('invalid input returns null', () {
        expect(DateTimeUtils.parseTime('not a time'), isNull);
        expect(DateTimeUtils.parseTime(''), isNull);
      });
    });

    group('isToday', () {
      test('today returns true', () {
        expect(DateTimeUtils.isToday(DateTime.now()), true);
      });

      test('yesterday returns false', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(DateTimeUtils.isToday(yesterday), false);
      });

      test('tomorrow returns false', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(DateTimeUtils.isToday(tomorrow), false);
      });
    });

    group('getRelativeTime', () {
      test('seconds ago → Just now', () {
        final recent = DateTime.now().subtract(const Duration(seconds: 30));
        expect(DateTimeUtils.getRelativeTime(recent), 'Just now');
      });

      test('minutes ago', () {
        final minsAgo = DateTime.now().subtract(const Duration(minutes: 5));
        expect(DateTimeUtils.getRelativeTime(minsAgo), '5m ago');
      });

      test('hours ago', () {
        final hoursAgo = DateTime.now().subtract(const Duration(hours: 3));
        expect(DateTimeUtils.getRelativeTime(hoursAgo), '3h ago');
      });

      test('days ago', () {
        final daysAgo = DateTime.now().subtract(const Duration(days: 4));
        expect(DateTimeUtils.getRelativeTime(daysAgo), '4d ago');
      });

      test('weeks ago', () {
        final weeksAgo = DateTime.now().subtract(const Duration(days: 14));
        expect(DateTimeUtils.getRelativeTime(weeksAgo), '2w ago');
      });
    });

    group('getTimeUntil', () {
      test('future date shows "in X"', () {
        final future = DateTime.now().add(const Duration(hours: 5));
        final result = DateTimeUtils.getTimeUntil(future);
        expect(result, anyOf('in 4h', 'in 5h'));
      });

      test('past date shows "Overdue"', () {
        final past = DateTime.now().subtract(const Duration(hours: 1));
        expect(DateTimeUtils.getTimeUntil(past), 'Overdue');
      });

      test('future minutes', () {
        final future = DateTime.now().add(const Duration(minutes: 30));
        final result = DateTimeUtils.getTimeUntil(future);
        expect(result, anyOf('in 29m', 'in 30m'));
      });
    });

    group('formatDateTime / formatTime / formatDate', () {
      test('formatDateTime returns expected format', () {
        final dt = DateTime(2025, 3, 15, 14, 30);
        final result = DateTimeUtils.formatDateTime(dt);
        expect(result, contains('Mar'));
        expect(result, contains('15'));
        expect(result, contains('2025'));
      });

      test('formatTime returns time string', () {
        final dt = DateTime(2025, 3, 15, 14, 30);
        final result = DateTimeUtils.formatTime(dt);
        expect(result, contains('02:30 PM'));
      });

      test('formatDate returns date string', () {
        final dt = DateTime(2025, 3, 15);
        final result = DateTimeUtils.formatDate(dt);
        expect(result, contains('Mar'));
        expect(result, contains('15'));
        expect(result, contains('2025'));
      });
    });

    group('calculateNextOccurrence', () {
      test('daily interval', () {
        final now = DateTime(2025, 6, 15, 10, 0);
        final next = DateTimeUtils.calculateNextOccurrence(now, 1, 'days');
        expect(next, DateTime(2025, 6, 16, 10, 0));
      });

      test('weekly interval', () {
        final now = DateTime(2025, 6, 15, 10, 0);
        final next = DateTimeUtils.calculateNextOccurrence(now, 1, 'weeks');
        expect(next, DateTime(2025, 6, 22, 10, 0));
      });

      test('monthly interval (approximate)', () {
        final now = DateTime(2025, 6, 15, 10, 0);
        final next = DateTimeUtils.calculateNextOccurrence(now, 1, 'months');
        expect(next, DateTime(2025, 7, 15, 10, 0));
      });

      test('with specific days of week', () {
        // June 15, 2025 is a Sunday (weekday=7)
        final now = DateTime(2025, 6, 15, 10, 0);
        final timeAt = DateTime(2025, 6, 15, 9, 0); // 9 AM
        final next = DateTimeUtils.calculateNextOccurrence(
          now,
          1,
          'weeks',
          repeatOnDays: [1], // Monday
          timeAt: timeAt,
        );
        expect(next, isNotNull);
        expect(next!.weekday, 1); // Monday
        expect(next.hour, 9);
      });
    });
  });
}
