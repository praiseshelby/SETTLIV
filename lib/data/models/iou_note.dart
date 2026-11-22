import 'package:flutter/foundation.dart';

enum IouDirection {
  owedToMe, // Someone owes the user
  iOwe,     // User owes someone
}

@immutable
class IouPayment {
  final String id;
  final int amountPaise;
  final DateTime date;

  const IouPayment({
    required this.id,
    required this.amountPaise,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amountPaise': amountPaise,
        'date': date.toIso8601String(),
      };

  factory IouPayment.fromJson(Map<String, dynamic> json) {
    return IouPayment(
      id: json['id'] as String,
      amountPaise: json['amountPaise'] as int,
      date: DateTime.parse(json['date'] as String),
    );
  }
}

@immutable
class IouNote {
  final String id;
  final String personName;
  final String? phone;
  final IouDirection direction;
  final int amountPaise;
  final String note;
  final DateTime date;
  final DateTime? dueDate;
  final List<IouPayment> payments;
  final DateTime? deletedAt;

  const IouNote({
    required this.id,
    required this.personName,
    this.phone,
    required this.direction,
    required this.amountPaise,
    required this.note,
    required this.date,
    this.dueDate,
    this.payments = const [],
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;
  bool get isOwedToMe => direction == IouDirection.owedToMe;
  String get counterpartyName => personName;

  int get paidPaise {
    return payments.fold(0, (sum, p) => sum + p.amountPaise);
  }

  int get remainingPaise {
    final rem = amountPaise - paidPaise;
    return rem > 0 ? rem : 0;
  }

  bool get isSettled => remainingPaise == 0;

  bool isOverdue(DateTime now) {
    if (isSettled || dueDate == null) return false;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return due.isBefore(today);
  }

  String? dueLabel(DateTime now) {
    if (dueDate == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final diff = due.difference(today).inDays;

    if (diff < 0) {
      final days = diff.abs();
      return 'Overdue $days ${days == 1 ? 'day' : 'days'}';
    } else if (diff == 0) {
      return 'Due today';
    } else if (diff == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in $diff days';
    }
  }

  IouNote copyWith({
    String? id,
    String? personName,
    String? phone,
    IouDirection? direction,
    int? amountPaise,
    String? note,
    DateTime? date,
    DateTime? dueDate,
    List<IouPayment>? payments,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return IouNote(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      phone: phone ?? this.phone,
      direction: direction ?? this.direction,
      amountPaise: amountPaise ?? this.amountPaise,
      note: note ?? this.note,
      date: date ?? this.date,
      dueDate: dueDate ?? this.dueDate,
      payments: payments ?? this.payments,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'personName': personName,
        'phone': phone,
        'direction': direction.name,
        'amountPaise': amountPaise,
        'note': note,
        'date': date.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'payments': payments.map((p) => p.toJson()).toList(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory IouNote.fromJson(Map<String, dynamic> json) {
    return IouNote(
      id: json['id'] as String,
      personName: json['personName'] as String,
      phone: json['phone'] as String?,
      direction: IouDirection.values.firstWhere(
        (e) => e.name == json['direction'],
        orElse: () => IouDirection.owedToMe,
      ),
      amountPaise: json['amountPaise'] as int,
      note: json['note'] as String? ?? '',
      date: DateTime.parse(json['date'] as String),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
      payments: (json['payments'] as List<dynamic>?)
              ?.map((e) => IouPayment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IouNote &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          personName == other.personName &&
          phone == other.phone &&
          direction == other.direction &&
          amountPaise == other.amountPaise &&
          note == other.note &&
          date == other.date &&
          dueDate == other.dueDate &&
          listEquals(payments, other.payments) &&
          deletedAt == other.deletedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      personName.hashCode ^
      phone.hashCode ^
      direction.hashCode ^
      amountPaise.hashCode ^
      note.hashCode ^
      date.hashCode ^
      dueDate.hashCode ^
      Object.hashAll(payments) ^
      deletedAt.hashCode;
}
