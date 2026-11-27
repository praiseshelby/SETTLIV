import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/auth/auth_provider.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/features/auth/presentation/auth_screens.dart';
import 'package:settliv/features/onboarding/domain/coach_card_placement.dart';
import 'package:settliv/features/onboarding/presentation/onboarding_tour_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CoachCardPlacementSolver unit tests', () {
    test('Places below when target is near top on 320x640 and 390x844', () {
      for (final viewport in [const Size(320, 640), const Size(390, 844)]) {
        final target = Rect.fromLTWH(20, 60, viewport.width - 40, 80);
        final cardSize = Size(
          CoachCardPlacementSolver.preferredCardWidth(
            viewportWidth: viewport.width,
            isExpandedWeb: false,
          ),
          170,
        );
        final p = CoachCardPlacementSolver.compute(
          targetRect: target,
          viewportSize: viewport,
          safePadding: const EdgeInsets.only(top: 24, bottom: 20),
          cardSize: cardSize,
          isExpandedWeb: false,
          bottomReserved: 72,
        );

        expect(p.side, CoachPlacementSide.below);
        expect(p.cardRect.overlaps(target), isFalse);
        expect(p.cardRect.left, greaterThanOrEqualTo(16));
        expect(p.cardRect.right, lessThanOrEqualTo(viewport.width - 16));
        expect(p.cardRect.bottom, lessThanOrEqualTo(viewport.height - 20 - 72 - 16));
        expect(p.cardRect.left + p.notchOffset, closeTo(target.center.dx, 25));
      }
    });

    test('Falls back to above when target is near bottom on 390x844', () {
      const viewport = Size(390, 844);
      const target = Rect.fromLTWH(20, 600, 350, 90);
      final p = CoachCardPlacementSolver.compute(
        targetRect: target,
        viewportSize: viewport,
        safePadding: const EdgeInsets.only(top: 24, bottom: 20),
        cardSize: const Size(320, 170),
        isExpandedWeb: false,
        bottomReserved: 72,
      );

      expect(p.side, CoachPlacementSide.above);
      expect(p.cardRect.overlaps(target), isFalse);
      expect(p.cardRect.top, greaterThanOrEqualTo(24 + 16));
    });

    test('Web-expanded 1280x800 prefers beside target (right/left) and clears sidebar', () {
      const viewport = Size(1280, 800);
      const target = Rect.fromLTWH(284, 180, 520, 120);
      final p = CoachCardPlacementSolver.compute(
        targetRect: target,
        viewportSize: viewport,
        safePadding: EdgeInsets.zero,
        cardSize: const Size(320, 170),
        isExpandedWeb: true,
        leftReserved: 264,
      );

      expect(p.side, CoachPlacementSide.right);
      expect(p.cardRect.overlaps(target), isFalse);
      expect(p.cardRect.left, greaterThanOrEqualTo(target.right + 10));
      expect(p.cardRect.right, lessThanOrEqualTo(viewport.width - 16));
      expect(p.cardRect.top + p.notchOffset, closeTo(target.center.dy, 25));
    });

    test('Clamps horizontally and keeps notch aimed at target center', () {
      const viewport = Size(320, 640);
      const target = Rect.fromLTWH(250, 80, 54, 60);
      final p = CoachCardPlacementSolver.compute(
        targetRect: target,
        viewportSize: viewport,
        safePadding: EdgeInsets.zero,
        cardSize: const Size(288, 160),
        isExpandedWeb: false,
      );

      expect(p.cardRect.left, greaterThanOrEqualTo(16));
      expect(p.cardRect.right, lessThanOrEqualTo(viewport.width - 16));
      expect(p.notchOffset, greaterThan(200));
    });
  });

  group('OnboardingTourScreen coach card widget tests', () {
    for (final width in [320.0, 390.0, 1280.0]) {
      for (final isDark in [false, true]) {
        testWidgets(
          'Renders without overflow at width=$width dark=$isDark and textScale=1.3',
          (tester) async {
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());
            addTearDown(() => tester.view.resetDevicePixelRatio());

            final prefs = await SharedPreferences.getInstance();
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  sharedPreferencesProvider.overrideWithValue(prefs),
                  effectiveExperienceProvider.overrideWithValue(
                    width >= 1100
                        ? EffectiveExperience.web
                        : EffectiveExperience.app,
                  ),
                ],
                child: MaterialApp(
                  theme: isDark ? AppTheme.dark() : AppTheme.light(),
                  builder: (ctx, child) => MediaQuery(
                    data: MediaQuery.of(ctx).copyWith(
                      textScaler: const TextScaler.linear(1.3),
                    ),
                    child: child!,
                  ),
                  home: const OnboardingTourScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(find.text('1 / 6'), findsOneWidget);
            expect(find.text('Skip'), findsOneWidget);
            expect(find.text('Start'), findsOneWidget);

            // Step to anchored target step 1
            await tester.tap(find.text('Start'));
            await tester.pumpAndSettle();
            expect(find.text('2 / 6'), findsOneWidget);
            expect(find.text('Back'), findsOneWidget);
            expect(find.text('Next'), findsOneWidget);
            expect(find.text('Your whole position, one number.'), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('Guest offer shows once on Explore without an account', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AuthScreen(initialMode: AuthFormMode.signIn),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Explore without an account'));
      await tester.pumpAndSettle();

      expect(find.text('Want a one-minute tour?'), findsOneWidget);
      expect(find.text('Take the tour'), findsOneWidget);
      expect(find.text('Skip to app'), findsOneWidget);

      await tester.tap(find.text('Skip to app'));
      await tester.pumpAndSettle();
      expect(prefs.getBool(OnboardingPendingNotifier.guestOfferShownKey), isTrue);
    });
  });
}
