import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/adaptive_presenter.dart';
import '../../../core/widgets/form_sheet_scaffold.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/models/sharing_models.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../../data/repositories/sharing_repository.dart';

class GroupSharingSheet extends ConsumerStatefulWidget {
  final Group group;

  const GroupSharingSheet({
    super.key,
    required this.group,
  });

  static Future<void> show({
    required BuildContext context,
    required Group group,
  }) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: 'Members & sharing',
      isScrollControlled: true,
      child: GroupSharingSheet(group: group),
    );
  }

  @override
  ConsumerState<GroupSharingSheet> createState() => _GroupSharingSheetState();
}

class _GroupSharingSheetState extends ConsumerState<GroupSharingSheet> {
  final TextEditingController _searchController = TextEditingController();

  List<GroupMemberInfo> _members = const [];
  List<GroupInvite> _pendingInvites = const [];
  List<UserSearchHit> _searchHits = const [];
  bool _loading = true;
  bool _busy = false;
  bool _searching = false;
  bool _copiedCode = false;
  String? _error;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sharing = ref.read(sharingRepositoryProvider);
      final results = await Future.wait([
        sharing.getGroupMembers(widget.group.id),
        sharing.getGroupPendingInvites(widget.group.id),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<GroupMemberInfo>;
        _pendingInvites = results[1] as List<GroupInvite>;
      });
    } on SharingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load sharing details');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onSearchChanged(String raw) async {
    final q = raw.trim();
    if (q.length < 3) {
      setState(() {
        _searchHits = const [];
        _searching = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final hits =
          await ref.read(sharingRepositoryProvider).searchUsersForInvite(q);
      if (mounted) setState(() => _searchHits = hits);
    } on SharingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Search failed. Try again.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _statusMessage = null;
    });
    try {
      await action();
      ref.read(sharingVersionProvider.notifier).state++;
      await _load();
    } on SharingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Action failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final group = ref.watch(groupProvider(widget.group.id)) ?? widget.group;
    final currentUserId = ref.watch(appRepositoryProvider).currentUserId;
    final me = _members.where((m) => m.userId == currentUserId).firstOrNull;
    final isAdmin = me?.isAdminOrOwner ??
        (group.ownerId == null || group.ownerId == currentUserId);

    return FormSheetScaffold(
      bottomBar: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _runBusy(() async {
                          await ref
                              .read(sharingRepositoryProvider)
                              .leaveGroup(group.id);
                          ref.read(appStateProvider.notifier).notifyChange();
                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true).pop();
                          }
                        }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.textCoral,
                  side: BorderSide(color: theme.textCoral),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Leave group',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PrimaryButton(
              label: 'Done',
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.coralTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: AppTypography.caption.copyWith(
                  color: theme.textCoral,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.emeraldTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _statusMessage!,
                style: AppTypography.caption.copyWith(
                  color: theme.textEmerald,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Join Code Section
          Text(
            'JOIN CODE',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 16,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.joinCodeEnabled
                            ? (group.joinCode ?? 'Not generated')
                            : 'Join code disabled',
                        style: AppTypography.titleLarge.copyWith(
                          color: group.joinCodeEnabled ? theme.ink : theme.muted,
                          letterSpacing: group.joinCodeEnabled ? 2.0 : 0,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (group.joinCodeEnabled && group.joinCode != null)
                      IconButton(
                        tooltip: 'Copy join code',
                        icon: Icon(
                          _copiedCode ? Icons.check_rounded : Icons.copy_rounded,
                          color: _copiedCode ? theme.textEmerald : theme.ink,
                        ),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: group.joinCode!),
                          );
                          setState(() => _copiedCode = true);
                        },
                      ),
                  ],
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _runBusy(() async {
                                  final code = await ref
                                      .read(sharingRepositoryProvider)
                                      .regenerateJoinCode(group.id);
                                  ref
                                      .read(appStateProvider.notifier)
                                      .notifyChange();
                                  _statusMessage = 'New join code: $code';
                                }),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Regenerate'),
                      ),
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _runBusy(() async {
                                  await ref
                                      .read(sharingRepositoryProvider)
                                      .setJoinCodeEnabled(
                                        groupId: group.id,
                                        enabled: !group.joinCodeEnabled,
                                      );
                                  ref
                                      .read(appStateProvider.notifier)
                                      .notifyChange();
                                }),
                        icon: Icon(
                          group.joinCodeEnabled
                              ? Icons.link_off_rounded
                              : Icons.link_rounded,
                          size: 16,
                        ),
                        label: Text(
                          group.joinCodeEnabled ? 'Disable' : 'Enable',
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Invite by Username
          Text(
            'INVITE BY USERNAME',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: AppTypography.body.copyWith(color: theme.ink),
            decoration: InputDecoration(
              hintText: 'Type at least 3 characters of username...',
              hintStyle: AppTypography.body.copyWith(color: theme.muted),
              prefixIcon: Icon(Icons.alternate_email_rounded, color: theme.muted),
              filled: true,
              fillColor: theme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
            ),
          ),
          if (_searching)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          for (final hit in _searchHits) ...[
            const SizedBox(height: 8),
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  PersonAvatar(
                    person: Person(
                      id: hit.id,
                      name: hit.displayName,
                      avatarKind: hit.avatarKind,
                      avatarRef: hit.avatarRef,
                    ),
                    size: 36,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hit.displayName,
                          style: AppTypography.bodySemiBold
                              .copyWith(color: theme.ink),
                        ),
                        Text(
                          '@${hit.username}',
                          style: AppTypography.caption
                              .copyWith(color: theme.muted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _runBusy(() async {
                              await ref
                                  .read(sharingRepositoryProvider)
                                  .inviteUser(
                                    groupId: group.id,
                                    inviteeId: hit.id,
                                  );
                              _statusMessage = 'Invited @${hit.username}';
                              _searchController.clear();
                              _searchHits = const [];
                            }),
                    child: const Text('Invite'),
                  ),
                ],
              ),
            ),
          ],

          if (_pendingInvites.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'PENDING INVITES',
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            for (final inv in _pendingInvites)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassSurface(
                  level: GlassLevel.level1,
                  borderRadius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Invited by ${inv.inviterName}',
                          style: AppTypography.body.copyWith(color: theme.ink),
                        ),
                      ),
                      if (isAdmin || inv.inviterId == currentUserId)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _runBusy(() => ref
                                  .read(sharingRepositoryProvider)
                                  .cancelInvite(inv.id)),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: theme.textCoral),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: 20),
          Text(
            'MEMBERS (${_members.length})',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            for (final member in _members)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassSurface(
                  level: GlassLevel.level1,
                  borderRadius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      PersonAvatar(
                        person: Person(
                          id: member.userId,
                          name: member.displayName,
                          avatarKind: member.avatarKind,
                          avatarRef: member.avatarRef,
                        ),
                        size: 36,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.userId == currentUserId
                                  ? '${member.displayName} (You)'
                                  : member.displayName,
                              style: AppTypography.bodySemiBold
                                  .copyWith(color: theme.ink),
                            ),
                            Text(
                              member.role.label,
                              style: AppTypography.caption
                                  .copyWith(color: theme.muted),
                            ),
                          ],
                        ),
                      ),
                      if (isAdmin &&
                          member.role != GroupMemberRole.owner &&
                          member.userId != currentUserId)
                        IconButton(
                          tooltip: 'Remove member',
                          icon: Icon(
                            Icons.person_remove_outlined,
                            color: theme.textCoral,
                            size: 20,
                          ),
                          onPressed: _busy
                              ? null
                              : () => _runBusy(() async {
                                    await ref
                                        .read(sharingRepositoryProvider)
                                        .removeGroupMember(
                                          groupId: group.id,
                                          userId: member.userId,
                                        );
                                    ref
                                        .read(appStateProvider.notifier)
                                        .notifyChange();
                                  }),
                        ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
