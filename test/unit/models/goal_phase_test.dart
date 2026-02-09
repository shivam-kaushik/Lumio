import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mockito/mockito.dart';
import 'package:lumio/data/models/goal_phase.dart';

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
  group('GoalPhase Model Tests', () {
    final now = DateTime(2025, 6, 15, 10, 0);

    Map<String, dynamic> _fullMap() => {
          'id': 1,
          'goal_id': 10,
          'name': 'Phase 1: Research',
          'description': 'Initial research phase',
          'start_date': now.toIso8601String(),
          'end_date': now.add(const Duration(days: 14)).toIso8601String(),
          'order_index': 0,
          'created_at': now.toIso8601String(),
        };

    test('round-trip serialization toMap → fromMap', () {
      final phase = GoalPhase.fromMap(_fullMap());
      final restoredMap = phase.toMap();
      final restored = GoalPhase.fromMap(restoredMap);

      expect(restored.id, 1);
      expect(restored.goalId, 10);
      expect(restored.name, 'Phase 1: Research');
      expect(restored.description, 'Initial research phase');
      expect(restored.startDate, now);
      expect(restored.endDate, now.add(const Duration(days: 14)));
      expect(restored.orderIndex, 0);
      expect(restored.createdAt, now);
    });

    test('fromMap handles missing optional description', () {
      final map = {
        'id': 2,
        'goal_id': 10,
        'name': 'Phase 2',
        'start_date': now.toIso8601String(),
        'end_date': now.add(const Duration(days: 7)).toIso8601String(),
        'created_at': now.toIso8601String(),
      };
      final phase = GoalPhase.fromMap(map);

      expect(phase.description, isNull);
      expect(phase.orderIndex, 0); // default
    });

    test('fromFirestore parses goalId string to int', () {
      final data = {
        'goalId': '42',
        'name': 'Firestore Phase',
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(now.add(const Duration(days: 7))),
        'createdAt': Timestamp.fromDate(now),
        'orderIndex': 2,
      };

      final doc = MockDocumentSnapshot('5', data);
      final phase = GoalPhase.fromFirestore(doc);

      expect(phase.id, 5);
      expect(phase.goalId, 42);
      expect(phase.startDate, now);
      expect(phase.orderIndex, 2);
    });

    test('fromFirestore parses ISO string DateTime fields', () {
      final data = {
        'goalId': '10',
        'name': 'String Dates',
        'startDate': now.toIso8601String(),
        'endDate': now.add(const Duration(days: 7)).toIso8601String(),
        'createdAt': now.toIso8601String(),
      };

      final doc = MockDocumentSnapshot('3', data);
      final phase = GoalPhase.fromFirestore(doc);

      expect(phase.startDate, now);
      expect(phase.endDate, now.add(const Duration(days: 7)));
    });

    test('copyWith preserves and overrides values', () {
      final phase = GoalPhase.fromMap(_fullMap());
      final copy = phase.copyWith(name: 'Updated Phase', orderIndex: 5);

      expect(copy.name, 'Updated Phase');
      expect(copy.orderIndex, 5);
      expect(copy.id, phase.id); // preserved
      expect(copy.goalId, phase.goalId); // preserved
      expect(copy.startDate, phase.startDate); // preserved
    });

    test('toInsertMap excludes id field', () {
      final phase = GoalPhase.fromMap(_fullMap());
      final insertMap = phase.toInsertMap();

      expect(insertMap.containsKey('id'), isFalse);
      expect(insertMap['goal_id'], 10);
      expect(insertMap['name'], 'Phase 1: Research');
    });
  });
}
