import 'dart:math' as math;
import 'package:flutter/foundation.dart';

@immutable
class Person {
  final String id;
  final String name;
  final String? upiId;
  final String? phone;
  final String avatarInitials;
  final int avatarPairIndex; // 0..7 index for theme.avatarGradients
  final String avatarKind; // 'initials' | 'stock' | 'upload'
  final String? avatarRef;
  final String? linkedUserId;

  const Person({
    required this.id,
    required this.name,
    this.upiId,
    this.phone,
    this.avatarInitials = '',
    this.avatarPairIndex = 0,
    this.avatarKind = 'initials',
    this.avatarRef,
    this.linkedUserId,
  });

  String get initials {
    if (avatarInitials.isNotEmpty) return avatarInitials;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '??';
    return trimmed.substring(0, math.min(2, trimmed.length)).toUpperCase();
  }

  Person copyWith({
    String? id,
    String? name,
    String? upiId,
    String? phone,
    String? avatarInitials,
    int? avatarPairIndex,
    String? avatarKind,
    String? avatarRef,
    String? linkedUserId,
    bool clearAvatarRef = false,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      upiId: upiId ?? this.upiId,
      phone: phone ?? this.phone,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarPairIndex: avatarPairIndex ?? this.avatarPairIndex,
      avatarKind: avatarKind ?? this.avatarKind,
      avatarRef: clearAvatarRef ? null : (avatarRef ?? this.avatarRef),
      linkedUserId: linkedUserId ?? this.linkedUserId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (upiId != null) 'upiId': upiId,
        if (phone != null) 'phone': phone,
        'avatarInitials': avatarInitials,
        'avatarPairIndex': avatarPairIndex,
        'avatarKind': avatarKind,
        if (avatarRef != null) 'avatarRef': avatarRef,
      };

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      name: json['name'] as String,
      upiId: json['upiId'] as String?,
      phone: json['phone'] as String?,
      avatarInitials: (json['avatarInitials'] as String?) ?? '',
      avatarPairIndex: (json['avatarPairIndex'] as int?) ?? 0,
      avatarKind: (json['avatarKind'] as String?) ?? 'initials',
      avatarRef: json['avatarRef'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Person &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          upiId == other.upiId &&
          phone == other.phone &&
          avatarInitials == other.avatarInitials &&
          avatarPairIndex == other.avatarPairIndex;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      upiId.hashCode ^
      phone.hashCode ^
      avatarInitials.hashCode ^
      avatarPairIndex.hashCode;
}
