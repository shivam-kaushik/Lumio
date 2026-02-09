import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:lumio/data/models/goal.dart';
import 'package:lumio/data/models/goal_settings.dart';

class MockDocumentSnapshot extends Mock implements DocumentSnapshot {
  final Map<String, dynamic> _data;
  final String _id;

  MockDocumentSnapshot(this._id, this._data);

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic get(Object field) => _data[field];
}

void main() {
  group('Goal Model Tests', () {
    final now = DateTime(2025, 6, 15, 10, 30);

    Map<String, dynamic> _fullMap() => {
          'id': 1,
          'name': 'Learn Flutter',
          'created_at': now.toIso8601String(),
          'target_deadline': now.add(const Duration(days: 30)).toIso8601String(),
          'hours_per_day': 2.5,
          'total_estimated_hours': 100,
          'settings': {
            'frequency': 1,
            'tone': 0,
            'notificationTime': '09:00',
            'alertTiming': 2,
            'enableNotifications': true,
          },
          'image_url': 'https://example.com/image.png',
        };

    test('round-trip serialization toMap → fromMap preserves all fields', () {
      final goal = Goal.fromMap(_fullMap());
      final restoredMap = goal.toMap();
      final restored = Goal.fromMap(restoredMap);

      expect(restored.id, 1);
      expect(restored.name, 'Learn Flutter');
      expect(restored.createdAt, now);
      expect(restored.targetDeadline, now.add(const Duration(days: 30)));
      expect(restored.hoursPerDay, 2.5);
      expect(restored.totalEstimatedHours, 100);
      expect(restored.settings, isNotNull);
      expect(restored.imageUrl, 'https://example.com/image.png');
    });

    test('fromMap handles null optional fields', () {
      final map = {
        'id': 2,
        'name': 'Minimal Goal',
        'created_at': now.toIso8601String(),
      };
      final goal = Goal.fromMap(map);

      expect(goal.targetDeadline, isNull);
      expect(goal.hoursPerDay, isNull);
      expect(goal.totalEstimatedHours, isNull);
      expect(goal.settings, isNull);
      expect(goal.imageUrl, isNull);
    });

    test('fromMap coerces int to double for hoursPerDay', () {
      final map = {
        'id': 3,
        'name': 'Coercion Test',
        'created_at': now.toIso8601String(),
        'hours_per_day': 3, // int, not double
      };
      final goal = Goal.fromMap(map);

      expect(goal.hoursPerDay, 3.0);
      expect(goal.hoursPerDay, isA<double>());
    });

    test('fromFirestore parses Timestamp fields', () {
      final timestamp = Timestamp.fromDate(now);
      final data = {
        'name': 'Firestore Goal',
        'createdAt': timestamp,
        'targetDeadline': timestamp,
        'hoursPerDay': 1.5,
      };

      final doc = MockDocumentSnapshot('42', data);
      final goal = Goal.fromFirestore(doc);

      expect(goal.id, 42);
      expect(goal.name, 'Firestore Goal');
      expect(goal.createdAt, now);
      expect(goal.targetDeadline, now);
      expect(goal.hoursPerDay, 1.5);
    });

    test('fromFirestore parses ISO string DateTime fields', () {
      final data = {
        'name': 'String Date Goal',
        'createdAt': now.toIso8601String(),
        'targetDeadline': now.add(const Duration(days: 7)).toIso8601String(),
      };

      final doc = MockDocumentSnapshot('99', data);
      final goal = Goal.fromFirestore(doc);

      expect(goal.createdAt, now);
      expect(goal.targetDeadline, now.add(const Duration(days: 7)));
    });

    test('fromFirestore handles null createdAt with fallback to now', () {
      final data = {
        'name': 'No CreatedAt',
      };

      final doc = MockDocumentSnapshot('10', data);
      final goal = Goal.fromFirestore(doc);

      // Should not throw; createdAt defaults to DateTime.now()
      expect(goal.createdAt, isNotNull);
      expect(goal.name, 'No CreatedAt');
    });

    test('copyWith preserves values when no overrides given', () {
      final goal = Goal.fromMap(_fullMap());
      final copy = goal.copyWith();

      expect(copy.id, goal.id);
      expect(copy.name, goal.name);
      expect(copy.createdAt, goal.createdAt);
      expect(copy.hoursPerDay, goal.hoursPerDay);
      expect(copy.imageUrl, goal.imageUrl);
    });

    test('copyWith overrides specified fields', () {
      final goal = Goal.fromMap(_fullMap());
      final copy = goal.copyWith(name: 'Updated Name', hoursPerDay: 5.0);

      expect(copy.name, 'Updated Name');
      expect(copy.hoursPerDay, 5.0);
      expect(copy.id, goal.id); // unchanged
    });

    test('toInsertMap excludes id field', () {
      final goal = Goal.fromMap(_fullMap());
      final insertMap = goal.toInsertMap();

      expect(insertMap.containsKey('id'), isFalse);
      expect(insertMap['name'], 'Learn Flutter');
    });

    test('generateGoalImageUrl encodes goal name', () {
      final url = generateGoalImageUrl('Learn Flutter');
      expect(url, contains('Learn%20Flutter'));
      expect(url, startsWith('https://image.pollinations.ai/prompt/'));
      expect(url, contains('width=800'));
      expect(url, contains('height=600'));
    });

    test('generateGoalImageUrl handles special characters', () {
      final url = generateGoalImageUrl('C++ & Rust');
      expect(url, contains(Uri.encodeComponent('C++ & Rust')));
    });
  });
}
