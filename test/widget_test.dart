import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/features/group_detail/presentation/widgets/balance_bars_chart.dart';
import 'package:settliv/features/group_detail/presentation/widgets/category_donut_chart.dart';
import 'package:settliv/main.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Home screen renders groups, balances, and navigates to group detail',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(child: SettlivApp(router: createAppRouter())));
    await tester.pumpAndSettle();

    expect(find.text("NET POSITION"), findsOneWidget);
    final flatmatesFinder = find.text('Flatmates');
    await tester.scrollUntilVisible(flatmatesFinder, 150);
    await tester.pumpAndSettle();
    expect(flatmatesFinder, findsOneWidget);

    // Tap Flatmates card to open GroupDetailScreen
    await tester.tap(flatmatesFinder);
    await tester.pumpAndSettle();

    // Verify GroupDetailScreen components
    expect(find.text('Day 3 of 5'), findsNothing); // Flatmates is home
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Balances'), findsOneWidget);

    // Switch to Balances tab
    await tester.tap(find.text('Balances'));
    await tester.pumpAndSettle();

    expect(find.text('Who pays whom'), findsOneWidget);
    expect(find.byType(BalanceBarsChart), findsOneWidget);
    expect(find.byType(CategoryDonutChart, skipOffstage: false), findsOneWidget);
  });

  testWidgets('Goa trip shows trip progress bar and settle up sheet opens',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(child: SettlivApp(router: createAppRouter())));
    await tester.pumpAndSettle();

    final goaCard = find.text('Goa Trip');
    await tester.scrollUntilVisible(goaCard, 150);
    await tester.pumpAndSettle();
    expect(goaCard, findsOneWidget);

    await tester.tap(goaCard);
    await tester.pumpAndSettle();

    // Verify trip progress bar
    expect(find.text('Day 3 of 5'), findsOneWidget);
    expect(find.text('You owe ₹380'), findsOneWidget);

    // Tap Settle up
    final settleUpBtn = find.text('Settle up · ₹380');
    expect(settleUpBtn, findsOneWidget);
    await tester.tap(settleUpBtn);
    await tester.pumpAndSettle();

    // Verify SettleSheet opened
    expect(find.text('Pay with UPI'), findsOneWidget);
    expect(find.text('Paid in Cash'), findsOneWidget);
  });

  testWidgets('Tapping center + button in floating nav bar navigates to /add',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: SettlivApp(router: createAppRouter())));
    await tester.pumpAndSettle();

    final addBtn = find.bySemanticsLabel('Add expense');
    expect(addBtn, findsOneWidget);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    expect(find.text('New expense'), findsOneWidget);
  });
}
