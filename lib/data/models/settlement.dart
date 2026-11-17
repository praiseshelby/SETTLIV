import 'package:flutter/foundation.dart';

enum SettlementMethod { upi, cash }

@immutable
class Settlement {
  final String id;
  final String groupId;
  final String payerId;
  final String payeeId;
  final int amount; // in paise
  final DateTime date;
  final SettlementMethod method;
  final String? note;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.payerId,
    required this.payeeId,
    required this.amount,
    required this.date,
    this.method = SettlementMethod.upi,
    this.note,
  });

  Settlement copyWith({
    String? id,
    String? groupId,
    String? payerId,
    String? payeeId,
    int? amount,
    DateTime? date,
    SettlementMethod? method,
    String? note,
  }) {
    return Settlement(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      payerId: payerId ?? this.payerId,
      payeeId: payeeId ?? this.payeeId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      method: method ?? this.method,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settlement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupId == other.groupId &&
          payerId == other.payerId &&
          payeeId == other.payeeId &&
          amount == other.amount &&
          date == other.date &&
          method == other.method &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      groupId.hashCode ^
      payerId.hashCode ^
      payeeId.hashCode ^
      amount.hashCode ^
      date.hashCode ^
      method.hashCode ^
      note.hashCode;
}
