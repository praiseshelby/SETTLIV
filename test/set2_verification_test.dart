import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settliv/main.dart';
import 'package:settliv/routes/app_router.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/models/iou_note.dart';
import 'package:settliv/data/engine/person_balance_engine.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/core/widgets/expense_tile.dart';
import 'package:settliv/features/add_expense/presentation/widgets/scan_sheet.dart';

void main() {
  group('Set 2 Verification: Records Screen & Personal Filter', () {
    testWidgets('Records screen renders All groups and Personal filter chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/records')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Records'), findsWidgets);
      expect(find.text('All groups'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);
    });

    testWidgets('Tapping Personal filter chip filters list to personal expenses',
        (WidgetTester tester) async {
      final repo = InMemoryAppRepository();
      final personalExp = Expense(
        id: 'exp_personal_test_1',
        groupId: 'group_personal',
        title: 'Solo Coffee Test',
        category: ExpenseCategory.food,
        amount: 25000,
        date: DateTime.now(),
        paidBy: 'person_arjun',
        splitMode: SplitMode.equal,
        shares: const {'person_arjun': 25000},
      );
      repo.addExpense(personalExp);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRepositoryProvider.overrideWithValue(repo),
          ],
          child: SettlivApp(router: createAppRouter(initialLocation: '/records')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();

      expect(find.text('Solo Coffee Test'), findsOneWidget);
      expect(find.text('Personal · Paid by you'), findsOneWidget);
    });
  });

  group('Set 2 Verification: Add Expense Shared | Personal Toggle', () {
    testWidgets('Add Expense shows Shared | Personal toggle and scan button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/add')),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Manual tab
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();

      // Both Shared and Personal segmented options are visible
      expect(find.text('Shared'), findsWidgets);
      expect(find.text('Personal'), findsWidgets);

      // Initially on Shared -> SPLIT WITH is present
      expect(find.text('SPLIT WITH'), findsOneWidget);

      // Tap Personal segmented button
      await tester.tap(find.text('Personal').first);
      await tester.pumpAndSettle();

      // SPLIT WITH and SPLIT MODE should now be hidden
      expect(find.text('SPLIT WITH'), findsNothing);
      expect(find.text('SPLIT MODE'), findsNothing);
    });

    testWidgets('ExpenseTile renders Personal · Paid by you for personal group',
        (WidgetTester tester) async {
      final personalExp = Expense(
        id: 'exp_personal_tile_test',
        groupId: 'group_personal',
        title: 'Books',
        category: ExpenseCategory.other,
        amount: 45000,
        date: DateTime.now(),
        paidBy: 'person_arjun',
        splitMode: SplitMode.equal,
        shares: const {'person_arjun': 45000},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExpenseTile(
              expense: personalExp,
              group: SeedData.personal,
              payer: SeedData.arjun,
              currentUserId: SeedData.currentUserId,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Books'), findsOneWidget);
      expect(find.text('Personal · Paid by you'), findsOneWidget);
      expect(find.text('Paid for self'), findsOneWidget);
    });
  });

  group('Set 2 Verification: IOU Notes Model & Engine', () {
    test('IOU Note creation, remaining calculation, and partial payment', () {
      final note = IouNote(
        id: 'iou_1',
        personName: 'Rohan Sharma',
        direction: IouDirection.owedToMe,
        amountPaise: 50000, // ₹500
        note: 'Concert ticket advance',
        date: DateTime(2026, 11, 20),
        dueDate: DateTime(2026, 11, 25),
      );

      expect(note.isSettled, isFalse);
      expect(note.remainingPaise, 50000);
      expect(note.paidPaise, 0);
      expect(note.isOwedToMe, isTrue);

      final withPayment = note.copyWith(payments: [
        IouPayment(
          id: 'pay_1',
          amountPaise: 20000,
          date: DateTime(2026, 11, 21),
        ),
      ]);

      expect(withPayment.paidPaise, 20000);
      expect(withPayment.remainingPaise, 30000);
      expect(withPayment.isSettled, isFalse);

      final settled = withPayment.copyWith(payments: [
        ...withPayment.payments,
        IouPayment(
          id: 'pay_2',
          amountPaise: 30000,
          date: DateTime(2026, 11, 22),
        ),
      ]);

      expect(settled.paidPaise, 50000);
      expect(settled.remainingPaise, 0);
      expect(settled.isSettled, isTrue);
    });

    test('IOU Note overdue logic works correctly', () {
      final overdueNote = IouNote(
        id: 'iou_overdue',
        personName: 'Vikram',
        direction: IouDirection.owedToMe,
        amountPaise: 15000,
        note: 'Lunch spot',
        date: DateTime(2026, 11, 10),
        dueDate: DateTime(2026, 11, 15),
      );

      final now = DateTime(2026, 11, 23);
      expect(overdueNote.isOverdue(now), isTrue);
      expect(overdueNote.dueLabel(now), contains('Overdue'));
    });

    test('PersonBalanceEngine integrates IOU notes into PersonDebtSummary', () {
      final repo = InMemoryAppRepository();
      repo.addIouNote(IouNote(
        id: 'iou_test_sneha',
        personName: 'Sneha Rao', // Matches SeedData sneha
        direction: IouDirection.owedToMe,
        amountPaise: 30000,
        note: 'Taxi fare',
        date: DateTime.now(),
      ));

      final summaries = PersonBalanceEngine.computePersonSummaries(repo);
      final snehaSummary = summaries.firstWhere((s) => s.person.name.toLowerCase() == 'sneha rao');

      expect(snehaSummary.iouNotes, isNotEmpty);
      expect(snehaSummary.breakdownText, contains('IOU note'));
    });
  });

  group('Set 2 Verification: Groups Hub & Navigation', () {
    testWidgets('Groups Hub renders search bar, segmented control and template cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/groups')),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and search button
      expect(find.text('Groups'), findsWidgets);
      await tester.tap(find.byTooltip('Search groups'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsWidgets); // Search field

      // Check Active and Archived segmented control
      expect(find.textContaining('Active'), findsWidgets);
      expect(find.textContaining('Archived'), findsWidgets);

      // Check template row
      expect(find.text('START A NEW GROUP'), findsOneWidget);
      expect(find.text('Trip'), findsWidgets);
      expect(find.text('Flatmates'), findsWidgets);
      expect(find.text('Couple'), findsWidgets);
    });

    testWidgets('Tapping Archived tab switches view without crash',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/groups')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Archived').first);
      await tester.pumpAndSettle();

      expect(find.text('No archived groups'), findsOneWidget);
    });
  });

  group('Set 2 Verification: Scan Sheet Presentation', () {
    testWidgets('ScanSheet presents honest explanation and action options',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => ScanSheet.show(ctx),
                  child: const Text('Open Scan'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Scan'));
      await tester.pumpAndSettle();

      expect(find.text('Scan receipt'), findsOneWidget);
      expect(find.text('Coming with the Android app'), findsOneWidget);
      expect(find.text('Paste bank SMS'), findsOneWidget);
      expect(find.text('Type it instead'), findsOneWidget);
    });
  });
}
