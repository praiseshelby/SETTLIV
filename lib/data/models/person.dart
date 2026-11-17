import 'package:flutter/foundation.dart';

@immutable
class Person {
  final String id;
  final String name;
  final String avatarInitials;
  final int avatarPairIndex; // 0..7 index for AppColors.avatarGradients

  const Person({
    required this.id,
    required this.name,
    required this.avatarInitials,
    this.avatarPairIndex = 0,
  });

  Person copyWith({
    String? id,
    String? name,
    String? avatarInitials,
    int? avatarPairIndex,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarPairIndex: avatarPairIndex ?? this.avatarPairIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          avatarInitials == other.avatarInitials &&
          avatarPairIndex == other.avatarPairIndex;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      avatarInitials.hashCode ^
      avatarPairIndex.hashCode;
}
