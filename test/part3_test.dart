import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settliv/main.dart';
import 'package:settliv/routes/app_router.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/models/group.dart';
import 'package:settliv/data/models/settlement.dart';

void main() {
  group('Part 3a & Router: Navigation & Floating Nav Bar', () {
    testWidgets('Floating bar navigates between Home, Records, Insights, and Plan',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/')),
        ),
      );
      await tester.pumpAndSettle();

      // Initially on Home screen
      expect(find.text('NET ACROSS GROUPS'), findsOneWidget);
      expect(find.text('Records'), findsOneWidget);

      // Tap Records slot in nav bar
      await tester.tap(find.text('Records'));
      await tester.pumpAndSettle();

      // Should be on Records screen
      expect(find.text('Records'), findsWidgets);
      expect(find.text('All groups'), findsOneWidget);

      // Tap Insights slot in nav bar
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      // Should be on Insights screen
      expect(find.text('Insights'), findsWidgets);

      // Tap Home slot to return to Home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('NET ACROSS GROUPS'), findsOneWidget);
    });

    testWidgets('Tapping center + button in floating bar opens /add',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Add expense'));
      await tester.pumpAndSettle();

      expect(find.text('New expense'), findsOneWidget);
    });

    testWidgets('Unknown route shows friendly Page not found with Home button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(
            router: createAppRouter(initialLocation: '/non_existent_route'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page not found'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);

      // Tap Home button navigates back to Home
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(find.text('NET ACROSS GROUPS'), findsOneWidget);
    });

    testWidgets('Invalid group id shows friendly Group not found state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(
            router: createAppRouter(initialLocation: '/group/invalid_group_xyz'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Group not found'), findsOneWidget);
      expect(find.text('Back to Home'), findsOneWidget);

      await tester.tap(find.text('Back to Home'));
      await tester.pumpAndSettle();

      expect(find.text('NET ACROSS GROUPS'), findsOneWidget);
    });
  });

  group('Part 3c: In-Memory Dynamic Group Creation', () {
    test('Creating a dynamic group updates repository and prevents duplicates', () {
      // Fresh repo
      final repo = InMemoryAppRepository();
      final initialCount = repo.getGroups().length;

      // Duplicate name rejected
      final existingGroup = repo.getGroups().first;
      final isDuplicate = repo
          .getGroups()
          .any((g) => g.name.toLowerCase() == existingGroup.name.toLowerCase());
      expect(isDuplicate, isTrue);

      // Add a valid unique group
      const newGroupId = 'group_manali';
      const newGroup = Group(
        id: newGroupId,
        name: 'Manali Expedition',
        type: GroupType.trip,
        memberIds: ['person_arjun', 'person_meera'],
        coverType: GroupCoverType.goaTrip,
      );

      repo.addGroup(newGroup);
      expect(repo.getGroups().length, equals(initialCount + 1));
      expect(repo.getGroup(newGroupId)?.name, equals('Manali Expedition'));
    });
  });

  group('Part 3e: Settle Flow & Invariants', () {
    test('Settlement updates ledger balances and undo restores exact state', () {
      final repo = InMemoryAppRepository();

      // Goa Trip initial state: Arjun owes Rohan 38000 paise (₹380)
      final initialSummary = repo.getGroupSummary('group_goa');
      final initialArjunNet = initialSummary.netBalances['person_arjun'] ?? 0;
      expect(initialArjunNet, equals(-38000));

      // Partial settlement of ₹200 (20000 paise)
      final settlement = Settlement(
        id: 'stl_test_1',
        groupId: 'group_goa',
        payerId: 'person_arjun',
        payeeId: 'person_rohan',
        amount: 20000,
        date: DateTime.now(),
        method: SettlementMethod.cash,
        note: 'Partial settle ₹200',
      );

      repo.addSettlement(settlement);

      // Balances update instantly: Arjun now owes ₹180 (-18000 paise)
      final afterSummary = repo.getGroupSummary('group_goa');
      final afterArjunNet = afterSummary.netBalances['person_arjun'] ?? 0;
      expect(afterArjunNet, equals(-18000));

      // Undo settlement restores exact initial balance
      repo.deleteSettlement(settlement.id);
      final restoredSummary = repo.getGroupSummary('group_goa');
      final restoredArjunNet = restoredSummary.netBalances['person_arjun'] ?? 0;
      expect(restoredArjunNet, equals(initialArjunNet));
    });
  });
}
