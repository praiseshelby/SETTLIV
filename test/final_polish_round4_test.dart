import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/features/insights/presentation/widgets/insights_web_view.dart';

void main() {
  group('Final Polish Round 4', () {
    test('InsightsWebView.formatSpendDelta uses absolute difference on tiny baseline and never a percentage', () {
      // Baseline ₹1,000 (100,000 paise) -> ₹36,239 (3,623,900 paise)
      final tinyBaseline = InsightsWebView.formatSpendDelta(3623900, 100000);
      expect(tinyBaseline, '₹35,239 more than last month');
      expect(tinyBaseline.contains('%'), isFalse);

      // Baseline ₹6,000 (600,000 paise) -> ₹30,000 (3,000,000 paise) (> 300% change)
      final hugeChange = InsightsWebView.formatSpendDelta(3000000, 600000);
      expect(hugeChange, '₹24,000 more than last month');
      expect(hugeChange.contains('%'), isFalse);

      // Baseline ₹10,000 -> ₹12,500 (normal 25% change)
      final normal = InsightsWebView.formatSpendDelta(1250000, 1000000);
      expect(normal, '25% more than last month');
    });

    testWidgets('InsightsWebView renders aligned 12-col bento without overflow at 1366x768', (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: InsightsWebView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL SPEND (YOUR SHARE)'), findsOneWidget);
      expect(find.text('SPENDING HABITS'), findsOneWidget);
      expect(find.text('MONTH IN REVIEW'), findsOneWidget);
      expect(find.text('DEBTS & SETTLEMENTS'), findsOneWidget);
      expect(find.text('BY CATEGORY'), findsOneWidget);
      expect(find.text('SPENDING CALENDAR'), findsOneWidget);
      expect(find.text('BY GROUP & PERSONAL'), findsOneWidget);
      expect(find.text('Reconciled with Records'), findsNothing);
    });
  });
}
