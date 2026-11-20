import 'package:flutter/foundation.dart';

enum GroupType {
  home('Home'),
  trip('Trip'),
  other('Other');

  final String label;
  const GroupType(this.label);
}

enum GroupCoverType { flatmates, goaTrip, generic }

@immutable
class Group {
  final String id;
  final String name;
  final GroupType type;
  final List<String> memberIds;
  final int coverThemeIndex; // 0..5 index into theme.coverThemePalettes
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? startDate;
  final DateTime? endDate;

  const Group({
    required this.id,
    required this.name,
    required this.type,
    required this.memberIds,
    this.coverThemeIndex = 0,
    this.isArchived = false,
    this.createdAt,
    this.startDate,
    this.endDate,
    GroupCoverType? coverType,
  }) : assert(coverThemeIndex >= 0 && coverThemeIndex < 6);

  DateTime get effectiveCreatedAt => createdAt ?? startDate ?? DateTime(2024, 1, 1);

  GroupCoverType get coverType {
    if (coverThemeIndex == 0) return GroupCoverType.flatmates;
    if (coverThemeIndex == 1) return GroupCoverType.goaTrip;
    return GroupCoverType.generic;
  }

  bool get isPersonal => id == 'group_personal';

  Group copyWith({
    String? id,
    String? name,
    GroupType? type,
    List<String>? memberIds,
    int? coverThemeIndex,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? endDate,
    GroupCoverType? coverType,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      memberIds: memberIds ?? this.memberIds,
      coverThemeIndex: coverThemeIndex ??
          (coverType != null
              ? (coverType == GroupCoverType.flatmates ? 0 : (coverType == GroupCoverType.goaTrip ? 1 : 2))
              : this.coverThemeIndex),
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'memberIds': memberIds,
        'coverThemeIndex': coverThemeIndex,
        'isArchived': isArchived,
        'createdAt': effectiveCreatedAt.toIso8601String(),
        if (startDate != null) 'startDate': startDate!.toIso8601String(),
        if (endDate != null) 'endDate': endDate!.toIso8601String(),
      };

  factory Group.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'other';
    final type = GroupType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => GroupType.other,
    );
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      memberIds: (json['memberIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      coverThemeIndex: (json['coverThemeIndex'] as int?) ?? 0,
      isArchived: (json['isArchived'] as bool?) ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime(2024, 1, 1)
          : DateTime(2024, 1, 1),
      startDate: json['startDate'] != null ? DateTime.tryParse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          type == other.type &&
          listEquals(memberIds, other.memberIds) &&
          coverThemeIndex == other.coverThemeIndex &&
          isArchived == other.isArchived &&
          createdAt == other.createdAt &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      Object.hashAll(memberIds) ^
      coverThemeIndex.hashCode ^
      isArchived.hashCode ^
      createdAt.hashCode ^
      startDate.hashCode ^
      endDate.hashCode;
}
