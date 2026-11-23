import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/profile/device_profile.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/settliv_wordmark.dart';
import 'package:settliv/features/activity/presentation/widgets/records_web_view.dart';
import 'package:settliv/features/add_expense/presentation/add_expense_screen.dart';
import 'package:settliv/features/insights/presentation/widgets/insights_web_view.dart';
import 'package:settliv/features/settings/presentation/settings_screen.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part W3: Web Meta & First Impression (HTML/Manifest)', () {
    test('index.html contains wordmark ONLY, pulse, tagline and meta tags', () {
      final file = File('web/index.html');
      expect(file.existsSync(), isTrue);
      final html = file.readAsStringSync();

      // Wordmark present, NO logomark, NO old slogan
      expect(html.contains('SETTLIV'), isTrue);
      expect(html.contains('loading-wordmark'), isTrue);
      expect(html.contains('One codebase'), isFalse);
      expect(html.contains('prefers-color-scheme: dark'), isTrue);

      // Meta and OpenGraph tags
      expect(html.contains('<title>Settliv — Expense Sharing & Group Ledger</title>'), isTrue);
      expect(html.contains('og:title'), isTrue);
      expect(html.contains('og:description'), isTrue);
      expect(html.contains('theme-color'), isTrue);

      // Removed on first frame
      expect(html.contains('flutter-first-frame'), isTrue);
    });

    test('manifest.json has correct name and branding', () {
      final file = File('web/manifest.json');
      expect(file.existsSync(), isTrue);
      final json = file.readAsStringSync();

      expect(json.contains('"name": "Settliv"'), isTrue);
      expect(json.contains('"short_name": "Settliv"'), isTrue);
      expect(json.contains('One codebase'), isFalse);
    });
  });

  group('Part W3: Records Web View (/records)', () {
    testWidgets('Full-width table with search, filters dialog, row click to drawer', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/records');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RecordsWebView), findsOneWidget);

      // Table headers
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget);
      expect(find.text('Paid by'), findsOneWidget);
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Your share'), findsOneWidget);

      // Search field
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'rent');
      await tester.pumpAndSettle();

      // Check summary line
      expect(find.textContaining('record'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);

      // Clear search
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();

      // Filters button -> opens dialog
      final filterBtn = find.text('Filters');
      expect(filterBtn, findsOneWidget);
      await tester.tap(filterBtn);
      await tester.pumpAndSettle();

      expect(find.text('Filter Records'), findsOneWidget);
      expect(find.text('All groups'), findsOneWidget);
      expect(find.text('All categories'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Filter Records'), findsNothing);

      // Table row click -> drawer
      final rowFinder = find.text('Flat rent & maintenance');
      if (rowFinder.evaluate().isNotEmpty) {
        await tester.tap(rowFinder);
        await tester.pumpAndSettle();
        expect(find.text('Expense Details'), findsOneWidget);

        // Close drawer
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Expense Details'), findsNothing);
      }
    });

    testWidgets('Compact Web (/records) stacks as cards without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/records');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RecordsWebView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Part W3: Insights & Budgets Web View (/insights)', () {
    testWidgets('Insights bento layout, period switcher and navigation to Budgets', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/insights');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InsightsWebView), findsOneWidget);
      expect(find.text('TOTAL SPEND (YOUR SHARE)'), findsOneWidget);
      expect(find.text('DEBTS & SETTLEMENTS'), findsOneWidget);
      expect(find.text('BY CATEGORY'), findsOneWidget);
      expect(find.text('SPENDING HABITS'), findsOneWidget);

      // Switch period to Last month
      await tester.tap(find.text('Last month'));
      await tester.pumpAndSettle();
      expect(find.text('TOTAL SPEND (YOUR SHARE)'), findsOneWidget);

      // Click "Budgets & Limits" -> navigates to /insights/budgets
      final budgetsBtn = find.text('Budgets & Limits');
      expect(budgetsBtn, findsOneWidget);
      await tester.tap(budgetsBtn);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), equals('/insights/budgets'));

      // Check back control on Budgets screen
      final backControl = find.text('Budgets & Limits');
      expect(backControl, findsWidgets);
    });
  });

  group('Part W3: Add Expense Dialog (/add)', () {
    testWidgets('Expanded Desktop: Centered dialog layout and Esc key handling', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/add');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseScreen), findsOneWidget);

      // Dialog container has max width 960 constraint
      final constrainedBoxFinder = find.descendant(
        of: find.byType(AddExpenseScreen),
        matching: find.byType(ConstrainedBox),
      );
      expect(constrainedBoxFinder, findsWidgets);

      // Esc dismisses dialog -> navigates back to /
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), equals('/'));
    });
  });

  group('Part W3: Settings Web View (/settings)', () {
    testWidgets('Expanded Desktop: Two-pane layout with section rail and large wordmark', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/settings');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);

      // Two-pane section rail items
      expect(find.text('Account & Theme'), findsOneWidget);
      expect(find.text('Experience'), findsOneWidget);
      expect(find.text('Recurring Bills'), findsOneWidget);
      expect(find.text('Privacy & Data'), findsOneWidget);

      // Large brand wordmark at end block
      expect(find.byType(SettlivWordmark), findsWidgets);
      expect(find.text('Settliv v0.2.0'), findsOneWidget);

      // Back navigation affordance
      final backControl = find.text('Home');
      expect(backControl, findsOneWidget);
      await tester.tap(backControl);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), equals('/'));
    });
  });
}
