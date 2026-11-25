import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/data/models/person.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/features/balances/presentation/balances_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Round 7: App Balances two-tier person row', () {
    for (final width in [320.0, 360.0, 430.0]) {
      for (final scale in [1.0, 1.3]) {
        for (final isDark in [false, true]) {
          testWidgets(
            'No overflow, single-line amount, 48px+ buttons, long name ellipsized at w=$width scale=$scale dark=$isDark',
            (tester) async {
              tester.view.physicalSize = Size(width, 844);
              tester.view.devicePixelRatio = 1.0;
              addTearDown(() => tester.view.resetPhysicalSize());
              addTearDown(() => tester.view.resetDevicePixelRatio());

              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    effectiveExperienceProvider
                        .overrideWithValue(EffectiveExperience.app),
                  ],
                  child: Consumer(
                    builder: (context, ref, _) {
                      // Rename first debtor to a long name to test ellipsis
                      final repo = ref.read(appRepositoryProvider);
                      final people = repo.getPeople();
                      final kabir = people.firstWhere(
                        (p) => p.name.contains('Kabir'),
                        orElse: () => people.first,
                      );
                      if (kabir.name != 'Kabir Venkataraghavan') {
                        repo.updatePerson(
                          Person(
                            id: kabir.id,
                            name: 'Kabir Venkataraghavan',
                            upiId: kabir.upiId,
                            phone: kabir.phone,
                          ),
                        );
                      }

                      return MaterialApp(
                        theme: isDark ? AppTheme.dark() : AppTheme.light(),
                        builder: (ctx, child) => MediaQuery(
                          data: MediaQuery.of(ctx).copyWith(
                            textScaler: TextScaler.linear(scale),
                          ),
                          child: child!,
                        ),
                        home: const BalancesScreen(),
                      );
                    },
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);

              // Long name ellipsizes cleanly on 1 line
              final nameFinder = find.text('Kabir Venkataraghavan');
              expect(nameFinder, findsOneWidget);
              final nameWidget = tester.widget<Text>(nameFinder);
              expect(nameWidget.maxLines, 1);
              expect(nameWidget.overflow, TextOverflow.ellipsis);

              // Amount text is single-line, softWrap false, never ellipsized
              final amountFinder = find.byWidgetPredicate(
                (w) =>
                    w is Text &&
                    (w.data?.startsWith('₹') ?? false) &&
                    w.maxLines == 1 &&
                    w.softWrap == false,
              );
              expect(amountFinder, findsWidgets);
              final amountRender =
                  tester.renderObject<RenderParagraph>(amountFinder.first);
              expect(amountRender.size.height, lessThanOrEqualTo(28.0));

              // Both Nudge & Mark received buttons >= 48px high and visible
              final nudgeBtn =
                  find.widgetWithText(OutlinedButton, 'Nudge').first;
              final markBtn =
                  find.widgetWithText(ElevatedButton, 'Mark received').first;
              expect(tester.getSize(nudgeBtn).height, greaterThanOrEqualTo(48.0));
              expect(tester.getSize(markBtn).height, greaterThanOrEqualTo(48.0));
              expect(tester.getRect(nudgeBtn).right, lessThanOrEqualTo(width));
              expect(tester.getRect(markBtn).right, lessThanOrEqualTo(width));
            },
          );
        }
      }
    }
  });
}
