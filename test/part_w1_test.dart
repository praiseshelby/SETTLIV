import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/navigation/back_navigation.dart';
import 'package:settliv/core/profile/device_profile.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/adaptive_presenter.dart';
import 'package:settliv/core/widgets/adaptive_web_shell.dart';
import 'package:settliv/core/widgets/app_shell.dart';
import 'package:settliv/core/widgets/docked_nav_bar.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part W1: Device Detection & Mode Resolution', () {
    test('DeviceProfile detection properties and fake profiles', () {
      const desktopProfile = DeviceProfile(
        deviceClass: DeviceClass.desktop,
        hardwareConcurrency: 8,
        deviceMemory: 16.0,
      );
      expect(desktopProfile.isDesktop, isTrue);
      expect(desktopProfile.isTouch, isFalse);
      expect(desktopProfile.hardwareConcurrency, equals(8));
      expect(desktopProfile.deviceMemory, equals(16.0));

      const touchProfile = DeviceProfile(
        deviceClass: DeviceClass.touch,
        hardwareConcurrency: 4,
        deviceMemory: 4.0,
      );
      expect(touchProfile.isDesktop, isFalse);
      expect(touchProfile.isTouch, isTrue);
    });

    test('Mode resolution table: Desktop always gets Web, Touch defaults to App', () {
      // Test matrix:
      // (DeviceClass, ExperienceMode) -> EffectiveExperience
      final matrix = [
        // Desktop is strictly always Web
        (DeviceClass.desktop, ExperienceMode.auto, EffectiveExperience.web),
        (DeviceClass.desktop, ExperienceMode.app, EffectiveExperience.web),
        (DeviceClass.desktop, ExperienceMode.web, EffectiveExperience.web),

        // Touch defaults to App, can switch to Web
        (DeviceClass.touch, ExperienceMode.auto, EffectiveExperience.app),
        (DeviceClass.touch, ExperienceMode.app, EffectiveExperience.app),
        (DeviceClass.touch, ExperienceMode.web, EffectiveExperience.web),
      ];

      for (final (deviceClass, mode, expected) in matrix) {
        final container = ProviderContainer(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              DeviceProfile(deviceClass: deviceClass),
            ),
          ],
        );

        container.read(experienceModeProvider.notifier).setMode(mode);
        final effective = container.read(effectiveExperienceProvider);
        expect(
          effective,
          equals(expected),
          reason: 'Failed for deviceClass=$deviceClass, mode=$mode',
        );
      }
    });

    test('Desktop cannot reach App experience under any circumstance', () {
      final container = ProviderContainer(
        overrides: [
          deviceProfileProvider.overrideWithValue(
            const DeviceProfile(deviceClass: DeviceClass.desktop),
          ),
        ],
      );

      // Explicitly try setting App mode
      container.read(experienceModeProvider.notifier).setMode(ExperienceMode.app);
      expect(container.read(effectiveExperienceProvider), equals(EffectiveExperience.web));
    });
  });

  group('Part W1: Route Table & Back Navigation Affordance', () {
    final routes = [
      '/',
      '/groups',
      '/records',
      '/insights',
      '/insights/budgets',
      '/balances',
      '/add',
      '/group/group_flatmates',
      '/settings',
      '/settings/recurring',
    ];

    test('Iterate all routes and assert back affordance & valid fallback', () {
      for (final route in routes) {
        final isRoot = BackNavigation.isRootRoute(route);
        final parent = BackNavigation.getParentRoute(route);
        final label = BackNavigation.getParentLabel(route);

        if (isRoot) {
          expect(parent, isNull, reason: '$route is root, parent should be null');
        } else {
          expect(parent, isNotNull, reason: '$route is non-root, parent must not be null');
          expect(parent!.startsWith('/'), isTrue, reason: 'Parent must be a valid path: $parent');
          expect(label.isNotEmpty, isTrue, reason: 'Label must be non-empty for $route');
        }
      }
    });
  });

  group('Part W1: AdaptivePresenter Variants per Layout Class', () {
    testWidgets('Compact layout shows bottom sheet (using GlassSheetScaffold)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      BuildContext? testContext;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const Scaffold(body: Center(child: Text('Home')));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      AdaptivePresenter.show(
        context: testContext!,
        title: 'Compact Sheet',
        child: const Text('Sheet Content'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compact Sheet'), findsOneWidget);
      expect(find.text('Sheet Content'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('Medium/Expanded layout shows centered dialog for formOrConfirmation', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      BuildContext? testContext;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const Scaffold(body: Center(child: Text('Home')));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      AdaptivePresenter.show(
        context: testContext!,
        title: 'Dialog Form',
        type: PresentationType.formOrConfirmation,
        child: const Text('Dialog Body'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dialog Form'), findsOneWidget);
      expect(find.text('Dialog Body'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Verify max width constraint is 560
      final constrainedBoxFinder = find.ancestor(
        of: find.text('Dialog Form'),
        matching: find.byType(ConstrainedBox),
      );
      expect(constrainedBoxFinder, findsWidgets);
      final box = tester.widget<ConstrainedBox>(constrainedBoxFinder.first);
      expect(box.constraints.maxWidth, equals(560));

      // Test Esc dismiss
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Dialog Form'), findsNothing);
    });

    testWidgets('Medium/Expanded layout shows right-side drawer for detailView', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      BuildContext? testContext;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Builder(
              builder: (ctx) {
                testContext = ctx;
                return const Scaffold(body: Center(child: Text('Home')));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      AdaptivePresenter.show(
        context: testContext!,
        title: 'Drawer Detail',
        type: PresentationType.detailView,
        child: const Text('Detail Content'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Drawer Detail'), findsOneWidget);
      expect(find.text('Detail Content'), findsOneWidget);

      // Verify max width constraint is 440
      final constrainedBoxes = tester.widgetList<ConstrainedBox>(
        find.ancestor(
          of: find.text('Drawer Detail'),
          matching: find.byType(ConstrainedBox),
        ),
      );
      final drawerBox = constrainedBoxes.firstWhere(
        (box) => box.constraints.maxWidth == 440,
      );
      expect(drawerBox.constraints.maxWidth, equals(440));

      // Tap close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Drawer Detail'), findsNothing);
    });
  });

  group('Part W1: Viewport Overflow Tests', () {
    final viewports = [
      (1920.0, 1080.0, '1080p Desktop', 1.0),
      (1440.0, 900.0, '1440x900 Desktop', 1.0),
      (1366.0, 768.0, '1366x768 Laptop', 1.0),
      (1024.0, 768.0, '1024x768 Tablet Landscape', 1.0),
      (768.0, 1024.0, '768x1024 Tablet Portrait', 1.0),
      (390.0, 844.0, '390x844 Mobile', 1.0),
      (360.0, 640.0, '360x640 Mobile', 1.0),
      (360.0, 640.0, '360x640 Compact 1.3 Text Scale', 1.3),
    ];

    for (final (width, height, label, textScale) in viewports) {
      testWidgets('No overflow at $label ($width x $height)', (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final router = createAppRouter(initialLocation: '/');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceProfileProvider.overrideWithValue(
                DeviceProfile(
                  deviceClass: width >= 1024 ? DeviceClass.desktop : DeviceClass.touch,
                ),
              ),
            ],
            child: MediaQuery(
              data: MediaQueryData(
                size: Size(width, height),
                textScaler: TextScaler.linear(textScale),
              ),
              child: MaterialApp.router(
                routerConfig: router,
                theme: AppTheme.light(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check that Home rendered with zero overflow exceptions
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsWidgets);
      });
    }
  });

  group('Part W1: Mode Switch Preserves Route & State', () {
    testWidgets('Touch user switching from App to Web preserves current route and state', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final router = createAppRouter(initialLocation: '/records');

      late ProviderContainer container;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container = ProviderContainer(
            overrides: [
              deviceProfileProvider.overrideWithValue(
                const DeviceProfile(deviceClass: DeviceClass.touch),
              ),
            ],
          ),
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On touch + default (auto -> app), AppShell and DockedNavBar are present
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(DockedNavBar), findsOneWidget);
      expect(router.state.uri.toString(), equals('/records'));

      // Now switch mode to Web
      await container.read(experienceModeProvider.notifier).setMode(ExperienceMode.web);
      await tester.pumpAndSettle();

      // Effective mode is now Web -> AdaptiveWebShell replaces AppShell
      expect(find.byType(AdaptiveWebShell), findsOneWidget);
      expect(find.byType(DockedNavBar), findsNothing);

      // Route location remains unchanged
      expect(router.state.uri.toString(), equals('/records'));
    });
  });
}
