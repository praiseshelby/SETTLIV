import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settliv/core/widgets/group_card.dart';
import 'package:settliv/features/group_detail/presentation/widgets/balance_bars_chart.dart';
import 'package:settliv/features/group_detail/presentation/widgets/category_donut_chart.dart';
import 'package:settliv/main.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  testWidgets('Home screen renders groups, balances, and navigates to group detail',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: SettlivApp(router: createAppRouter())));
    await tester.pumpAndSettle();

    expect(find.text("YOUR BALANCE"), findsOneWidget);
    final flatmatesCard = find.widgetWithText(GroupCard, 'Flatmates');
    expect(flatmatesCard, findsOneWidget);

    // Tap Flatmates card to open GroupDetailScreen
    await tester.tap(flatmatesCard);
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
    await tester.pumpWidget(ProviderScope(child: SettlivApp(router: createAppRouter())));
    await tester.pumpAndSettle();

    final goaCard = find.widgetWithText(GroupCard, 'Goa Trip');
    expect(goaCard, findsOneWidget);

    await tester.ensureVisible(goaCard);
    await tester.pumpAndSettle();

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
    expect(find.text('Pay via UPI'), findsOneWidget);
    expect(find.text('Mark as cash'), findsOneWidget);
  });

  testWidgets('Tapping Quick Add suggestion chip navigates to /add prefilled',
      (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(child: SettlivApp(router: createAppRouter())));
    await tester.pumpAndSettle();

    final rentChip = find.text('Rent 18,000');
    expect(rentChip, findsOneWidget);
    await tester.tap(rentChip);
    await tester.pumpAndSettle();

    expect(find.text('New expense'), findsOneWidget);
    expect(find.text('Rent 18,000'), findsWidgets);
  });
}
