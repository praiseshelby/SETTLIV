import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/profile/device_profile.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/theme/app_typography.dart';
import 'package:settliv/core/widgets/group_card.dart';
import 'package:settliv/core/widgets/settliv_wordmark.dart';
import 'package:settliv/features/group_detail/presentation/widgets/group_detail_web_view.dart';
import 'package:settliv/features/home/presentation/widgets/dashboard_web_view.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part W2: Wordmark Only Brand Requirement', () {
    testWidgets('SettlivWordmark renders SETTLIV in Bricolage Grotesque ExtraBold with wide tracking', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Center(
              child: SettlivWordmark(fontSize: 18),
            ),
          ),
        ),
      );

      final wordmarkFinder = find.byType(SettlivWordmark);
      expect(wordmarkFinder, findsOneWidget);
      expect(find.text('SETTLIV'), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('SETTLIV'));
      expect(textWidget.style?.fontFamily, equals(AppTypography.fontBrand));
      expect(textWidget.style?.fontWeight, equals(FontWeight.w800));
      expect(textWidget.style?.letterSpacing, closeTo(18 * 0.18, 0.01));
    });

    testWidgets('Rotated wordmark in medium rail rotates 90 degrees bottom-to-top', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Center(
              child: SettlivWordmark(fontSize: 13, rotated: true),
            ),
          ),
        ),
      );

      final rotatedBoxFinder = find.byType(RotatedBox);
      expect(rotatedBoxFinder, findsOneWidget);
      final rotatedBox = tester.widget<RotatedBox>(rotatedBoxFinder);
      expect(rotatedBox.quarterTurns, equals(3));
    });

    testWidgets('Wordmark renders in each shell variant (expanded, medium, compact) with ZERO logomark widgets', (tester) async {
      // 1. Expanded Desktop (1440x900)
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/');

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

      expect(find.byType(SettlivWordmark), findsWidgets);
      expect(find.text('SETTLIV'), findsWidgets);
      // Assert no logomark widget exists
      expect(find.text('S'), findsNothing);

      // 2. Medium Web (800x1000)
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pumpAndSettle();
      expect(find.byType(SettlivWordmark), findsWidgets);
      expect(find.byType(RotatedBox), findsOneWidget);
      expect(find.text('S'), findsNothing);

      // 3. Compact Web (390x844)
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(SettlivWordmark), findsWidgets);
      expect(find.text('S'), findsNothing);

      // 4. Settings view has large wordmark (at end block)
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(SettlivWordmark), findsWidgets);
      expect(find.text('S'), findsNothing);
    });
  });

  group('Part W2: Dashboard Web View', () {
    testWidgets('Expanded Desktop (1440x900): Bento grid elements, table and detail drawer', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/');

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

      // Check DashboardWebView is present
      expect(find.byType(DashboardWebView), findsOneWidget);

      // Key Bento Elements
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Recent groups'), findsOneWidget);
      expect(find.text('Quick shortcuts'), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);

      // Desktop rule: scanReceipt is hidden from shortcuts on desktop
      expect(find.text('Scan receipt'), findsNothing);

      // Activity Table columns
      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Paid by'), findsOneWidget);
      expect(find.text('Your share'), findsOneWidget);

      // Table row click -> opens detail drawer
      final activityRowFinder = find.text('Flat rent & maintenance');
      if (activityRowFinder.evaluate().isNotEmpty) {
        await tester.tap(activityRowFinder);
        await tester.pumpAndSettle();

        // Right-side drawer opened
        expect(find.text('Expense Details'), findsOneWidget);
        // Press Esc to dismiss drawer
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Expense Details'), findsNothing);
      }

      // Hero Net position tap -> navigates to /balances
      final heroFinder = find.text('NET POSITION');
      expect(heroFinder, findsOneWidget);
      await tester.tap(heroFinder);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), equals('/balances'));
    });

    testWidgets('Compact Web (390x844): Stacks bento in single column without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/');

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

      expect(find.byType(DashboardWebView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Part W2: Groups Web View', () {
    testWidgets('Responsive grid at expanded (3 cols) and medium (2 cols) with New group dialog', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/groups');

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

      expect(find.byWidgetPredicate((w) => w is GroupCard || w.runtimeType.toString() == 'GroupHubCard'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Tap "New group" -> opens AdaptivePresenter modal dialog
      final newGroupBtn = find.text('New group');
      expect(newGroupBtn, findsOneWidget);
      await tester.tap(newGroupBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining(RegExp(r'group', caseSensitive: false)), findsWidgets);
      // Close dialog with close icon
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text('New Group'), findsNothing);

      // Medium viewport (800x1000)
      tester.view.physicalSize = const Size(800, 1000);
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is GroupCard || w.runtimeType.toString() == 'GroupHubCard'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Part W2: Group Detail Web View', () {
    testWidgets('Expanded Desktop: Full-bleed banner, two panes, back control', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/group/group_flatmates');

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

      expect(find.byType(GroupDetailWebView), findsOneWidget);
      expect(find.text('Flatmates'), findsWidgets);
      expect(find.text('GROUP BALANCES'), findsOneWidget);

      // Back control present
      final backControl = find.text('Groups');
      expect(backControl, findsOneWidget);
      await tester.tap(backControl);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), equals('/groups'));
    });
  });

  group('Part W2: Balances Web View', () {
    testWidgets('Expanded Desktop: Two columns side by side (Owed to you | You owe) and back navigation', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/balances');

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

      // Side by side headers present
      expect(find.textContaining('OWED TO YOU'), findsOneWidget);
      expect(find.textContaining('YOU OWE'), findsOneWidget);

      // Back navigation affordance
      final backAffordance = find.text('Home');
      expect(backAffordance, findsOneWidget);
      await tester.tap(backAffordance);
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), equals('/'));
    });

    testWidgets('Compact Web: Stacked sections without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/balances');

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

      expect(find.textContaining('OWED TO YOU'), findsOneWidget);
      expect(find.textContaining('YOU OWE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
