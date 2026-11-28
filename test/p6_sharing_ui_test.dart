import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/data/models/group.dart';
import 'package:settliv/data/models/person.dart';
import 'package:settliv/data/models/sharing_models.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/repositories/persistent_app_repository.dart';
import 'package:settliv/data/repositories/sharing_repository.dart';
import 'package:settliv/features/group_detail/sheets/group_sharing_sheet.dart';
import 'package:settliv/features/groups/presentation/widgets/join_and_invites_sheets.dart';

class _TestAppStateNotifier extends AppStateNotifier {
  final PersistentAppRepository _repo;
  _TestAppStateNotifier(this._repo);

  @override
  int build() {
    repository = _repo;
    return 0;
  }
}

void main() {
  testWidgets('JoinGroupSheet joins by code and offers placeholder claiming',
      (tester) async {
    final appRepo = PersistentAppRepository(
      startEmpty: true,
      initialUser: const Person(id: 'u_joiner', name: 'Vikram'),
    );
    appRepo.addPerson(const Person(id: 'p_old', name: 'Vikram (old)'));
    appRepo.addGroup(const Group(
      id: 'g_goa',
      name: 'Goa',
      type: GroupType.trip,
      memberIds: ['u_owner', 'p_old'],
      ownerId: 'u_owner',
      joinCode: 'GOA23456',
      joinCodeEnabled: true,
    ));

    final sharing = InMemorySharingRepository(
      appRepository: appRepo,
      currentUserId: 'u_joiner',
      currentUserName: 'Vikram',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => _TestAppStateNotifier(appRepo)),
          sharingRepositoryProvider.overrideWithValue(sharing),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => JoinGroupSheet.show(context),
                child: const Text('Open Join'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Join'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'GOA23456');
    await tester.tap(find.text('Join group'));
    await tester.pumpAndSettle();

    expect(find.text("I'm already listed as..."), findsOneWidget);
    expect(find.text('Vikram (old)'), findsOneWidget);
    await tester.tap(find.text('Vikram (old)'));
    await tester.pumpAndSettle();

    expect(appRepo.getGroup('g_goa')!.memberIds, contains('u_joiner'));
    expect(appRepo.getGroup('g_goa')!.memberIds, isNot(contains('p_old')));
  });

  testWidgets('InvitesInboxSheet lists pending invite and accepts it',
      (tester) async {
    final now = DateTime(2026, 11, 27, 12, 0);
    final appRepo = PersistentAppRepository(
      startEmpty: true,
      initialUser: const Person(id: 'u_me', name: 'Meera'),
      clock: () => now,
    );
    appRepo.addGroup(const Group(
      id: 'g_flat',
      name: 'Flat 4B',
      type: GroupType.home,
      memberIds: ['u_owner'],
      ownerId: 'u_owner',
    ));

    final sharing = InMemorySharingRepository(
      appRepository: appRepo,
      currentUserId: 'u_me',
      currentUserName: 'Meera',
      clock: () => now,
    );
    sharing.seedInvite(GroupInvite(
      id: 'inv_1',
      groupId: 'g_flat',
      groupName: 'Flat 4B',
      inviterId: 'u_owner',
      inviterName: 'Asha',
      inviteeId: 'u_me',
      status: GroupInviteStatus.pending,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 14)),
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => _TestAppStateNotifier(appRepo)),
          sharingRepositoryProvider.overrideWithValue(sharing),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => InvitesInboxSheet.show(context),
                child: const Text('Open Inbox'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Inbox'));
    await tester.pumpAndSettle();

    expect(find.text('Flat 4B'), findsOneWidget);
    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(appRepo.getGroup('g_flat')!.memberIds, contains('u_me'));
  });

  testWidgets('GroupSharingSheet displays join code and searches usernames',
      (tester) async {
    final appRepo = PersistentAppRepository(
      startEmpty: true,
      initialUser: const Person(id: 'u_owner', name: 'Asha'),
    );
    const group = Group(
      id: 'g_trip',
      name: 'Coorg',
      type: GroupType.trip,
      memberIds: ['u_owner'],
      ownerId: 'u_owner',
      joinCode: 'COORG234',
      joinCodeEnabled: true,
    );
    appRepo.addGroup(group);

    final sharing = InMemorySharingRepository(
      appRepository: appRepo,
      currentUserId: 'u_owner',
      currentUserName: 'Asha',
    );
    sharing.seedGroupMembership(
      groupId: 'g_trip',
      userId: 'u_owner',
      role: GroupMemberRole.owner,
      displayName: 'Asha',
    );
    sharing.registerDirectoryUser(const UserSearchHit(
      id: 'u_kiran',
      displayName: 'Kiran Rao',
      username: 'kiran_r',
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateProvider.overrideWith(() => _TestAppStateNotifier(appRepo)),
          sharingRepositoryProvider.overrideWithValue(sharing),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => GroupSharingSheet.show(
                  context: context,
                  group: group,
                ),
                child: const Text('Open Share'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Share'));
    await tester.pumpAndSettle();

    expect(find.text('COORG234'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'kir');
    await tester.pumpAndSettle();

    expect(find.text('@kiran_r'), findsOneWidget);
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    expect(find.text('Invited @kiran_r'), findsOneWidget);
  });
}
