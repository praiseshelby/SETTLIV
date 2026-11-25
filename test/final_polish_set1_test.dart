import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/balance_hero_card.dart';
import 'package:settliv/core/widgets/feature_coming_sheet.dart';
import 'package:settliv/core/widgets/person_avatar.dart';
import 'package:settliv/core/widgets/phone_frame.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/features/add_expense/presentation/add_expense_screen.dart';
import 'package:settliv/features/home/presentation/home_screen.dart';
import 'package:settliv/features/settings/presentation/settings_screen.dart';

double _relativeLuminance(Color c) {
  double linear(double ch) =>
      ch <= 0.03928 ? ch / 12.92 : math.pow((ch + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
}

double _contrastRatio(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final bright = math.max(l1, l2);
  final dark = math.min(l1, l2);
  return (bright + 0.05) / (dark + 0.05);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Item 6: Add Expense Manual & Quick', () {
    testWidgets(
      'Manual tab: empty amount shows validation after attempt; valid amount adds 1 expense',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
          ],
        );
        addTearDown(container.dispose);

        final initialCount = container.read(allExpensesProvider).length;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const AddExpenseScreen(initialTabIndex: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Before attempt, validation caption is hidden
        expect(find.text('Add an amount to continue'), findsNothing);

        // Tap primary button with empty amount -> shows validation caption
        await tester.tap(find.text('Add expense'));
        await tester.pumpAndSettle();
        expect(find.text('Add an amount to continue'), findsOneWidget);
        expect(container.read(allExpensesProvider).length, initialCount);

        // Enter valid amount 600
        await tester.enterText(find.byType(TextField).first, '600');
        await tester.pumpAndSettle();

        // Tap primary button -> adds exactly 1 expense
        await tester.tap(find.text('Add ₹600 to Flatmates'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(container.read(allExpensesProvider).length, initialCount + 1);
      },
    );
  });

  group('Item 11: Reactive single source of truth', () {
    testWidgets(
      'Updating profile name updates Home avatar and Settings header immediately; adding expense updates hero & group balance',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Column(
                children: [
                  Expanded(child: HomeScreen()),
                  Expanded(child: SettingsScreen()),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Change profile name
        container.read(appStateProvider.notifier).updateCurrentUser(name: 'Riya Sharma');
        await tester.pump();

        expect(find.text('Riya Sharma'), findsWidgets);
        // Home avatar initials should reflect RS
        final homeAvatars = tester.widgetList<PersonAvatar>(find.byType(PersonAvatar));
        expect(homeAvatars.any((a) => a.person?.avatarInitials == 'RS'), isTrue);

        // Record initial hero net balance and Flatmates balance
        final beforeOverall = container.read(userOverallBalanceProvider).netBalance;
        final beforeGroup = container.read(groupSummaryProvider('group_flatmates')).userNetBalance;

        // Add an expense via notifier
        final existing = container.read(allExpensesProvider).first;
        container.read(appStateProvider.notifier).addExpense(
              existing.copyWith(
                id: 'exp_reactive_test',
                amount: 30000,
                shares: const {
                  'person_arjun': 10000,
                  'person_meera': 10000,
                  'person_kabir': 10000,
                },
                paidBy: 'person_arjun',
                groupId: 'group_flatmates',
                date: DateTime.now(),
              ),
            );
        await tester.pump();

        expect(
          container.read(userOverallBalanceProvider).netBalance,
          beforeOverall + 20000,
        );
        expect(
          container.read(groupSummaryProvider('group_flatmates')).userNetBalance,
          beforeGroup + 20000,
        );
      },
    );
  });

  group('Item 2: FeatureComingSheet containment in App-in-frame', () {
    testWidgets(
      'Opening FeatureComingSheet from Settings in PhoneFrame stays inside frame bounds',
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
              theme: AppTheme.light(),
              builder: (context, child) => PhoneFrame(child: child!),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final frameFinder = find.byType(PhoneFrame);
        expect(frameFinder, findsOneWidget);

        // Scroll to and tap Screen & biometric lock
        final lockTile = find.text('Screen & biometric lock');
        await tester.ensureVisible(lockTile);
        await tester.tap(lockTile);
        await tester.pumpAndSettle();

        final sheetFinder = find.byType(FeatureComingSheet);
        expect(sheetFinder, findsOneWidget);

        // Verify sheet bounds lie within PhoneFrame's inner screen ClipRRect
        final screenClip = find.descendant(
          of: frameFinder,
          matching: find.byType(ClipRRect),
        ).first;
        final frameRect = tester.getRect(screenClip);
        final sheetRect = tester.getRect(sheetFinder);
        expect(sheetRect.left >= frameRect.left - 1, isTrue);
        expect(sheetRect.right <= frameRect.right + 1, isTrue);
        expect(sheetRect.bottom <= frameRect.bottom + 1, isTrue);
      },
    );
  });

  group('Item 1: BalanceHeroCard AA contrast in light & dark themes', () {
    test('Hero primary text, muted text, owed & owe accents pass AA (>= 4.5:1)', () {
      for (final ext in [SettlivThemeExtension.light, SettlivThemeExtension.dark]) {
        final bgStart = ext.heroMeshStart;
        final bgEnd = ext.heroMeshEnd;
        final primaryText = ext.isDark ? ext.white : ext.ink;
        final secondaryText = ext.isDark ? ext.white : ext.muted;
        final owedText = ext.isDark ? ext.textEmerald : ext.textEmerald;
        final oweText = ext.isDark ? ext.textCoral : ext.textCoral;

        expect(_contrastRatio(primaryText, bgStart), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(primaryText, bgEnd), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(secondaryText, bgStart), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(owedText, bgEnd), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(oweText, bgEnd), greaterThanOrEqualTo(4.5));
      }
    });

    testWidgets('BalanceHeroCard uses light pearl-lavender in light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: BalanceHeroCard(
              netPaise: 86000,
              totalOwedToUserPaise: 124000,
              totalUserOwesPaise: 38000,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Light mode heroMeshStart should be light (luminance > 0.7), not dark navy
      expect(_relativeLuminance(SettlivThemeExtension.light.heroMeshStart), greaterThan(0.7));
    });
  });
}
