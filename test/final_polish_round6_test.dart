import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/phone_frame.dart';
import 'package:settliv/data/engine/person_balance_engine.dart';
import 'package:settliv/data/models/person.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/features/balances/presentation/balances_screen.dart';
import 'package:settliv/features/group_detail/sheets/mark_received_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Round 6 Item A: Mark received for people who owe me', () {
    testWidgets('1 & 4: Full receipt zeroes balance, removes row, updates hero & group in same frame', (tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.light(),
                home: const BalancesScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialOverall = container.read(userOverallBalanceProvider);
      expect(initialOverall.totalOwedToUser, greaterThan(0));

      // Tap the first 'Mark received' button on Owed to you tab
      final markBtn = find.widgetWithText(ElevatedButton, 'Mark received').first;
      expect(markBtn, findsOneWidget);
      await tester.tap(markBtn);
      await tester.pumpAndSettle();

      // Primary submit button should be prefilled with full owed amount
      final submitBtn = find.byType(ElevatedButton).last;
      await tester.tap(submitBtn);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Balance & hero totals updated immediately
      final afterOverall = container.read(userOverallBalanceProvider);
      expect(afterOverall.totalOwedToUser, lessThan(initialOverall.totalOwedToUser));
      expect(find.text('SETTLED RECENTLY'), findsOneWidget);
    });

    testWidgets('2 & 3 & 6: Partial receipt leaves exact remainder, Undo restores state, per-person sums match group net', (tester) async {
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                theme: AppTheme.light(),
                home: const BalancesScreen(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final repo = container.read(appRepositoryProvider);
      final summariesBefore = PersonBalanceEngine.computePersonSummaries(repo);
      final debtorSummary = summariesBefore.firstWhere((s) => s.personOwesUser);
      final originalOwed = debtorSummary.amountPaise;

      await tester.tap(find.widgetWithText(ElevatedButton, 'Mark received').first);
      await tester.pumpAndSettle();

      // Enter partial amount ₹200 (20000 paise)
      await tester.enterText(find.byType(TextField).first, '200');
      await tester.pump();
      await tester.tap(find.text('Cash'));
      await tester.pump();

      await tester.tap(find.text('Mark ₹200 received'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final summariesAfter = PersonBalanceEngine.computePersonSummaries(repo);
      final updatedDebtor = summariesAfter.firstWhere((s) => s.person.id == debtorSummary.person.id);
      expect(updatedDebtor.amountPaise, originalOwed - 20000);

      // Verify per-person balances sum to group net for every shared group
      for (final g in repo.getGroups().where((g) => !g.isPersonal)) {
        final gSum = repo.getGroupSummary(g.id);
        final netSum = gSum.netBalances.values.fold<int>(0, (a, b) => a + b);
        expect(netSum, 0);
      }

      // Undo restores exact previous state
      await tester.tap(find.text('Undo').last);
      await tester.pumpAndSettle();

      final summariesRestored = PersonBalanceEngine.computePersonSummaries(repo);
      final restoredDebtor = summariesRestored.firstWhere((s) => s.person.id == debtorSummary.person.id);
      expect(restoredDebtor.amountPaise, originalOwed);
    });

    testWidgets('5: MarkReceivedSheet stays inside PhoneFrame and button is visible without scrolling at 320px & textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      const payer = Person(id: 'p_test', name: 'Kabir');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: const Size(320, 680),
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: PhoneFrame(child: child!),
              );
            },
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => MarkReceivedSheet.show(
                      context: context,
                      payer: payer,
                      maxAmountPaise: 124000,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final btnFinder = find.text('Mark ₹1,240 received');
      expect(btnFinder, findsOneWidget);
      final btnBox = tester.getRect(btnFinder);
      final phoneBox = tester.getRect(find.byType(PhoneFrame));
      expect(btnBox.left, greaterThanOrEqualTo(phoneBox.left));
      expect(btnBox.right, lessThanOrEqualTo(phoneBox.right));
      expect(btnBox.bottom, lessThanOrEqualTo(phoneBox.bottom));
      expect(tester.takeException(), isNull);
    });
  });
}
