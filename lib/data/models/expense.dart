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
  percent('Percent');

  final String label;
  const SplitMode(this.label);
}

@immutable
class Expense {
  final String id;
  final String groupId;
  final String title;
  final ExpenseCategory category;
  final int amount; // in paise
  final DateTime date;
  final String paidBy; // Person id
  final SplitMode splitMode;
  final Map<String, int> shares; // Person id -> paise
  final bool isDeleted;

  const Expense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.paidBy,
    required this.splitMode,
    required this.shares,
    this.isDeleted = false,
  });

  Expense copyWith({
    String? id,
    String? groupId,
    String? title,
    ExpenseCategory? category,
    int? amount,
    DateTime? date,
    String? paidBy,
    SplitMode? splitMode,
    Map<String, int>? shares,
    bool? isDeleted,
  }) {
    return Expense(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paidBy: paidBy ?? this.paidBy,
      splitMode: splitMode ?? this.splitMode,
      shares: shares ?? this.shares,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Expense &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupId == other.groupId &&
          title == other.title &&
          category == other.category &&
          amount == other.amount &&
          date == other.date &&
          paidBy == other.paidBy &&
          splitMode == other.splitMode &&
          mapEquals(shares, other.shares) &&
          isDeleted == other.isDeleted;

  @override
  int get hashCode =>
      id.hashCode ^
      groupId.hashCode ^
      title.hashCode ^
      category.hashCode ^
      amount.hashCode ^
      date.hashCode ^
      paidBy.hashCode ^
      splitMode.hashCode ^
      Object.hashAll(shares.entries) ^
      isDeleted.hashCode;
}
