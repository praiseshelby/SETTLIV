import 'package:flutter/foundation.dart';

enum GroupMemberRole {
  owner('owner', 'Owner'),
  admin('admin', 'Admin'),
  member('member', 'Member');

  final String dbValue;
  final String label;
  const GroupMemberRole(this.dbValue, this.label);

  static GroupMemberRole fromDb(String? value) {
    switch (value) {
      case 'owner':
        return GroupMemberRole.owner;
      case 'admin':
        return GroupMemberRole.admin;
      default:
        return GroupMemberRole.member;
    }
  }
}

enum GroupInviteStatus {
  pending('pending'),
  accepted('accepted'),
  declined('declined'),
  cancelled('cancelled'),
  expired('expired');

  final String dbValue;
  const GroupInviteStatus(this.dbValue);

  static GroupInviteStatus fromDb(String? value) {
    return GroupInviteStatus.values.firstWhere(
      (e) => e.dbValue == value,
      orElse: () => GroupInviteStatus.pending,
    );
  }
}

@immutable
class GroupMemberInfo {
  final String groupId;
  final String userId;
  final GroupMemberRole role;
  final DateTime joinedAt;
  final String displayName;
  final String? username;
  final String avatarKind;
  final String? avatarRef;

  const GroupMemberInfo({
    required this.groupId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.displayName,
    this.username,
    this.avatarKind = 'initials',
    this.avatarRef,
  });

  bool get isAdminOrOwner =>
      role == GroupMemberRole.owner || role == GroupMemberRole.admin;
}

@immutable
class GroupInvite {
  final String id;
  final String groupId;
  final String groupName;
  final String inviterId;
  final String inviterName;
  final String inviteeId;
  final GroupInviteStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.inviterId,
    required this.inviterName,
    required this.inviteeId,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  bool isExpiredAt(DateTime now) =>
      status == GroupInviteStatus.expired ||
      (status == GroupInviteStatus.pending && expiresAt.isBefore(now));
}

@immutable
class UserSearchHit {
  final String id;
  final String displayName;
  final String username;
  final String avatarKind;
  final String? avatarRef;

  const UserSearchHit({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarKind = 'initials',
    this.avatarRef,
  });
}

class SharingException implements Exception {
  final String message;
  const SharingException(this.message);

  @override
  String toString() => message;
}
