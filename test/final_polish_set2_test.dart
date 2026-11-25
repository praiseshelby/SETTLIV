import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/first_visit_compatibility_card.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/features/home/presentation/widgets/month_dial.dart';
import 'package:settliv/features/home/presentation/widgets/this_month_web_card.dart';
import 'package:settliv/features/settings/presentation/settings_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Item 3: Compatibility preview message', () {
    testWidgets('FirstVisitCompatibilityCard renders nothing on desktop 1440x900',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: FirstVisitCompatibilityCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compatibility preview'), findsNothing);
    });

    testWidgets('CompatibilityPreviewSheet shows 3 wireframe tiles and Got it / View layouts',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: CompatibilityPreviewSheet(
              effectiveExperience: EffectiveExperience.web,
              isCompact: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Compatibility preview'), findsOneWidget);
      expect(find.text('PC website'), findsOneWidget);
      expect(find.text('Mobile web'), findsOneWidget);
      expect(find.text('Mobile app'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('View layouts'), findsOneWidget);
    });
  });

  group('Item 10: PC Web Settings two-column + dot rail', () {
    testWidgets('Desktop Settings removes left section list and shows sticky summary + dot rail',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account & Theme'), findsNothing);
      expect(find.text('Edit profile'), findsOneWidget);
      expect(find.text('Current layout: PC website'), findsOneWidget);
    });
  });

  group('Item 4: ThisMonthWebCard', () {
    testWidgets('Renders cumulative chart, Daily average, and Biggest expense',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 460,
              child: ThisMonthWebCard(
                expenses: SeedData.expenses,
                currentUserId: SeedData.currentUserId,
                now: DateTime.now(),
                thisMonthSpend: 250000,
                lastMonthSpend: 300000,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Daily average'), findsOneWidget);
      expect(find.text('Biggest expense'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('Item 5: MonthDial text clearance & no text scaling inside ring', () {
    testWidgets('MonthDial renders cleanly even at high textScaleFactor',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: Scaffold(
              body: MonthDial(
                now: DateTime(2026, 11, 25),
                upcomingItems: [
                  UpcomingDueItem(
                    title: 'Wifi & broadband',
                    dueDate: DateTime(2026, 11, 28),
                    amountPaise: 150000,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('days left'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
