import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settliv/main.dart';
import 'package:settliv/routes/app_router.dart';
import 'package:settliv/core/utils/currency_formatter.dart';
import 'package:settliv/data/engine/split_calculator.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/features/add_expense/logic/quick_expense_parser.dart';

void main() {
  final parser = QuickExpenseParser(
    availablePeople: SeedData.people,
    availableGroups: SeedData.groups,
    currentUser: SeedData.arjun,
  );
  group('Part 3g QA: Screen Dimensions & Text Scale 1.3', () {
    testWidgets('Renders Home at 360x640 with textScaleFactor 1.3 without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 640),
              textScaler: TextScaler.linear(1.3),
            ),
            child: SettlivApp(router: createAppRouter(initialLocation: '/')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR BALANCE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders Groups at 320-wide with textScaleFactor 1.3 without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(1.3),
            ),
            child: SettlivApp(router: createAppRouter(initialLocation: '/groups')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Groups'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders Activity at 390x844 without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/activity')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Activity'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Part 3g QA: Abnormal Amounts, Pasted Junk & Parsing', () {
    test('Zero or negative is rejected in parser and formatter', () {
      expect(CurrencyFormatter.parseToPaise('0'), isNull);
      expect(CurrencyFormatter.parseToPaise('-50'), isNull);
      expect(parser.parse('dinner 0').isValid, isFalse);
    });

    test('Decimal amount 0.5 is 50 paise', () {
      expect(CurrencyFormatter.parseToPaise('0.5'), equals(50));
      expect(CurrencyFormatter.formatPaise(50), equals('₹0.50'));
    });

    test('Pasted junk text returns null safely without throwing', () {
      expect(CurrencyFormatter.parseToPaise('abc!@#\$%^&*()'), isNull);
      expect(CurrencyFormatter.parseToPaise('...'), isNull);
      expect(CurrencyFormatter.parseToPaise('12.34.56'), isNull);
    });

    test('Astronomical amount 1e18 is detected as over cap', () {
      final parsed = parser.parse('buy island 1000000000000');
      expect(parsed.isOverCap, isTrue);
      expect(parsed.isValid, isFalse);
    });

    test('3-way split of ₹100 assigns remainder to payer first', () {
      final split = SplitCalculator.splitEqual(
        totalPaise: 10000,
        memberIds: ['person_a', 'person_b', 'person_c'],
        paidBy: 'person_b',
      );
      // Payer is person_b, so person_b gets 3334, others get 3333
      expect(split['person_b'], equals(3334));
      expect(split['person_a'], equals(3333));
      expect(split['person_c'], equals(3333));
      expect(split.values.reduce((a, b) => a + b), equals(10000));
    });
  });
}
