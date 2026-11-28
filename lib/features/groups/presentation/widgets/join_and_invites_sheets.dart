import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../core/widgets/form_sheet_scaffold.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../data/models/person.dart';
import '../../../../data/models/sharing_models.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../../../../data/repositories/sharing_repository.dart';

class JoinGroupSheet extends ConsumerStatefulWidget {
  const JoinGroupSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: 'Join group',
      isScrollControlled: true,
      child: const JoinGroupSheet(),
    );
  }

  @override
  ConsumerState<JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<JoinGroupSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _joinedGroupId;
  List<Person> _unclaimedPlaceholders = const [];

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _onJoin() async {
    if (_busy) return;
    final code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the 8-character join code');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sharing = ref.read(sharingRepositoryProvider);
      final groupId = await sharing.joinByCode(code);
      ref.read(appStateProvider.notifier).notifyChange();
      ref.read(sharingVersionProvider.notifier).state++;

      final appRepo = ref.read(appRepositoryProvider);
      final group = appRepo.getGroup(groupId);
      final uid = appRepo.currentUserId;
      final placeholders = <Person>[];
      if (group != null) {
        for (final id in group.memberIds) {
          if (id == uid || id == group.ownerId) continue;
          final p = appRepo.getPerson(id);
          if (p != null && p.linkedUserId == null) {
            placeholders.add(p);
          }
        }
      }

      if (!mounted) return;
      if (placeholders.isNotEmpty) {
        setState(() {
          _joinedGroupId = groupId;
          _unclaimedPlaceholders = placeholders;
        });
      } else {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } on SharingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not join group. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim(String placeholderId) async {
    if (_busy || _joinedGroupId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sharingRepositoryProvider).claimPlaceholder(
            groupId: _joinedGroupId!,
            placeholderId: placeholderId,
          );
      ref.read(appStateProvider.notifier).notifyChange();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } on SharingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not claim member');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    if (_joinedGroupId != null) {
      return FormSheetScaffold(
        bottomBar: PrimaryButton(
          label: 'Join as new member',
          onPressed: _busy
              ? null
              : () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "I'm already listed as...",
              style: AppTypography.titleLarge.copyWith(
                color: theme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select your name if someone already added expenses for you in this group.',
              style: AppTypography.body.copyWith(color: theme.muted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: theme.textCoral)),
            ],
            const SizedBox(height: 14),
            for (final p in _unclaimedPlaceholders)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassSurface(
                  level: GlassLevel.level1,
                  borderRadius: 14,
                  onTap: _busy ? null : () => _claim(p.id),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      PersonAvatar(person: p, size: 36),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          p.name,
                          style: AppTypography.bodySemiBold
                              .copyWith(color: theme.ink),
                        ),
                      ),
                      Text(
                        'Claim',
                        style: AppTypography.caption.copyWith(
                          color: theme.textEmerald,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return FormSheetScaffold(
      bottomBar: PrimaryButton(
        label: _busy ? 'Joining...' : 'Join group',
        onPressed: _busy ? null : _onJoin,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter an 8-character group join code',
            style: AppTypography.body.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            style: AppTypography.titleLarge.copyWith(
              color: theme.ink,
              letterSpacing: 2.0,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. K7M9P2QR',
              hintStyle: AppTypography.body.copyWith(color: theme.muted),
              errorText: _error,
              filled: true,
              fillColor: theme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class InvitesInboxSheet extends ConsumerStatefulWidget {
  const InvitesInboxSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: 'Group invites',
      isScrollControlled: true,
      child: const InvitesInboxSheet(),
    );
  }

  @override
  ConsumerState<InvitesInboxSheet> createState() => _InvitesInboxSheetState();
}

class _InvitesInboxSheetState extends ConsumerState<InvitesInboxSheet> {
  bool _busy = false;
  String? _error;

  Future<void> _respond(GroupInvite invite, bool accept) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sharingRepositoryProvider).respondToInvite(
            inviteId: invite.id,
            accept: accept,
          );
      ref.read(sharingVersionProvider.notifier).state++;
      ref.read(appStateProvider.notifier).notifyChange();
    } on SharingException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update invite');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final invitesAsync = ref.watch(incomingInvitesProvider);

    return FormSheetScaffold(
      bottomBar: PrimaryButton(
        label: 'Close',
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: theme.textCoral)),
            const SizedBox(height: 10),
          ],
          invitesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => Text(
              'Could not load invites.',
              style: AppTypography.body.copyWith(color: theme.muted),
            ),
            data: (invites) {
              if (invites.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No pending group invites right now.',
                    style: AppTypography.body.copyWith(color: theme.muted),
                  ),
                );
              }
              return Column(
                children: [
                  for (final inv in invites)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GlassSurface(
                        level: GlassLevel.level1,
                        borderRadius: 16,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.groupName,
                              style: AppTypography.bodySemiBold
                                  .copyWith(color: theme.ink),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Invited by ${inv.inviterName}',
                              style: AppTypography.caption
                                  .copyWith(color: theme.muted),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _respond(inv, false),
                                  child: Text(
                                    'Decline',
                                    style: TextStyle(color: theme.textCoral),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _respond(inv, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.primaryButtonBg,
                                    foregroundColor: theme.primaryButtonText,
                                  ),
                                  child: const Text('Accept'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
