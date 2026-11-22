import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/utils/name_normalizer.dart';
import 'package:settliv/core/widgets/expense_tile.dart';
import 'package:settliv/core/widgets/screen_header.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/features/home/domain/shortcut_engine.dart';
import 'package:settliv/features/home/presentation/widgets/day_period_tile.dart';
import 'package:settliv/core/theme/app_theme.dart';

void main() {
  group('Set 1 Foundations Verification Tests', () {
    test('Greeting time periods (Bug/Feature C1)', () {
      // 5 to 12 -> Good morning
      expect(getTimeGreeting(DateTime(2026, 11, 22, 5, 0)), equals('Good morning'));
      expect(getTimeGreeting(DateTime(2026, 11, 22, 11, 59)), equals('Good morning'));

      // 12 to 17 -> Good afternoon
      expect(getTimeGreeting(DateTime(2026, 11, 22, 12, 0)), equals('Good afternoon'));
      expect(getTimeGreeting(DateTime(2026, 11, 22, 16, 59)), equals('Good afternoon'));

      // 17 to 21 -> Good evening
      expect(getTimeGreeting(DateTime(2026, 11, 22, 17, 0)), equals('Good evening'));
      expect(getTimeGreeting(DateTime(2026, 11, 22, 20, 59)), equals('Good evening'));

      // 21 to 5 -> Good night
      expect(getTimeGreeting(DateTime(2026, 11, 22, 21, 0)), equals('Good night'));
      expect(getTimeGreeting(DateTime(2026, 11, 22, 23, 59)), equals('Good night'));
      expect(getTimeGreeting(DateTime(2026, 11, 22, 0, 0)), equals('Good night'));
      expect(getTimeGreeting(DateTime(2026, 11, 22, 4, 59)), equals('Good night'));
    });

    test('Name normalisation and payer display (Bug 2)', () {
      // Normalisation: trim, collapse spaces, capitalize
      expect(NameNormalizer.normalize('  ashish   kumar '), equals('Ashish Kumar'));
      expect(NameNormalizer.normalize('kabir'), equals('Kabir'));
      expect(NameNormalizer.normalize('MEERA SHARMA'), equals('Meera Sharma'));

      // Payer display: current user displays as "you" / "Paid by you"
      expect(
        NameNormalizer.formatPayer(
          payerId: 'u1',
          currentUserId: 'u1',
          fallbackName: 'ashish',
        ),
        equals('Paid by you'),
      );

      // Other user displays normalized name
      expect(
        NameNormalizer.formatPayer(
          payerId: 'u2',
          currentUserId: 'u1',
          fallbackName: 'meera sharma',
        ),
        equals('Paid by Meera Sharma'),
      );
    });

    test('Shortcut ranking & decay engine (Feature C3)', () {
      final now = DateTime(2026, 11, 22, 12, 0);

      // New-user default order: Scan receipt, Paste SMS, Budgets, IOU notes, Split calculator
      final defaultList = ShortcutEngine.rankShortcuts({});
      expect(
        defaultList.map((s) => s.id).toList(),
        equals([
          ShortcutId.scanReceipt,
          ShortcutId.pasteSms,
          ShortcutId.budgets,
          ShortcutId.iouNotes,
          ShortcutId.splitCalculator,
        ]),
      );

      // Record taps on recurring (adds +1 score each time)
      var usages = <ShortcutId, ShortcutUsage>{};
      usages = ShortcutEngine.recordTap(usages, ShortcutId.recurring, now);
      usages = ShortcutEngine.recordTap(usages, ShortcutId.recurring, now);
      usages = ShortcutEngine.recordTap(usages, ShortcutId.recurring, now);

      // Now recurring has score 3.0, it should be top 1
      var ranked = ShortcutEngine.rankShortcuts(usages);
      expect(ranked.first.id, equals(ShortcutId.recurring));

      // After 14 days, score should halve to 1.5
      final after14Days = now.add(const Duration(days: 14));
      usages = ShortcutEngine.decayAll(usages, after14Days);
      expect((usages[ShortcutId.recurring]!.score - 1.5).abs(), lessThan(0.01));

      // After another 14 days (28 total), score halves to 0.75
      final after28Days = now.add(const Duration(days: 28));
      usages = ShortcutEngine.decayAll(usages, after28Days);
      expect((usages[ShortcutId.recurring]!.score - 0.75).abs(), lessThan(0.01));
    });

    testWidgets('ExpenseTile pressed feedback does NOT shift layout or scale (Bug 6)', (tester) async {
      final expense = Expense(
        id: 'e1',
        groupId: 'g1',
        description: 'Test dinner',
        category: ExpenseCategory.food,
        totalPaise: 120000,
        date: DateTime(2026, 11, 22),
        payers: const [PayerShare(personId: 'u1', paise: 120000)],
        splitMode: SplitMode.equal,
        computedShares: const {'u1': 60000, 'u2': 60000},
        createdAt: DateTime(2026, 11, 22),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: ExpenseTile(
                  expense: expense,
                  currentUserId: 'u1',
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final initialRect = tester.getRect(find.byType(ExpenseTile));

      // Press down on the tile
      final gesture = await tester.startGesture(tester.getCenter(find.byType(ExpenseTile)));
      await tester.pump();

      final pressedRect = tester.getRect(find.byType(ExpenseTile));

      // Verify bounds are identical (no scale, no overlap with neighbors)
      expect(pressedRect, equals(initialRect));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('ScreenHeader renders 30/800 title with Bricolage Grotesque display font', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ScreenHeader(
              title: 'Settliv Title',
              eyebrow: 'OVERVIEW',
            ),
          ),
        ),
      );

      expect(find.text('Settliv Title'), findsOneWidget);
      expect(find.text('OVERVIEW'), findsOneWidget);

      final titleWidget = tester.widget<Text>(find.text('Settliv Title'));
      expect(titleWidget.style?.fontSize, equals(30));
      expect(titleWidget.style?.fontWeight, equals(FontWeight.w800));
      expect(titleWidget.style?.fontFamily, equals('BricolageGrotesque'));
    });
  });
}
