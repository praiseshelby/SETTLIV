import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/settliv_wordmark.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Round 5 Item A: Rail wordmark stays on one line', () {
    for (final height in [480.0, 600.0, 900.0]) {
      testWidgets(
        'Web medium rail wordmark renders on one line at height $height',
        (tester) async {
          tester.view.physicalSize = Size(800, height);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());
          addTearDown(() => tester.view.resetDevicePixelRatio());

          final router = createAppRouter(initialLocation: '/');
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                effectiveExperienceProvider
                    .overrideWithValue(EffectiveExperience.web),
              ],
              child: MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final wordmarkFinder = find.byType(SettlivWordmark);
          expect(wordmarkFinder, findsOneWidget);

          final textFinder = find.descendant(
            of: wordmarkFinder,
            matching: find.text('SETTLIV'),
          );
          expect(textFinder, findsOneWidget);

          final textWidget = tester.widget<Text>(textFinder);
          expect(textWidget.maxLines, 1);
          expect(textWidget.softWrap, isFalse);

          final renderParagraph = tester.renderObject<RenderParagraph>(textFinder);
          // Unrotated Text height is 1 line (~13px * 1.0), strictly < 2 lines.
          expect(renderParagraph.size.height, lessThanOrEqualTo(18.0));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
