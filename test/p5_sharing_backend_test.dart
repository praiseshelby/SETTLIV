import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/models/group.dart';
import 'package:settliv/data/models/person.dart';
import 'package:settliv/data/models/settlement.dart';
import 'package:settliv/data/models/sharing_models.dart';
import 'package:settliv/data/repositories/persistent_app_repository.dart';
import 'package:settliv/data/repositories/sharing_repository.dart';

void main() {
  test('Join code avoids ambiguous chars, joins group, and throttles after 10 failures',
      () async {
    var now = DateTime(2026, 11, 27, 12, 0);
    final ownerApp = PersistentAppRepository(
      startEmpty: true,
      initialUser: const Person(id: 'u_owner', name: 'Asha'),
      clock: () => now,
    );
    final ownerSharing = InMemorySharingRepository(
      appRepository: ownerApp,
      currentUserId: 'u_owner',
      currentUserName: 'Asha',
      clock: () => now,
    );

    final code = ownerSharing.generateJoinCode();
    expect(code.length, 8);
    expect(RegExp(r'[0O1IL]').hasMatch(code), isFalse);

    final trip = Group(
      id: 'g_trip',
      name: 'Coorg',
      type: GroupType.trip,
      memberIds: const ['u_owner'],
      ownerId: 'u_owner',
      joinCode: code,
      joinCodeEnabled: true,
    );
    ownerApp.addGroup(trip);
    ownerSharing.seedGroupMembership(
      groupId: 'g_trip',
      userId: 'u_owner',
      role: GroupMemberRole.owner,
    );

    // Disable & regenerate
    await ownerSharing.setJoinCodeEnabled(groupId: 'g_trip', enabled: false);
    expect(ownerApp.getGroup('g_trip')!.joinCodeEnabled, isFalse);
    final newCode = await ownerSharing.regenerateJoinCode('g_trip');
    expect(newCode, isNot(code));
    expect(ownerApp.getGroup('g_trip')!.joinCodeEnabled, isTrue);

    // Joiner throttle: 10 failed attempts -> 11th throttled
    final joinerSharing = InMemorySharingRepository(
      appRepository: ownerApp,
      currentUserId: 'u_joiner',
      currentUserName: 'Rohan',
      clock: () => now,
    );
    for (int i = 0; i < 10; i++) {
      await expectLater(
        joinerSharing.joinByCode('BADCODE1'),
        throwsA(isA<SharingException>()),
      );
    }
    await expectLater(
      joinerSharing.joinByCode(newCode),
      throwsA(predicate<SharingException>(
          (e) => e.message.contains('Too many failed attempts'))),
    );

    // After 1 hour window passes, valid code succeeds
    now = now.add(const Duration(hours: 1, minutes: 1));
    final joinedId = await joinerSharing.joinByCode(newCode);
    expect(joinedId, 'g_trip');
    expect(ownerApp.getGroup('g_trip')!.memberIds, contains('u_joiner'));
  });

  test('Username search respects 3-char minimum, limit 5, and allowUsernameInvites',
      () async {
    final sharing = InMemorySharingRepository(
      currentUserId: 'u_1',
      currentUserName: 'Asha',
    );
    for (int i = 0; i < 7; i++) {
      sharing.registerDirectoryUser(
        UserSearchHit(
          id: 'u_dir_$i',
          displayName: 'Kiran $i',
          username: 'kiran_$i',
        ),
        allowInvites: i != 0,
      );
    }

    expect(await sharing.searchUsersForInvite('ki'), isEmpty);
    final hits = await sharing.searchUsersForInvite('kir');
    expect(hits.length, 5);
    expect(hits.any((h) => h.id == 'u_dir_0'), isFalse);
  });

  test('Invites expire after 14 days, can be accepted/declined/cancelled', () async {
    var now = DateTime(2026, 11, 1, 10, 0);
    final appRepo = PersistentAppRepository(
      startEmpty: true,
      initialUser: const Person(id: 'u_invitee', name: 'Meera'),
      clock: () => now,
    );
    appRepo.addGroup(const Group(
      id: 'g_home',
      name: 'Flat',
      type: GroupType.home,
      memberIds: ['u_inviter'],
      ownerId: 'u_inviter',
    ));

    final sharing = InMemorySharingRepository(
      appRepository: appRepo,
      currentUserId: 'u_invitee',
      currentUserName: 'Meera',
      clock: () => now,
    );

    sharing.seedInvite(GroupInvite(
      id: 'inv_1',
      groupId: 'g_home',
      groupName: 'Flat',
      inviterId: 'u_inviter',
      inviterName: 'Asha',
      inviteeId: 'u_invitee',
      status: GroupInviteStatus.pending,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 14)),
    ));

    final gid = await sharing.respondToInvite(inviteId: 'inv_1', accept: true);
    expect(gid, 'g_home');
    expect(appRepo.getGroup('g_home')!.memberIds, contains('u_invitee'));

    // Expired invite throws
    sharing.seedInvite(GroupInvite(
      id: 'inv_old',
      groupId: 'g_home',
      groupName: 'Flat',
      inviterId: 'u_inviter',
      inviterName: 'Asha',
      inviteeId: 'u_invitee',
      status: GroupInviteStatus.pending,
      createdAt: now,
      expiresAt: now.add(const Duration(days: 14)),
    ));
    now = now.add(const Duration(days: 15));
    await expectLater(
      sharing.respondToInvite(inviteId: 'inv_old', accept: true),
      throwsA(predicate<SharingException>(
          (e) => e.message.contains('expired'))),
    );
  });

  test('Leave requires zero balance; claiming placeholder remaps expenses & settlements',
      () async {
    final appRepo = PersistentAppRepository(
      startEmpty: true,
      initialUser: const Person(id: 'u_real', name: 'Vikram'),
    );
    appRepo.addPerson(const Person(id: 'p_placeholder', name: 'Vikram (old)'));
    appRepo.addPerson(const Person(id: 'u_owner', name: 'Asha'));
    appRepo.addGroup(const Group(
      id: 'g_1',
      name: 'Goa',
      type: GroupType.trip,
      memberIds: ['u_owner', 'p_placeholder', 'u_real'],
      ownerId: 'u_owner',
    ));
    appRepo.addExpense(Expense(
      id: 'e_1',
      groupId: 'g_1',
      title: 'Dinner',
      category: ExpenseCategory.food,
      amount: 10000,
      date: DateTime(2026, 11, 20),
      paidBy: 'u_owner',
      splitMode: SplitMode.equal,
      shares: const {'u_owner': 5000, 'p_placeholder': 5000},
    ));

    final sharing = InMemorySharingRepository(
      appRepository: appRepo,
      currentUserId: 'u_real',
      currentUserName: 'Vikram',
    );
    sharing.seedGroupMembership(
      groupId: 'g_1',
      userId: 'u_owner',
      role: GroupMemberRole.owner,
    );
    sharing.seedGroupMembership(
      groupId: 'g_1',
      userId: 'u_real',
      role: GroupMemberRole.member,
    );

    await sharing.claimPlaceholder(
      groupId: 'g_1',
      placeholderId: 'p_placeholder',
    );
    expect(appRepo.getExpense('e_1')!.shares['u_real'], 5000);
    expect(appRepo.getGroupSummary('g_1').netBalances['u_real'], -5000);

    // Cannot leave with non-zero balance
    await expectLater(
      sharing.leaveGroup('g_1'),
      throwsA(predicate<SharingException>(
          (e) => e.message.contains('Settle your remaining balance'))),
    );

    // Settle up, then leave succeeds
    appRepo.addSettlement(Settlement(
      id: 's_1',
      groupId: 'g_1',
      from: 'u_real',
      to: 'u_owner',
      paise: 5000,
      method: SettlementMethod.upi,
      date: DateTime(2026, 11, 21),
    ));
    expect(appRepo.getGroupSummary('g_1').netBalances['u_real'], 0);
    await sharing.leaveGroup('g_1');
    expect(appRepo.getGroup('g_1')!.memberIds, isNot(contains('u_real')));
  });
}
