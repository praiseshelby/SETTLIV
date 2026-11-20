import 'package:flutter/foundation.dart';

enum ExpenseCategory {
  food('Food'),
  rent('Rent'),
  travel('Travel'),
  stay('Stay'),
  groceries('Groceries'),
  bills('Bills'),
  fun('Fun'),
  other('Other');

  final String label;
  const ExpenseCategory(this.label);
}

enum SplitMode {
  equal('Equal'),
  exact('Exact'),
  percent('Percent'),
  shares('Shares'),
  byIncome('By Income');

  final String label;
  const SplitMode(this.label);
}

enum ExpenseSource {
  manual('Manual'),
  quick('Quick'),
  sms('SMS');

  final String label;
  const ExpenseSource(this.label);
}

@immutable
class PayerShare {
  final String personId;
  final int paise;

  const PayerShare({
    required this.personId,
    required this.paise,
  });

  Map<String, dynamic> toJson() => {
        'personId': personId,
        'paise': paise,
      };

  factory PayerShare.fromJson(Map<String, dynamic> json) {
    return PayerShare(
      personId: json['personId'] as String,
      paise: json['paise'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayerShare &&
          runtimeType == other.runtimeType &&
          personId == other.personId &&
          paise == other.paise;

  @override
  int get hashCode => personId.hashCode ^ paise.hashCode;
}

@immutable
class ExpenseRevision {
  final DateTime editedAt;
  final String editedBy;
  final String summary;

  const ExpenseRevision({
    required this.editedAt,
    required this.editedBy,
    required this.summary,
  });

  Map<String, dynamic> toJson() => {
        'editedAt': editedAt.toIso8601String(),
        'editedBy': editedBy,
        'summary': summary,
      };

  factory ExpenseRevision.fromJson(Map<String, dynamic> json) {
    return ExpenseRevision(
      editedAt: DateTime.tryParse(json['editedAt'] as String? ?? '') ?? DateTime.now(),
      editedBy: json['editedBy'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseRevision &&
          runtimeType == other.runtimeType &&
          editedAt == other.editedAt &&
          editedBy == other.editedBy &&
          summary == other.summary;

  @override
  int get hashCode => editedAt.hashCode ^ editedBy.hashCode ^ summary.hashCode;
}

@immutable
class Expense {
  final String id;
  final String groupId;
  final String description;
  final String? note;
  final ExpenseCategory category;
  final int totalPaise;
  final DateTime date;
  final List<PayerShare> payers;
  final SplitMode splitMode;
  final Map<String, num>? splitParameters;
  final List<String> participants;
  final Map<String, int> computedShares;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<ExpenseRevision> revisions;
  final ExpenseSource source;
  final String? bankRef;

  // Backward compatibility getters
  String get title => description;
  int get amount => totalPaise;
  String get paidBy => payers.isNotEmpty ? payers.first.personId : '';
  Map<String, int> get shares => computedShares;
  bool get isDeleted => deletedAt != null;

  Expense({
    required this.id,
    required this.groupId,
    String? description,
    String? title,
    this.note,
    required this.category,
    int? totalPaise,
    int? amount,
    required this.date,
    List<PayerShare>? payers,
    String? paidBy,
    required this.splitMode,
    this.splitParameters,
    List<String>? participants,
    Map<String, int>? computedShares,
    Map<String, int>? shares,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    bool? isDeleted,
    List<ExpenseRevision>? revisions,
    this.source = ExpenseSource.manual,
    this.bankRef,
  })  : description = description ?? title ?? '',
        totalPaise = totalPaise ?? amount ?? 0,
        payers = payers ??
            (paidBy != null
                ? [PayerShare(personId: paidBy, paise: totalPaise ?? amount ?? 0)]
                : const []),
        computedShares = computedShares ?? shares ?? const {},
        participants = participants ??
            (computedShares != null
                ? computedShares.keys.toList()
                : (shares != null ? shares.keys.toList() : const [])),
        createdAt = createdAt ?? date,
        updatedAt = updatedAt ?? date,
        revisions = revisions ?? const [] {
    // If isDeleted is explicitly true and deletedAt is not set, set deletedAt
    if (isDeleted == true && deletedAt == null) {
      // In immutable fields, deletedAt cannot be reassigned here unless in initializer
    }
  }

  Expense copyWith({
    String? id,
    String? groupId,
    String? description,
    String? title,
    String? note,
    ExpenseCategory? category,
    int? totalPaise,
    int? amount,
    DateTime? date,
    List<PayerShare>? payers,
    String? paidBy,
    SplitMode? splitMode,
    Map<String, num>? splitParameters,
    List<String>? participants,
    Map<String, int>? computedShares,
    Map<String, int>? shares,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? isDeleted,
    List<ExpenseRevision>? revisions,
    ExpenseSource? source,
    String? bankRef,
  }) {
    DateTime? effectiveDeletedAt = deletedAt ?? this.deletedAt;
    if (isDeleted != null) {
      effectiveDeletedAt = isDeleted ? (effectiveDeletedAt ?? DateTime.now()) : null;
    }

    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? title ?? this.description,
      note: note ?? this.note,
      category: category ?? this.category,
      totalPaise: totalPaise ?? amount ?? this.totalPaise,
      date: date ?? this.date,
      payers: payers ??
          (paidBy != null
              ? [PayerShare(personId: paidBy, paise: totalPaise ?? amount ?? this.totalPaise)]
              : this.payers),
      splitMode: splitMode ?? this.splitMode,
      splitParameters: splitParameters ?? this.splitParameters,
      participants: participants ?? this.participants,
      computedShares: computedShares ?? shares ?? this.computedShares,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: effectiveDeletedAt,
      revisions: revisions ?? this.revisions,
      source: source ?? this.source,
      bankRef: bankRef ?? this.bankRef,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'description': description,
        if (note != null) 'note': note,
        'category': category.name,
        'totalPaise': totalPaise,
        'date': date.toIso8601String(),
        'payers': payers.map((p) => p.toJson()).toList(),
        'splitMode': splitMode.name,
        if (splitParameters != null) 'splitParameters': splitParameters,
        'participants': participants,
        'computedShares': computedShares,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
        'revisions': revisions.map((r) => r.toJson()).toList(),
        'source': source.name,
        if (bankRef != null) 'bankRef': bankRef,
      };

  factory Expense.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category'] as String? ?? 'other';
    final category = ExpenseCategory.values.firstWhere(
      (e) => e.name == categoryStr,
      orElse: () => ExpenseCategory.other,
    );
    final splitModeStr = json['splitMode'] as String? ?? 'equal';
    final splitMode = SplitMode.values.firstWhere(
      (e) => e.name == splitModeStr,
      orElse: () => SplitMode.equal,
    );
    final sourceStr = json['source'] as String? ?? 'manual';
    final source = ExpenseSource.values.firstWhere(
      (e) => e.name == sourceStr,
      orElse: () => ExpenseSource.manual,
    );

    final totalPaise = (json['totalPaise'] as int?) ?? (json['amount'] as int?) ?? 0;

    List<PayerShare> payers = [];
    if (json['payers'] != null) {
      payers = (json['payers'] as List<dynamic>)
          .map((p) => PayerShare.fromJson(p as Map<String, dynamic>))
          .toList();
    } else if (json['paidBy'] != null) {
      payers = [PayerShare(personId: json['paidBy'] as String, paise: totalPaise)];
    }

    Map<String, int> computedShares = {};
    if (json['computedShares'] != null) {
      computedShares = (json['computedShares'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      );
    } else if (json['shares'] != null) {
      computedShares = (json['shares'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      );
    }

    final participants = (json['participants'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        computedShares.keys.toList();

    final revisions = (json['revisions'] as List<dynamic>?)
            ?.map((r) => ExpenseRevision.fromJson(r as Map<String, dynamic>))
            .toList() ??
        const [];

    return Expense(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      description: (json['description'] as String?) ?? (json['title'] as String?) ?? '',
      note: json['note'] as String?,
      category: category,
      totalPaise: totalPaise,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      payers: payers,
      splitMode: splitMode,
      splitParameters: (json['splitParameters'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as num),
      ),
      participants: participants,
      computedShares: computedShares,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'] as String) : null,
      revisions: revisions,
      source: source,
      bankRef: json['bankRef'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupId == other.groupId &&
          description == other.description &&
          note == other.note &&
          category == other.category &&
          totalPaise == other.totalPaise &&
          date == other.date &&
          listEquals(payers, other.payers) &&
          splitMode == other.splitMode &&
          listEquals(participants, other.participants) &&
          mapEquals(computedShares, other.computedShares) &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt &&
          deletedAt == other.deletedAt &&
          listEquals(revisions, other.revisions) &&
          source == other.source &&
          bankRef == other.bankRef;

  @override
  int get hashCode =>
      id.hashCode ^
      groupId.hashCode ^
      description.hashCode ^
      note.hashCode ^
      category.hashCode ^
      totalPaise.hashCode ^
      date.hashCode ^
      Object.hashAll(payers) ^
      splitMode.hashCode ^
      Object.hashAll(participants) ^
      Object.hashAll(computedShares.entries) ^
      createdAt.hashCode ^
      updatedAt.hashCode ^
      deletedAt.hashCode ^
      Object.hashAll(revisions) ^
      source.hashCode ^
      bankRef.hashCode;
}
