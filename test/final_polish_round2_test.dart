import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/experience_transition_overlay.dart';
import 'package:settliv/core/widgets/settle_orbit_splash.dart';
import 'package:settliv/features/settings/presentation/settings_screen.dart';
import 'package:settliv/routes/app_router.dart';

double _lum(Color c) {
  double lin(double ch) =>
      ch <= 0.03928 ? ch / 12.92 : math.pow((ch + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * lin(c.red / 255.0) + 0.7152 * lin(c.green / 255.0) + 0.0722 * lin(c.blue / 255.0);
}

double _contrast(Color a, Color b) {
  final l1 = _lum(a);
  final l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Fix 4: Recurring expenses icon adapts in light & dark themes', () {
    testWidgets('Icon color differs between themes and passes AA contrast',
        (tester) async {
      Color? lightIconColor;
      Color? darkIconColor;

      for (final isDark in [false, true]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              effectiveExperienceProvider
                  .overrideWithValue(EffectiveExperience.app),
            ],
            child: MaterialApp(
              theme: isDark ? AppTheme.dark() : AppTheme.light(),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.byIcon(Icons.repeat_rounded);
        await tester.ensureVisible(iconFinder);
        final iconWidget = tester.widget<Icon>(iconFinder);
        if (isDark) {
          darkIconColor = iconWidget.color;
        } else {
          lightIconColor = iconWidget.color;
        }
      }

      expect(lightIconColor, isNotNull);
      expect(darkIconColor, isNotNull);
      expect(lightIconColor, isNot(equals(darkIconColor)));
      expect(
        _contrast(lightIconColor!, SettlivThemeExtension.light.surfaceSolid),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(darkIconColor!, SettlivThemeExtension.dark.surfaceSolid),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('Fix 1: Sidebar Add expense button alignment & dark-mode contrast', () {
    testWidgets('Icon and label vertical centers match within 1px',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = createAppRouter(initialLocation: '/');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider
                .overrideWithValue(EffectiveExperience.web),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labelFinder = find.text('Add expense');
      final iconFinder = find.byIcon(Icons.add_rounded).first;
      expect(labelFinder, findsOneWidget);
      expect(iconFinder, findsOneWidget);

      final labelCenterY = tester.getCenter(labelFinder).dy;
      final iconCenterY = tester.getCenter(iconFinder).dy;
      expect((labelCenterY - iconCenterY).abs(), lessThanOrEqualTo(1.0));
    });
  });

  group('Fix 2: Device-morph App <-> Web transition without words', () {
    testWidgets('Renders device-morph CustomPaint with no target-name text',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ExperienceTransitionOverlay(
              child: Scaffold(body: Text('Content')),
            ),
          ),
        ),
      );
      await tester.pump();

      container.read(experienceTransitionProvider.notifier).trigger(
            fromWeb: true,
            toWeb: false,
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Mobile app'), findsNothing);
      expect(find.text('PC website'), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Fix 3: Cinematic Settle Orbit loading screen', () {
    for (final size in [const Size(360, 800), const Size(1920, 1080)]) {
      testWidgets('Renders cleanly at ${size.width}x${size.height}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SettleOrbitSplash()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1200));

        expect(find.text('S'), findsOneWidget);
        expect(find.text('V'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
