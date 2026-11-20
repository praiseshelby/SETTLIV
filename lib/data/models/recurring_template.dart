import 'package:flutter/foundation.dart';
import 'expense.dart';

enum RecurringFrequency {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly'),
  yearly('Yearly');

  final String label;
  const RecurringFrequency(this.label);
}

@immutable
class RecurringTemplate {
  final String id;
  final String groupId;
  final String description;
  final String? note;
  final ExpenseCategory category;
  final int totalPaise;
  final List<PayerShare> payers;
  final SplitMode splitMode;
  final Map<String, num>? splitParameters;
  final List<String> participants;
  final RecurringFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isPaused;
  final DateTime? lastGeneratedDate;
  final DateTime createdAt;

  const RecurringTemplate({
    required this.id,
    required this.groupId,
    required this.description,
    this.note,
    required this.category,
    required this.totalPaise,
    required this.payers,
    required this.splitMode,
    this.splitParameters,
    required this.participants,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.isPaused = false,
    this.lastGeneratedDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? startDate;

  RecurringTemplate copyWith({
    String? id,
    String? groupId,
    String? description,
    String? note,
    ExpenseCategory? category,
    int? totalPaise,
    List<PayerShare>? payers,
    SplitMode? splitMode,
    Map<String, num>? splitParameters,
    List<String>? participants,
    RecurringFrequency? frequency,
    DateTime? startDate,
    DateTime? endDate,
    bool? isPaused,
    DateTime? lastGeneratedDate,
    DateTime? createdAt,
  }) {
    return RecurringTemplate(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      note: note ?? this.note,
      category: category ?? this.category,
      totalPaise: totalPaise ?? this.totalPaise,
      payers: payers ?? this.payers,
      splitMode: splitMode ?? this.splitMode,
      splitParameters: splitParameters ?? this.splitParameters,
      participants: participants ?? this.participants,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isPaused: isPaused ?? this.isPaused,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'groupId': groupId,
        'description': description,
        if (note != null) 'note': note,
        'category': category.name,
        'totalPaise': totalPaise,
        'payers': payers.map((p) => p.toJson()).toList(),
        'splitMode': splitMode.name,
        if (splitParameters != null) 'splitParameters': splitParameters,
        'participants': participants,
        'frequency': frequency.name,
        'startDate': startDate.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
        'isPaused': isPaused,
        if (lastGeneratedDate != null) 'lastGeneratedDate': lastGeneratedDate!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory RecurringTemplate.fromJson(Map<String, dynamic> json) {
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
    final frequencyStr = json['frequency'] as String? ?? 'monthly';
    final frequency = RecurringFrequency.values.firstWhere(
      (e) => e.name == frequencyStr,
      orElse: () => RecurringFrequency.monthly,
    );

    return RecurringTemplate(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      description: json['description'] as String? ?? '',
      note: json['note'] as String?,
      category: category,
      totalPaise: json['totalPaise'] as int? ?? 0,
      payers: (json['payers'] as List<dynamic>?)
              ?.map((p) => PayerShare.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
      splitMode: splitMode,
      splitParameters: (json['splitParameters'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as num),
      ),
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      frequency: frequency,
      startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
      isPaused: json['isPaused'] as bool? ?? false,
      lastGeneratedDate: json['lastGeneratedDate'] != null
          ? DateTime.tryParse(json['lastGeneratedDate'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupId == other.groupId &&
          description == other.description &&
          note == other.note &&
          category == other.category &&
          totalPaise == other.totalPaise &&
          listEquals(payers, other.payers) &&
          splitMode == other.splitMode &&
          listEquals(participants, other.participants) &&
          frequency == other.frequency &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          isPaused == other.isPaused &&
          lastGeneratedDate == other.lastGeneratedDate &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      groupId.hashCode ^
      description.hashCode ^
      note.hashCode ^
      category.hashCode ^
      totalPaise.hashCode ^
      Object.hashAll(payers) ^
      splitMode.hashCode ^
      Object.hashAll(participants) ^
      frequency.hashCode ^
      startDate.hashCode ^
      endDate.hashCode ^
      isPaused.hashCode ^
      lastGeneratedDate.hashCode ^
      createdAt.hashCode;
}
