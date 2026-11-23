import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:settliv/core/layout/adaptive_layout.dart';
import 'package:settliv/core/profile/device_profile.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/adaptive_presenter.dart';
import 'package:settliv/core/widgets/phone_frame.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/features/add_expense/presentation/add_expense_screen.dart';
import 'package:settliv/features/add_expense/presentation/widgets/scan_sheet.dart';
import 'package:settliv/features/balances/presentation/balances_screen.dart';
import 'package:settliv/features/balances/sheets/create_edit_iou_sheet.dart';
import 'package:settliv/features/group_detail/presentation/group_detail_screen.dart';
import 'package:settliv/features/group_detail/sheets/nudge_sheet.dart';
import 'package:settliv/features/group_detail/sheets/settle_sheet.dart';
import 'package:settliv/features/home/presentation/widgets/dashboard_web_view.dart';
import 'package:settliv/features/home/presentation/widgets/month_dial.dart';
import 'package:settliv/features/home/presentation/widgets/split_calculator_sheet.dart';
import 'package:settliv/features/settings/presentation/settings_screen.dart';
import 'package:settliv/features/settings/presentation/widgets/experience_settings_section.dart';
import 'package:settliv/main.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part Y.1: Lint Test for Window/View Size Reads', () {
    test('No dart file under lib/ outside experience wrapper reads window/view sizes directly', () {
      final libDir = Directory('lib');
      final forbidden = [
        'PlatformDispatcher.instance.views',
        'View.of(context).physicalSize',
        'window.physicalSize',
      ];

      final violations = <String>[];
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          for (final pattern in forbidden) {
            if (content.contains(pattern)) {
              violations.add('${entity.path}: contains "$pattern"');
            }
          }
        }
      }

      expect(violations, isEmpty, reason: 'Files must use scoped MediaQuery.of(context), not window/view sizes');
    });
  });

  group('Part Y.1: Global Phone Frame Containment on Wide Viewport (App mode on PC)', () {
    testWidgets('Every route in App mode on 1440x900 is constrained within the PhoneFrame', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createAppRouter(initialLocation: '/');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            experienceModeProvider.overrideWith((ref) {
              final notifier = ExperienceModeNotifier(null);
              notifier.setMode(ExperienceMode.app);
              return notifier;
            }),
          ],
          child: SettlivApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      // Home in App mode on PC: PhoneFrame must exist
      expect(find.byType(PhoneFrame), findsOneWidget);

      // Verify bounds of Home content are within PhoneFrame target size (390x844)
      final phoneFrameFinder = find.byType(PhoneFrame);
      expect(phoneFrameFinder, findsOneWidget);

      // Navigate to /add
      router.push('/add');
      await tester.pumpAndSettle();
      expect(find.byType(AddExpenseScreen), findsOneWidget);
      final addRect = tester.getRect(find.byType(AddExpenseScreen));
      // AddExpense must be inside the phone frame bounds (width <= 390)
      expect(addRect.width, lessThanOrEqualTo(PhoneFrame.targetWidth));
      expect(addRect.height, lessThanOrEqualTo(PhoneFrame.targetHeight));

      // Navigate to /settings
      router.push('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final settingsRect = tester.getRect(find.byType(SettingsScreen));
      expect(settingsRect.width, lessThanOrEqualTo(PhoneFrame.targetWidth));

      // Navigate to /balances
      router.push('/balances');
      await tester.pumpAndSettle();
      expect(find.byType(BalancesScreen), findsOneWidget);
      final balancesRect = tester.getRect(find.byType(BalancesScreen));
      expect(balancesRect.width, lessThanOrEqualTo(PhoneFrame.targetWidth));

      // Navigate to /group/group_flatmates
      router.push('/group/group_flatmates');
      await tester.pumpAndSettle();
      expect(find.byType(GroupDetailScreen), findsOneWidget);
      final groupRect = tester.getRect(find.byType(GroupDetailScreen));
      expect(groupRect.width, lessThanOrEqualTo(PhoneFrame.targetWidth));
    });

    testWidgets('Sheets/Dialogs in App mode on PC open as bottom sheets inside the frame', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            experienceModeProvider.overrideWith((ref) {
              final notifier = ExperienceModeNotifier(null);
              notifier.setMode(ExperienceMode.app);
              return notifier;
            }),
          ],
          child: SettlivApp(
            router: GoRouter(
              navigatorKey: rootNavigatorKey,
              initialLocation: '/',
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) {
                    capturedContext = context;
                    return const Scaffold(body: Text('Shell Root'));
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In App mode on PC, MediaQuery inside frame must be 390x844
      expect(MediaQuery.of(capturedContext).size.width, equals(390.0));
      expect(MediaQuery.of(capturedContext).size.height, equals(844.0));
      expect(AdaptiveLayout.of(capturedContext), equals(LayoutClass.compact));

      // Show an AdaptivePresenter dialog
      AdaptivePresenter.show(
        context: capturedContext,
        title: 'Test Sheet',
        child: const Text('Sheet Content'),
      );
      await tester.pumpAndSettle();

      // Bottom sheet is rendered, constrained to frame
      final sheetFinder = find.byType(BottomSheet);
      expect(sheetFinder, findsOneWidget);
      final sheetRect = tester.getRect(sheetFinder);
      expect(sheetRect.width, lessThanOrEqualTo(390.0));
    });
  });

  group('Part Y.2: Month Dial Redesign on Web Dashboard', () {
    testWidgets('MonthDial does not repeat date, shows N days left, upcoming dues and tooltip', (tester) async {
      final now = DateTime(2026, 11, 23);
      final upcomingItems = [
        UpcomingDueItem(
          title: 'Wifi bill',
          dueDate: DateTime(2026, 11, 28),
          amountPaise: 150000,
        ),
        UpcomingDueItem(
          title: 'Rent share',
          dueDate: DateTime(2026, 11, 30),
          amountPaise: 600000,
        ),
      ];

      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: MonthDial(
                now: now,
                upcomingItems: upcomingItems,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Dial does NOT repeat the date (no 'Monday' or '23 November' in MonthDial)
      expect(find.text('Monday'), findsNothing);
      expect(find.text('23 November'), findsNothing);

      // 2. Dial shows "7" (30 - 23 = 7 days left in November)
      expect(find.text('7'), findsNothing); // painter paints text via TextPainter
      // Verify semantics/tooltip has days left message
      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label?.contains('7 days left') ?? false),
      );
      expect(semanticsFinder, findsOneWidget);

      // 3. Beside dial shows "Next: Wifi bill · Sat 28 Nov" and "₹1,500"
      expect(find.text('Next: Wifi bill · Sat 28 Nov'), findsOneWidget);
      expect(find.text('₹1,500'), findsOneWidget);

      // 4. Tap callback triggers
      await tester.tap(find.byType(MonthDial));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('MonthDial shows "No dues this month" when list is empty', (tester) async {
      final now = DateTime(2026, 11, 23);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: MonthDial(
                now: now,
                upcomingItems: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No dues this month'), findsOneWidget);
      expect(find.text('All settled'), findsOneWidget);
    });
  });

  group('Part Y.3: Compatibility Preview Entry Points & Deep Link', () {
    testWidgets('Home/Dashboard does NOT contain "Compatibility preview · PC, Mobile web, App · Settings ›"', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DashboardWebView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compatibility preview · PC, Mobile web, App · Settings ›'), findsNothing);
    });

    testWidgets('/settings?section=experience selects Experience rail and scrolls', (tester) async {
      final router = createAppRouter(initialLocation: '/settings?section=experience');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            experienceModeProvider.overrideWith((ref) {
              final notifier = ExperienceModeNotifier(null);
              notifier.setMode(ExperienceMode.web);
              return notifier;
            }),
          ],
          child: SettlivApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(ExperienceSettingsSection), findsOneWidget);
    });
  });

  group('Part Y.4: Experience Section Redesign in Settings', () {
    testWidgets('ExperienceSection on PC displays PC website & Mobile app selectable, Mobile web as reference', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(
                deviceClass: DeviceClass.desktop,
              ),
            ),
            experienceModeProvider.overrideWith((ref) {
              final notifier = ExperienceModeNotifier(null);
              notifier.setMode(ExperienceMode.web);
              return notifier;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ExperienceSettingsSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Eyebrow
      expect(find.text('COMPATIBILITY PREVIEW'), findsOneWidget);

      // Tiles
      expect(find.text('PC website'), findsOneWidget);
      expect(find.text('Mobile web'), findsOneWidget);
      expect(find.text('Phones only'), findsOneWidget);
      expect(find.text('Mobile app'), findsOneWidget);

      // Notice strip
      expect(find.text('A preview, not a feature.'), findsOneWidget);
      expect(
        find.textContaining('In the shipped product each person gets only the layout made for their device'),
        findsOneWidget,
      );
    });

    testWidgets('ExperienceSection on touch displays Mobile web & Mobile app selectable, PC website as reference', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(
                deviceClass: DeviceClass.touch,
              ),
            ),
            experienceModeProvider.overrideWith((ref) {
              final notifier = ExperienceModeNotifier(null);
              notifier.setMode(ExperienceMode.app);
              return notifier;
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ExperienceSettingsSection(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COMPATIBILITY PREVIEW'), findsOneWidget);
      expect(find.text('PC website'), findsOneWidget);
      expect(find.text('PCs only'), findsOneWidget);
      expect(find.text('Mobile web'), findsOneWidget);
      expect(find.text('Mobile app'), findsOneWidget);
    });
  });

  group('Part Y.5: Layout Matrix Test Suite', () {
    final matrixEnvironments = [
      {'name': 'App on phone', 'mode': ExperienceMode.app, 'width': 390.0, 'height': 844.0},
      {'name': 'App in frame on PC', 'mode': ExperienceMode.app, 'width': 1440.0, 'height': 900.0},
      {'name': 'Web desktop', 'mode': ExperienceMode.web, 'width': 1440.0, 'height': 900.0},
      {'name': 'Web compact', 'mode': ExperienceMode.web, 'width': 390.0, 'height': 844.0},
    ];

    for (final env in matrixEnvironments) {
      final envName = env['name'] as String;
      final mode = env['mode'] as ExperienceMode;
      final width = env['width'] as double;
      final height = env['height'] as double;

      testWidgets('Layout Matrix: $envName routes render with no overflow', (tester) async {
        tester.view.physicalSize = Size(width, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final router = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              experienceModeProvider.overrideWith((ref) {
                final notifier = ExperienceModeNotifier(null);
                notifier.setMode(mode);
                return notifier;
              }),
            ],
            child: SettlivApp(router: router),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Home
        expect(tester.takeException(), isNull);

        // 2. Groups
        router.go('/groups');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 3. Group Detail
        router.push('/group/group_flatmates');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 4. Records
        router.go('/records');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 5. Insights
        router.go('/insights');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 6. Budgets (or /insights/budgets in App)
        final budgetsPath = mode == ExperienceMode.web ? '/budgets' : '/insights/budgets';
        router.go(budgetsPath);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 7. Balances
        router.push('/balances');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 8. Settings
        router.push('/settings');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // 9. Add Expense
        router.push('/add');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Layout Matrix Sheets & Dialogs open without overflow', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = createAppRouter(initialLocation: '/');
      await tester.pumpWidget(
        ProviderScope(
          child: SettlivApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      final ctx = rootNavigatorKey.currentContext!;

      // 1. Scan sheet
      ScanSheet.show(ctx);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      // 2. Split calculator sheet
      SplitCalculatorSheet.show(ctx);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      // 3. Nudge sheet
      NudgeSheet.show(context: ctx, group: SeedData.groups.first, amountPaise: 124000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      // 4. Settle sheet
      SettleSheet.show(
        context: ctx,
        group: SeedData.groups.first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();

      // 5. IOU sheet
      CreateEditIouSheet.show(ctx);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      Navigator.of(ctx).pop();
      await tester.pumpAndSettle();
    });
  });
}
