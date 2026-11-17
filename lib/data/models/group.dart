import 'package:flutter/foundation.dart';

enum GroupType { home, trip }

enum GroupCoverType { flatmates, goaTrip }

@immutable
class Group {
  final String id;
  final String name;
  final GroupType type;
  final List<String> memberIds;
  final GroupCoverType coverType;
  final DateTime? startDate;
  final DateTime? endDate;

  const Group({
    required this.id,
    required this.name,
    required this.type,
    required this.memberIds,
    required this.coverType,
    this.startDate,
    this.endDate,
  });

  Group copyWith({
    String? id,
    String? name,
    GroupType? type,
    List<String>? memberIds,
    GroupCoverType? coverType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      memberIds: memberIds ?? this.memberIds,
      coverType: coverType ?? this.coverType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
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
          coverType == other.coverType &&
          startDate == other.startDate &&
          endDate == other.endDate;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      type.hashCode ^
      Object.hashAll(memberIds) ^
      coverType.hashCode ^
      startDate.hashCode ^
      endDate.hashCode;
}
