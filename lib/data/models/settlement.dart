import 'package:flutter/foundation.dart';

enum SettlementMethod {
  upi('UPI'),
  cash('Cash'),
  other('Other');

  final String label;
  const SettlementMethod(this.label);
}

@immutable
class Settlement {
  final String id;
  final String groupId;
  final String from; // personId who paid
  final String to; // personId who received
  final int paise; // in paise
  final SettlementMethod method;
  final DateTime date;
  final DateTime? deletedAt;
  final String? note;

  // Backward compatibility getters
  String get payerId => from;
  String get payeeId => to;
  int get amount => paise;
  bool get isDeleted => deletedAt != null;

  const Settlement({
    required this.id,
    required this.groupId,
    String? from,
    String? payerId,
    String? to,
    String? payeeId,
    int? paise,
    int? amount,
    required this.date,
    this.method = SettlementMethod.upi,
    this.deletedAt,
    this.note,
  })  : from = from ?? payerId ?? '',
        to = to ?? payeeId ?? '',
        paise = paise ?? amount ?? 0;

  Settlement copyWith({
    String? id,
    String? groupId,
    String? from,
    String? payerId,
    String? to,
    String? payeeId,
    int? paise,
    int? amount,
    DateTime? date,
    SettlementMethod? method,
    DateTime? deletedAt,
    bool? isDeleted,
    String? note,
  }) {
    DateTime? effectiveDeletedAt = deletedAt ?? this.deletedAt;
    if (isDeleted != null) {
      effectiveDeletedAt = isDeleted ? (effectiveDeletedAt ?? DateTime.now()) : null;
    }

    return Settlement(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      from: from ?? payerId ?? this.from,
      to: to ?? payeeId ?? this.to,
      paise: paise ?? amount ?? this.paise,
      date: date ?? this.date,
      method: method ?? this.method,
      deletedAt: effectiveDeletedAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'from': from,
        'to': to,
        'paise': paise,
        'date': date.toIso8601String(),
        'method': method.name,
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
        if (note != null) 'note': note,
      };

  factory Settlement.fromJson(Map<String, dynamic> json) {
    final methodStr = json['method'] as String? ?? 'upi';
    final method = SettlementMethod.values.firstWhere(
      (e) => e.name == methodStr,
      orElse: () => SettlementMethod.upi,
    );
    final paise = (json['paise'] as int?) ?? (json['amount'] as int?) ?? 0;
    final from = (json['from'] as String?) ?? (json['payerId'] as String?) ?? '';
    final to = (json['to'] as String?) ?? (json['payeeId'] as String?) ?? '';

    return Settlement(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      from: from,
      to: to,
      paise: paise,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      method: method,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
      note: json['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Settlement &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupId == other.groupId &&
          from == other.from &&
          to == other.to &&
          paise == other.paise &&
          date == other.date &&
          method == other.method &&
          deletedAt == other.deletedAt &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      groupId.hashCode ^
      from.hashCode ^
      to.hashCode ^
      paise.hashCode ^
      date.hashCode ^
      method.hashCode ^
      deletedAt.hashCode ^
      note.hashCode;
}
