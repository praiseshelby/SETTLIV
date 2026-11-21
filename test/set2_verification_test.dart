import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settliv/main.dart';
import 'package:settliv/routes/app_router.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/core/widgets/expense_tile.dart';

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
      // Add a known personal expense
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

      // Tap Personal filter chip
      await tester.tap(find.text('Personal'));
      await tester.pumpAndSettle();

      expect(find.text('Solo Coffee Test'), findsOneWidget);
      expect(find.text('Personal · Paid by you'), findsOneWidget);
    });
  });

  group('Set 2 Verification: Add Expense Personal Handling', () {
    testWidgets('Add Expense shows Personal (just me) in group selector',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/add')),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Manual tab
      await tester.tap(find.text('Manual'));
      await tester.pumpAndSettle();

      expect(find.text('Personal (just me)'), findsOneWidget);
    });

    testWidgets('Selecting Personal (just me) hides SPLIT WITH and SPLIT MODE',
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

      // Initially on a shared group -> SPLIT WITH is present
      expect(find.text('SPLIT WITH'), findsOneWidget);

      // Select Personal (just me)
      await tester.tap(find.text('Personal (just me)'));
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
}
