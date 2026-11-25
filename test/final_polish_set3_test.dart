import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/experience_transition_overlay.dart';
import 'package:settliv/core/widgets/phone_frame.dart';
import 'package:settliv/core/widgets/settle_orbit_splash.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/features/add_expense/presentation/add_expense_screen.dart';
import 'package:settliv/features/insights/presentation/widgets/spending_calendar.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Item 7: ExperienceTransitionOverlay', () {
    testWidgets('Plays choreographed overlay on trigger and completes cleanly',
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
              child: Scaffold(body: Text('Underneath')),
            ),
          ),
        ),
      );
      await tester.pump();

      container.read(experienceTransitionProvider.notifier).trigger(
            origin: const Offset(200, 300),
            targetLabel: 'Mobile app',
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Mobile app'), findsOneWidget);
      expect(find.text('Underneath'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Mobile app'), findsNothing);
    });
  });

  group('Item 13: SettleOrbitSplash', () {
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
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('SETTLIV'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders static composed version under reduced motion',
        (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(body: SettleOrbitSplash()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('SETTLIV'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Item 12: Compact SpendingCalendar on PC Web', () {
    testWidgets('Caps container at maxWidth 440 with compact cells',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SpendingCalendar(
                expenses: SeedData.expenses,
                currentUserId: SeedData.currentUserId,
                initialDate: DateTime(2026, 11, 25),
                maxWidth: 440,
                compactCells: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.getSize(find.byType(SpendingCalendar));
      expect(box.width, lessThanOrEqualTo(440));
      expect(tester.takeException(), isNull);
    });
  });

  group('Final QA: Add Expense in all 4 layout contexts (incl. 320px & 1.3x)', () {
    testWidgets('App on phone 320x640 at textScale 1.3 has no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: AddExpenseScreen(initialTabIndex: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('App in PhoneFrame 1440x900 renders inside frame without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            builder: (context, child) => PhoneFrame(child: child!),
            home: const AddExpenseScreen(initialTabIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PhoneFrame), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
