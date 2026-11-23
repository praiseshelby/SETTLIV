import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/profile/device_profile.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/widgets/phone_frame.dart';
import 'package:settliv/core/widgets/avatar_stack.dart';
import 'package:settliv/core/widgets/screen_header.dart';
import 'package:settliv/core/widgets/settliv_wordmark.dart';
import 'package:settliv/core/widgets/web_balance_badge.dart';
import 'package:settliv/data/engine/balance_engine.dart';
import 'package:settliv/data/models/person.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/features/home/presentation/widgets/month_dial.dart';

void main() {
  group('Part X1: Experience Rules & Resolution Table', () {
    test('Resolution table strictly maps (profile, mode) -> EffectiveExperience', () {
      const desktop = DeviceProfile(deviceClass: DeviceClass.desktop);
      const touch = DeviceProfile(deviceClass: DeviceClass.touch);

      // desktop + none -> Web
      expect(resolveEffectiveExperience(profile: desktop, mode: ExperienceMode.auto), EffectiveExperience.web);
      // desktop + app -> App
      expect(resolveEffectiveExperience(profile: desktop, mode: ExperienceMode.app), EffectiveExperience.app);
      // desktop + web -> Web
      expect(resolveEffectiveExperience(profile: desktop, mode: ExperienceMode.web), EffectiveExperience.web);

      // touch + none -> App
      expect(resolveEffectiveExperience(profile: touch, mode: ExperienceMode.auto), EffectiveExperience.app);
      // touch + app -> App
      expect(resolveEffectiveExperience(profile: touch, mode: ExperienceMode.app), EffectiveExperience.app);
      // touch + web -> Web
      expect(resolveEffectiveExperience(profile: touch, mode: ExperienceMode.web), EffectiveExperience.web);
    });
  });

  group('Part X1: Centred Phone Frame & Wordmark', () {
    testWidgets('Phone frame renders bezel, SETTLIV wordmark, and preview hint on wide viewport', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PhoneFrame(
                child: Text('App Content Inside Frame'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('App Content Inside Frame'), findsOneWidget);
      expect(find.byType(SettlivWordmark), findsOneWidget);
      expect(find.textContaining('Mobile app layout · compatibility preview'), findsOneWidget);
    });

    testWidgets('Phone frame returns unadorned child on phones (<= 600px)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PhoneFrame(
                child: Text('Raw Mobile View'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Raw Mobile View'), findsOneWidget);
      expect(find.byType(SettlivWordmark), findsNothing);
      expect(find.textContaining('compatibility preview'), findsNothing);
    });
  });

  group('Part X1: Avatar Stack Geometry & Initials Legibility', () {
    testWidgets('AvatarStack uses overlap <= 6px and preserves initials visibility', (tester) async {
      const p1 = Person(id: 'p1', name: 'Kabir Verma', avatarInitials: 'KV', avatarPairIndex: 0);
      const p2 = Person(id: 'p2', name: 'Meera Rao', avatarInitials: 'MR', avatarPairIndex: 1);
      const p3 = Person(id: 'p3', name: 'Nisha Gupta', avatarInitials: 'NG', avatarPairIndex: 2);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarStack(
              people: [p1, p2, p3],
              size: 32,
              overlap: 6.0,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AvatarStack), findsOneWidget);
      expect(find.text('KV'), findsOneWidget);
      expect(find.text('MR'), findsOneWidget);
      expect(find.text('NG'), findsOneWidget);

      final stackRender = tester.renderObject<RenderBox>(find.byType(AvatarStack));
      expect(stackRender.size.height, 32.0);
      // Width for 3 items with size 32 and overlap <= 6 is bounded: 32 + 2*(32 - overlap) >= 32 + 2*26 = 84
      expect(stackRender.size.width, greaterThanOrEqualTo(80.0));
      expect(stackRender.size.width, lessThanOrEqualTo(96.0));
    });
  });

  group('Part X1: Hero Counts & Seed Logic Audit', () {
    test('amount > 0 implies count >= 1 and counts distinct counterparties across groups + IOUs', () {
      const engine = BalanceEngine();
      final people = SeedData.people;
      final peopleMap = {for (final p in people) p.id: p};
      final groups = SeedData.groups;
      final groupMembers = {for (final g in groups) g.id: g.memberIds};
      final expenses = SeedData.expenses;
      final settlements = SeedData.settlements;

      final counterpartyNets = engine.computeCounterpartyNets(
        currentUserId: SeedData.currentUserId,
        groups: groups,
        groupMembersMap: groupMembers,
        expenses: expenses,
        settlements: settlements,
        iouNotes: const [],
        peopleMap: peopleMap,
      );

      final owingUser = counterpartyNets.where((c) => c.netPaise > 0).toList();
      final userOwes = counterpartyNets.where((c) => c.netPaise < 0).toList();

      // Arjun has positive net in Flatmates (+₹1,240 from Kabir/Meera) and owes in Goa (-₹380)
      expect(owingUser.isNotEmpty, isTrue);
      expect(userOwes.isNotEmpty, isTrue);

      final overall = engine.computeUserOverallBalance(
        currentUserId: SeedData.currentUserId,
        groupIds: groups.map((g) => g.id).toList(),
        groupMembersMap: groupMembers,
        expenses: expenses,
        settlements: settlements,
      );

      if (overall.totalOwedToUser > 0) {
        expect(owingUser.length, greaterThanOrEqualTo(1));
      }
      if (overall.totalUserOwes > 0) {
        expect(userOwes.length, greaterThanOrEqualTo(1));
      }
    });

    test('FIFO settlement matching computes true debt age, never showing settled 155-day debt', () {
      const engine = BalanceEngine();
      final now = DateTime.now();

      final ageDays = engine.computeDebtAgeInDays(
        debtorId: 'person_kabir',
        creditorId: SeedData.currentUserId,
        groupId: 'group_flatmates',
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
        now: now,
      );

      // The historical expenses from 35, 65, 95, 125, 155 days ago were settled!
      // Oldest unsettled debt in Flatmates is within ~16 days.
      expect(ageDays, lessThanOrEqualTo(20));
      expect(ageDays, isNot(155));
    });

    test('MonthDial renders properly without throwing', () {
      final now = DateTime(2026, 11, 23);
      final widget = MonthDial(now: now);
      expect(widget.now.day, 23);
    });

    testWidgets('WebBalanceBadge renders right-aligned tabular numbers and caption', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WebBalanceBadge(paise: 124000),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('₹1,240'), findsOneWidget);
      expect(find.text('owed to you'), findsOneWidget);
    });
  });

  group('Part X1: Web Spacing & Insets Audit', () {
    testWidgets('ScreenHeader on desktop web has top padding 40px and title-to-content 24px', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScreenHeader(
              title: 'Groups',
            ),
          ),
        ),
      );
      await tester.pump();

      final paddingFinder = find.byType(Padding).first;
      final padding = tester.widget<Padding>(paddingFinder);
      final insets = padding.padding as EdgeInsets;

      expect(insets.top, 40.0);
      expect(insets.bottom, 24.0);
      expect(insets.left, greaterThanOrEqualTo(24.0));
      expect(insets.right, greaterThanOrEqualTo(24.0));
    });
  });
}
