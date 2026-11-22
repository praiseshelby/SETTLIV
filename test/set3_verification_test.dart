import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:settliv/main.dart';
import 'package:settliv/routes/app_router.dart';
import 'package:settliv/core/theme/theme_provider.dart';

void main() {
  group('Set 3 Verification: Groups Screen & Group Detail', () {
    testWidgets('Groups screen lists active groups with New group button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/groups')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Groups'), findsWidgets);
      expect(find.text('New group'), findsOneWidget);
      expect(find.text('Flatmates'), findsWidgets);
      expect(find.text('Goa Trip'), findsOneWidget);
    });

    testWidgets('Group detail renders title, balance, and switches tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/group/group_flatmates')),
        ),
      );
      await tester.pumpAndSettle();

      // Flatmates title and actions
      expect(find.text('Flatmates'), findsWidgets);
      expect(find.text('Nudge'), findsOneWidget);
      expect(find.text('Settle up'), findsWidgets);

      // Verify Expenses tab is selected initially
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Balances'), findsOneWidget);

      // Tap Balances tab
      await tester.tap(find.text('Balances'));
      await tester.pumpAndSettle();

      // Should show Who pays whom and Member balances
      expect(find.text('Who pays whom'), findsOneWidget);
      expect(find.text('Member balances'), findsOneWidget);

      // Scroll to Spend by category
      await tester.scrollUntilVisible(find.text('Spend by category'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Spend by category'), findsOneWidget);
    });

    testWidgets('Group detail Settle up sheet opens from action button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/group/group_goa')),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Settle up action in header
      await tester.tap(find.text('Settle up').first);
      await tester.pumpAndSettle();

      expect(find.text('Settle balance'), findsOneWidget);
    });

    testWidgets('Group detail Nudge sheet opens from action button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: createAppRouter(initialLocation: '/group/group_flatmates')),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Nudge button in header
      await tester.tap(find.text('Nudge').first);
      await tester.pumpAndSettle();

      expect(find.text('Send a nudge'), findsOneWidget);
      expect(find.text('Copy reminder message'), findsOneWidget);
    });
  });

  group('Set 3 Verification: Theme Switch & Cross-Fade', () {
    testWidgets('Theme transitions between Light and Dark mode without errors',
        (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: SettlivApp(router: createAppRouter(initialLocation: '/settings')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);

      // Switch to Dark Mode
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), equals(ThemeMode.dark));

      // Switch to Light Mode
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), equals(ThemeMode.light));
    });
  });
}
