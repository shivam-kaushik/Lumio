import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot, Timestamp, FieldValue;

/// Context event model for tracking reminder triggers and outcomes
class ContextEvent {
  final String id;
  final String reminderId;
  final String contextType;
  final DateTime triggerTime;
  final String outcome;
  final Map<String, dynamic>? metadata;

  ContextEvent({
    String? id,
    required this.reminderId,
    required this.contextType,
    DateTime? triggerTime,
    required this.outcome,
    this.metadata,
  }) : id = id ?? const Uuid().v4(),
       triggerTime = triggerTime ?? DateTime.now();

  /// Create ContextEvent from database map
  factory ContextEvent.fromMap(Map<String, dynamic> map) {
    return ContextEvent(
      id: map['id'] as String,
      reminderId: map['reminderId'] as String,
      contextType: map['contextType'] as String,
      triggerTime: DateTime.parse(map['triggerTime'] as String),
      outcome: map['outcome'] as String,
      metadata: map['metadata'] != null
          ? Map<String, dynamic>.from(map['metadata'] as Map)
          : null,
    );
  }

  /// Convert ContextEvent to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminderId': reminderId,
      'contextType': contextType,
      'triggerTime': triggerTime.toIso8601String(),
      'outcome': outcome,
      'metadata': metadata?.toString(),
    };
  }

  /// Create ContextEvent from Firestore document
  factory ContextEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ContextEvent(
      id: doc.id,
      reminderId: data['reminderId'] as String,
      contextType: data['contextType'] as String,
      triggerTime: data['triggerTime'] != null
          ? (data['triggerTime'] is Timestamp
              ? (data['triggerTime'] as Timestamp).toDate()
              : DateTime.parse(data['triggerTime'] as String))
          : DateTime.now(),
      outcome: data['outcome'] as String,
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'] as Map)
          : null,
    );
  }

  /// Convert ContextEvent to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'reminderId': reminderId,
      'contextType': contextType,
      'triggerTime': Timestamp.fromDate(triggerTime),
      'outcome': outcome,
      'metadata': metadata,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
