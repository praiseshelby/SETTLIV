import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_repository.dart';
import '../../supabase_config.dart';
import '../models/expense.dart';
import '../models/group.dart';
import '../models/person.dart';
import '../models/settlement.dart';
import '../models/sharing_models.dart';
import 'app_repository.dart';
import 'in_memory_app_repository.dart';

abstract class SharingRepository {
  Future<List<UserSearchHit>> searchUsersForInvite(String query);
  Future<String> inviteUser({
    required String groupId,
    required String inviteeId,
  });
  Future<List<GroupInvite>> getIncomingInvites();
  Future<List<GroupInvite>> getGroupPendingInvites(String groupId);
  Future<String> respondToInvite({
    required String inviteId,
    required bool accept,
  });
  Future<void> cancelInvite(String inviteId);
  Future<String> joinByCode(String code);
  Future<String> regenerateJoinCode(String groupId);
  Future<void> setJoinCodeEnabled({
    required String groupId,
    required bool enabled,
  });
  Future<List<GroupMemberInfo>> getGroupMembers(String groupId);
  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
  });
  Future<void> leaveGroup(String groupId);
  Future<void> claimPlaceholder({
    required String groupId,
    required String placeholderId,
  });
  Future<bool> getAllowUsernameInvites();
  Future<void> setAllowUsernameInvites(bool allow);
}

class InMemorySharingRepository implements SharingRepository {
  static const String _codeAlphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

  final AppRepository? appRepository;
  final String currentUserId;
  final String currentUserName;
  final DateTime Function() _clock;
  final math.Random _rng = math.Random.secure();

  final Map<String, bool> _allowUsernameInvitesByUser = {};
  final List<UserSearchHit> _directoryUsers = [];
  final Map<String, List<GroupMemberInfo>> _membersByGroup = {};
  final List<GroupInvite> _invites = [];
  final Map<String, List<DateTime>> _failedJoinAttempts = {};
  int _idSeq = 1;

  InMemorySharingRepository({
    this.appRepository,
    required this.currentUserId,
    required this.currentUserName,
    DateTime Function()? clock,
    List<UserSearchHit> directoryUsers = const [],
  }) : _clock = clock ?? DateTime.now {
    _directoryUsers.addAll(directoryUsers);
  }

  void registerDirectoryUser(UserSearchHit user, {bool allowInvites = true}) {
    _directoryUsers.removeWhere((u) => u.id == user.id);
    _directoryUsers.add(user);
    _allowUsernameInvitesByUser[user.id] = allowInvites;
  }

  void seedGroupMembership({
    required String groupId,
    required String userId,
    required GroupMemberRole role,
    String? displayName,
    String? username,
  }) {
    final list = _membersByGroup.putIfAbsent(groupId, () => []);
    list.removeWhere((m) => m.userId == userId);
    list.add(
      GroupMemberInfo(
        groupId: groupId,
        userId: userId,
        role: role,
        joinedAt: _clock(),
        displayName: displayName ?? userId,
        username: username,
      ),
    );
  }

  void seedInvite(GroupInvite invite) {
    _invites.removeWhere((i) => i.id == invite.id);
    _invites.add(invite);
  }

  String generateJoinCode() {
    final existingCodes = (appRepository?.getGroups() ?? const <Group>[])
        .map((g) => g.joinCode)
        .whereType<String>()
        .toSet();
    while (true) {
      final buf = StringBuffer();
      for (var i = 0; i < 8; i++) {
        buf.write(_codeAlphabet[_rng.nextInt(_codeAlphabet.length)]);
      }
      final candidate = buf.toString();
      if (!existingCodes.contains(candidate)) {
        return candidate;
      }
    }
  }

  bool _isAdmin(String groupId) {
    final members = _membersByGroup[groupId] ?? const [];
    final me = members.where((m) => m.userId == currentUserId).firstOrNull;
    if (me != null) return me.isAdminOrOwner;
    final grp = appRepository?.getGroup(groupId);
    return grp != null && (grp.ownerId == null || grp.ownerId == currentUserId);
  }

  bool _isMember(String groupId) {
    final members = _membersByGroup[groupId] ?? const [];
    if (members.any((m) => m.userId == currentUserId)) return true;
    final grp = appRepository?.getGroup(groupId);
    return grp != null && grp.memberIds.contains(currentUserId);
  }

  @override
  Future<List<UserSearchHit>> searchUsersForInvite(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 3) return const [];
    final hits = _directoryUsers.where((u) {
      if (u.id == currentUserId) return false;
      if (!(_allowUsernameInvitesByUser[u.id] ?? true)) return false;
      return u.username.toLowerCase().startsWith(q);
    }).toList();
    hits.sort((a, b) {
      final aExact = a.username.toLowerCase() == q ? 0 : 1;
      final bExact = b.username.toLowerCase() == q ? 0 : 1;
      if (aExact != bExact) return aExact.compareTo(bExact);
      return a.username.compareTo(b.username);
    });
    return hits.take(5).toList();
  }

  @override
  Future<String> inviteUser({
    required String groupId,
    required String inviteeId,
  }) async {
    if (!_isMember(groupId)) {
      throw const SharingException('Only group members can send invites');
    }
    if (inviteeId == currentUserId) {
      throw const SharingException('You are already in this group');
    }
    final members = _membersByGroup[groupId] ?? const [];
    if (members.any((m) => m.userId == inviteeId)) {
      throw const SharingException('User is already a member of this group');
    }
    if (!(_allowUsernameInvitesByUser[inviteeId] ?? true)) {
      throw const SharingException('This user is not accepting username invites');
    }
    final now = _clock();
    final id = 'inv_${_idSeq++}';
    final groupName = appRepository?.getGroup(groupId)?.name ?? 'Group';
    _invites.add(
      GroupInvite(
        id: id,
        groupId: groupId,
        groupName: groupName,
        inviterId: currentUserId,
        inviterName: currentUserName,
        inviteeId: inviteeId,
        status: GroupInviteStatus.pending,
        createdAt: now,
        expiresAt: now.add(const Duration(days: 14)),
      ),
    );
    return id;
  }

  @override
  Future<List<GroupInvite>> getIncomingInvites() async {
    final now = _clock();
    return _invites
        .where((i) =>
            i.inviteeId == currentUserId &&
            i.status == GroupInviteStatus.pending &&
            !i.isExpiredAt(now))
        .toList();
  }

  @override
  Future<List<GroupInvite>> getGroupPendingInvites(String groupId) async {
    final now = _clock();
    return _invites
        .where((i) =>
            i.groupId == groupId &&
            i.status == GroupInviteStatus.pending &&
            !i.isExpiredAt(now))
        .toList();
  }

  @override
  Future<String> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final idx = _invites.indexWhere(
      (i) => i.id == inviteId && i.inviteeId == currentUserId,
    );
    if (idx == -1) {
      throw const SharingException('Invite not found');
    }
    final inv = _invites[idx];
    if (inv.status != GroupInviteStatus.pending) {
      throw const SharingException('Invite is no longer pending');
    }
    final now = _clock();
    if (inv.expiresAt.isBefore(now)) {
      _invites[idx] = GroupInvite(
        id: inv.id,
        groupId: inv.groupId,
        groupName: inv.groupName,
        inviterId: inv.inviterId,
        inviterName: inv.inviterName,
        inviteeId: inv.inviteeId,
        status: GroupInviteStatus.expired,
        createdAt: inv.createdAt,
        expiresAt: inv.expiresAt,
        respondedAt: now,
      );
      throw const SharingException('Invite has expired');
    }
    _invites[idx] = GroupInvite(
      id: inv.id,
      groupId: inv.groupId,
      groupName: inv.groupName,
      inviterId: inv.inviterId,
      inviterName: inv.inviterName,
      inviteeId: inv.inviteeId,
      status: accept ? GroupInviteStatus.accepted : GroupInviteStatus.declined,
      createdAt: inv.createdAt,
      expiresAt: inv.expiresAt,
      respondedAt: now,
    );

    if (accept) {
      seedGroupMembership(
        groupId: inv.groupId,
        userId: currentUserId,
        role: GroupMemberRole.member,
        displayName: currentUserName,
      );
      final grp = appRepository?.getGroup(inv.groupId);
      if (grp != null && !grp.memberIds.contains(currentUserId)) {
        appRepository?.updateGroup(
          grp.copyWith(memberIds: [...grp.memberIds, currentUserId]),
        );
      }
    }
    return inv.groupId;
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    final idx = _invites.indexWhere((i) => i.id == inviteId);
    if (idx == -1) {
      throw const SharingException('Invite not found');
    }
    final inv = _invites[idx];
    if (inv.inviterId != currentUserId && !_isAdmin(inv.groupId)) {
      throw const SharingException('Not allowed to cancel this invite');
    }
    if (inv.status == GroupInviteStatus.pending) {
      _invites[idx] = GroupInvite(
        id: inv.id,
        groupId: inv.groupId,
        groupName: inv.groupName,
        inviterId: inv.inviterId,
        inviterName: inv.inviterName,
        inviteeId: inv.inviteeId,
        status: GroupInviteStatus.cancelled,
        createdAt: inv.createdAt,
        expiresAt: inv.expiresAt,
        respondedAt: _clock(),
      );
    }
  }

  @override
  Future<String> joinByCode(String code) async {
    final now = _clock();
    final cutoff = now.subtract(const Duration(hours: 1));
    final attempts = _failedJoinAttempts.putIfAbsent(currentUserId, () => []);
    attempts.removeWhere((t) => t.isBefore(cutoff));
    if (attempts.length >= 10) {
      throw const SharingException(
        'Too many failed attempts. Try again in an hour.',
      );
    }

    final normalized = code.trim().toUpperCase();
    final groups = appRepository?.getGroups() ?? const <Group>[];
    final match = groups.where((g) {
      return !g.isPersonal &&
          g.joinCodeEnabled &&
          g.joinCode?.toUpperCase() == normalized;
    }).firstOrNull;

    if (match == null) {
      attempts.add(now);
      throw const SharingException('Invalid or disabled join code');
    }

    attempts.clear();
    seedGroupMembership(
      groupId: match.id,
      userId: currentUserId,
      role: GroupMemberRole.member,
      displayName: currentUserName,
    );
    if (!match.memberIds.contains(currentUserId)) {
      appRepository?.updateGroup(
        match.copyWith(memberIds: [...match.memberIds, currentUserId]),
      );
    }
    return match.id;
  }

  @override
  Future<String> regenerateJoinCode(String groupId) async {
    if (!_isAdmin(groupId)) {
      throw const SharingException('Only group admins can regenerate join codes');
    }
    final grp = appRepository?.getGroup(groupId);
    if (grp == null) {
      throw const SharingException('Group not found');
    }
    final nextCode = generateJoinCode();
    appRepository?.updateGroup(
      grp.copyWith(joinCode: nextCode, joinCodeEnabled: true),
    );
    return nextCode;
  }

  @override
  Future<void> setJoinCodeEnabled({
    required String groupId,
    required bool enabled,
  }) async {
    if (!_isAdmin(groupId)) {
      throw const SharingException('Only group admins can update join code settings');
    }
    final grp = appRepository?.getGroup(groupId);
    if (grp == null) {
      throw const SharingException('Group not found');
    }
    appRepository?.updateGroup(grp.copyWith(joinCodeEnabled: enabled));
  }

  @override
  Future<List<GroupMemberInfo>> getGroupMembers(String groupId) async {
    final existing = _membersByGroup[groupId];
    if (existing != null && existing.isNotEmpty) {
      return List.unmodifiable(existing);
    }
    final grp = appRepository?.getGroup(groupId);
    if (grp == null) return const [];
    return grp.memberIds.map((id) {
      final person = appRepository?.getPerson(id);
      return GroupMemberInfo(
        groupId: groupId,
        userId: id,
        role: id == (grp.ownerId ?? currentUserId)
            ? GroupMemberRole.owner
            : GroupMemberRole.member,
        joinedAt: grp.effectiveCreatedAt,
        displayName: person?.name ?? id,
        avatarKind: person?.avatarKind ?? 'initials',
        avatarRef: person?.avatarRef,
      );
    }).toList();
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    if (!_isAdmin(groupId)) {
      throw const SharingException('Only group admins can remove members');
    }
    final members = _membersByGroup[groupId] ?? [];
    final target = members.where((m) => m.userId == userId).firstOrNull;
    if (target?.role == GroupMemberRole.owner) {
      throw const SharingException('Group owner cannot be removed');
    }
    members.removeWhere((m) => m.userId == userId);
    final grp = appRepository?.getGroup(groupId);
    if (grp != null) {
      appRepository?.updateGroup(
        grp.copyWith(
          memberIds: grp.memberIds.where((id) => id != userId).toList(),
        ),
      );
    }
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    if (!_isMember(groupId)) {
      throw const SharingException('Not a member of this group');
    }
    if (appRepository != null) {
      final summary = appRepository!.getGroupSummary(groupId);
      final net = summary.netBalances[currentUserId] ?? 0;
      if (net != 0) {
        throw const SharingException(
          'Settle your remaining balance before leaving this group',
        );
      }
    }
    final members = _membersByGroup[groupId] ?? [];
    final me = members.where((m) => m.userId == currentUserId).firstOrNull;
    if (me?.role == GroupMemberRole.owner &&
        members.any((m) => m.userId != currentUserId)) {
      throw const SharingException(
        'Group owner cannot leave while other members remain',
      );
    }
    members.removeWhere((m) => m.userId == currentUserId);
    final grp = appRepository?.getGroup(groupId);
    if (grp != null) {
      appRepository?.updateGroup(
        grp.copyWith(
          memberIds: grp.memberIds.where((id) => id != currentUserId).toList(),
        ),
      );
    }
  }

  @override
  Future<void> claimPlaceholder({
    required String groupId,
    required String placeholderId,
  }) async {
    if (!_isMember(groupId)) {
      throw const SharingException(
        'Must be a member of the group to claim a placeholder',
      );
    }
    final repo = appRepository;
    if (repo == null) return;
    final grp = repo.getGroup(groupId);
    if (grp != null) {
      final nextIds = <String>[
        for (final id in grp.memberIds)
          if (id == placeholderId) currentUserId else id,
      ];
      if (!nextIds.contains(currentUserId)) {
        nextIds.add(currentUserId);
      }
      repo.updateGroup(grp.copyWith(memberIds: nextIds.toSet().toList()));
    }
    for (final exp in repo.getExpensesForGroup(groupId)) {
      final nextPayers = exp.payers
          .map((p) => p.personId == placeholderId
              ? PayerShare(personId: currentUserId, paise: p.paise)
              : p)
          .toList();
      final nextShares = <String, int>{};
      for (final entry in exp.shares.entries) {
        final k = entry.key == placeholderId ? currentUserId : entry.key;
        nextShares[k] = (nextShares[k] ?? 0) + entry.value;
      }
      repo.updateExpense(
        exp.copyWith(payers: nextPayers, shares: nextShares),
      );
    }
    for (final s in repo.getSettlementsForGroup(groupId)) {
      if (s.from == placeholderId || s.to == placeholderId) {
        repo.deleteSettlement(s.id);
        repo.addSettlement(
          Settlement(
            id: s.id,
            groupId: s.groupId,
            from: s.from == placeholderId ? currentUserId : s.from,
            to: s.to == placeholderId ? currentUserId : s.to,
            paise: s.paise,
            method: s.method,
            date: s.date,
            note: s.note,
          ),
        );
      }
    }
    final person = repo.getPerson(placeholderId);
    if (person != null) {
      repo.updatePerson(person.copyWith(linkedUserId: currentUserId));
    }
  }

  @override
  Future<bool> getAllowUsernameInvites() async {
    return _allowUsernameInvitesByUser[currentUserId] ?? true;
  }

  @override
  Future<void> setAllowUsernameInvites(bool allow) async {
    _allowUsernameInvitesByUser[currentUserId] = allow;
  }
}

class SupabaseSharingRepository implements SharingRepository {
  final SupabaseClient _client;
  final String _uid;
  final AppRepository _appRepository;

  SupabaseSharingRepository({
    required SupabaseClient client,
    required String uid,
    required AppRepository appRepository,
  })  : _client = client,
        _uid = uid,
        _appRepository = appRepository;

  SharingException _mapError(Object error, String fallback) {
    if (error is PostgrestException) {
      final msg = error.message;
      if (msg.contains('Could not find the function') ||
          msg.contains('does not exist')) {
        return const SharingException(
          'Sharing setup is not complete yet on the server. Apply migration 004 first.',
        );
      }
      return SharingException(msg.isNotEmpty ? msg : fallback);
    }
    return SharingException(fallback);
  }

  @override
  Future<List<UserSearchHit>> searchUsersForInvite(String query) async {
    if (query.trim().length < 3) return const [];
    try {
      final rows = await _client.rpc(
        'rpc_search_users_for_invite',
        params: {'p_query': query.trim()},
      );
      if (rows is! List) return const [];
      return rows
          .map((r) => UserSearchHit(
                id: r['id'] as String,
                displayName: (r['display_name'] as String?) ?? 'User',
                username: (r['username'] as String?) ?? '',
                avatarKind: (r['avatar_kind'] as String?) ?? 'initials',
                avatarRef: r['avatar_ref'] as String?,
              ))
          .toList();
    } catch (e) {
      throw _mapError(e, 'Could not search users right now');
    }
  }

  @override
  Future<String> inviteUser({
    required String groupId,
    required String inviteeId,
  }) async {
    try {
      final res = await _client.rpc(
        'rpc_invite_user',
        params: {'p_group_id': groupId, 'p_invitee_id': inviteeId},
      );
      return res.toString();
    } catch (e) {
      throw _mapError(e, 'Could not send invite');
    }
  }

  @override
  Future<List<GroupInvite>> getIncomingInvites() async {
    try {
      final rows = await _client
          .from('group_invites')
          .select()
          .eq('invitee_id', _uid)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return _parseInvites(rows as List);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<GroupInvite>> getGroupPendingInvites(String groupId) async {
    try {
      final rows = await _client
          .from('group_invites')
          .select()
          .eq('group_id', groupId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return _parseInvites(rows as List);
    } catch (_) {
      return const [];
    }
  }

  List<GroupInvite> _parseInvites(List rows) {
    return rows.map((r) {
      final gid = r['group_id'] as String;
      final grp = _appRepository.getGroup(gid);
      final inviter = _appRepository.getPerson(r['inviter_id'] as String);
      return GroupInvite(
        id: r['id'].toString(),
        groupId: gid,
        groupName: grp?.name ?? 'Shared group',
        inviterId: r['inviter_id'] as String,
        inviterName: inviter?.name ?? 'Group member',
        inviteeId: r['invitee_id'] as String,
        status: GroupInviteStatus.fromDb(r['status'] as String?),
        createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
            DateTime.now(),
        expiresAt: DateTime.tryParse(r['expires_at']?.toString() ?? '') ??
            DateTime.now().add(const Duration(days: 14)),
        respondedAt: r['responded_at'] != null
            ? DateTime.tryParse(r['responded_at'].toString())
            : null,
      );
    }).toList();
  }

  @override
  Future<String> respondToInvite({
    required String inviteId,
    required bool accept,
  }) async {
    try {
      final res = await _client.rpc(
        'rpc_respond_invite',
        params: {'p_invite_id': inviteId, 'p_accept': accept},
      );
      return res.toString();
    } catch (e) {
      throw _mapError(e, 'Could not respond to invite');
    }
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    try {
      await _client.rpc(
        'rpc_cancel_invite',
        params: {'p_invite_id': inviteId},
      );
    } catch (e) {
      throw _mapError(e, 'Could not cancel invite');
    }
  }

  @override
  Future<String> joinByCode(String code) async {
    try {
      final res = await _client.rpc(
        'rpc_join_by_code',
        params: {'p_code': code.trim().toUpperCase()},
      );
      return res.toString();
    } catch (e) {
      throw _mapError(e, 'Could not join group');
    }
  }

  @override
  Future<String> regenerateJoinCode(String groupId) async {
    try {
      final res = await _client.rpc(
        'rpc_regenerate_join_code',
        params: {'p_group_id': groupId},
      );
      return res.toString();
    } catch (e) {
      throw _mapError(e, 'Could not regenerate join code');
    }
  }

  @override
  Future<void> setJoinCodeEnabled({
    required String groupId,
    required bool enabled,
  }) async {
    try {
      await _client.rpc(
        'rpc_set_join_code_enabled',
        params: {'p_group_id': groupId, 'p_enabled': enabled},
      );
    } catch (e) {
      throw _mapError(e, 'Could not update join code setting');
    }
  }

  @override
  Future<List<GroupMemberInfo>> getGroupMembers(String groupId) async {
    try {
      final rows = await _client
          .from('group_members')
          .select('group_id, user_id, role, joined_at')
          .eq('group_id', groupId);
      return (rows as List).map((r) {
        final uid = r['user_id'] as String;
        final p = _appRepository.getPerson(uid);
        return GroupMemberInfo(
          groupId: r['group_id'] as String,
          userId: uid,
          role: GroupMemberRole.fromDb(r['role'] as String?),
          joinedAt: DateTime.tryParse(r['joined_at']?.toString() ?? '') ??
              DateTime.now(),
          displayName: p?.name ?? (uid == _uid ? 'You' : 'Member'),
          avatarKind: p?.avatarKind ?? 'initials',
          avatarRef: p?.avatarRef,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> removeGroupMember({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _client.rpc(
        'rpc_remove_group_member',
        params: {'p_group_id': groupId, 'p_user_id': userId},
      );
    } catch (e) {
      throw _mapError(e, 'Could not remove member');
    }
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final summary = _appRepository.getGroupSummary(groupId);
    final net = summary.netBalances[_uid] ?? 0;
    if (net != 0) {
      throw const SharingException(
        'Settle your remaining balance before leaving this group',
      );
    }
    try {
      await _client.rpc(
        'rpc_leave_group',
        params: {'p_group_id': groupId},
      );
    } catch (e) {
      throw _mapError(e, 'Could not leave group');
    }
  }

  @override
  Future<void> claimPlaceholder({
    required String groupId,
    required String placeholderId,
  }) async {
    try {
      await _client.rpc(
        'rpc_claim_placeholder',
        params: {'p_group_id': groupId, 'p_placeholder_id': placeholderId},
      );
    } catch (e) {
      throw _mapError(e, 'Could not claim placeholder member');
    }
  }

  @override
  Future<bool> getAllowUsernameInvites() async {
    try {
      final row = await _client
          .from('profiles')
          .select('allow_username_invites')
          .eq('id', _uid)
          .maybeSingle();
      return (row?['allow_username_invites'] as bool?) ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> setAllowUsernameInvites(bool allow) async {
    try {
      await _client
          .from('profiles')
          .update({'allow_username_invites': allow})
          .eq('id', _uid);
    } catch (e) {
      throw _mapError(e, 'Could not update username invite preference');
    }
  }
}

final sharingVersionProvider = StateProvider<int>((ref) => 0);

final sharingRepositoryProvider = Provider<SharingRepository>((ref) {
  final authStatus = ref.watch(authStateProvider);
  final appRepo = ref.watch(appRepositoryProvider);
  if (authStatus is AuthSignedIn &&
      SupabaseConfig.isSupabaseConfigured &&
      SupabaseConfig.isInitialized) {
    return SupabaseSharingRepository(
      client: Supabase.instance.client,
      uid: authStatus.user.id,
      appRepository: appRepo,
    );
  }
  return InMemorySharingRepository(
    appRepository: appRepo,
    currentUserId: appRepo.currentUserId,
    currentUserName: appRepo.currentUser?.name ?? 'You',
  );
});

final incomingInvitesProvider = FutureProvider<List<GroupInvite>>((ref) async {
  ref.watch(sharingVersionProvider);
  ref.watch(appStateProvider);
  final repo = ref.watch(sharingRepositoryProvider);
  return repo.getIncomingInvites();
});
