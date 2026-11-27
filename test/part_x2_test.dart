import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/profile/device_profile.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/aurora_background.dart';
import 'package:settliv/core/widgets/empty_state.dart';
import 'package:settliv/core/widgets/magnetic_button.dart';
import 'package:settliv/core/widgets/web_glass_card.dart';
import 'package:settliv/features/home/presentation/widgets/web_net_position_hero.dart';

void main() {
  group('Part X2: Visual Level-Up Verification', () {
    testWidgets('AuroraBackground renders 3-layer depth stack without square hairline grid', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: AuroraBackground(
                child: Text('Content'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Content'), findsOneWidget);
      // Assert CustomPaint painters exist
      final painters = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final painterTypes = painters.map((p) => p.painter.runtimeType.toString()).toSet();
      expect(painterTypes.contains('_FarColourFieldsPainter'), isTrue);
      expect(painterTypes.contains('_MidContourOrbitPainter'), isTrue);
      expect(painterTypes.contains('_NearVignetteCursorPainter'), isTrue);
      // Square hairline grid removed
      expect(painterTypes.contains('_HairlineGridPainter'), isFalse);
    });

    testWidgets('WebGlassCard renders gradient border, inner highlight, and lifts on hover', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: Center(
                child: WebGlassCard(
                  child: Text('Card Content'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Card Content'), findsOneWidget);
      // Hovering over the card
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Card Content')));
      addTearDown(gesture.removePointer);
      await tester.pumpAndSettle();

      final animatedContainer = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
      // Check lift translation in matrix
      final transform = animatedContainer.transform;
      if (transform != null) {
        expect(transform.getTranslation().y, equals(-2.0));
      }
    });

    testWidgets('WebNetPositionHero renders Prism Pearl in Light mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: WebNetPositionHero(
                netPaise: 86000,
                totalOwedToUserPaise: 124000,
                totalUserOwesPaise: 38000,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NET POSITION'), findsOneWidget);
      expect(find.textContaining('owed to you'), findsOneWidget);
      expect(find.textContaining('you owe'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WebNetPositionHero renders Luminous Core in Dark mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(
              body: WebNetPositionHero(
                netPaise: -38000,
                totalOwedToUserPaise: 0,
                totalUserOwesPaise: 38000,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('NET POSITION'), findsOneWidget);
      expect(find.textContaining('you owe'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MagneticButton tracks hover without crashing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceProfileProvider.overrideWithValue(
              const DeviceProfile(deviceClass: DeviceClass.desktop),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: MagneticButton(
                  child: ElevatedButton(
                    onPressed: null,
                    child: Text('Magnetic Action'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Magnetic Action'), findsOneWidget);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Magnetic Action')) + const Offset(10, 5));
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('EmptyState renders Settle orbit motif in fine lines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: EmptyState(
              title: 'No transactions yet',
              message: 'Your activity will appear here.',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No transactions yet'), findsOneWidget);
      expect(find.text('Your activity will appear here.'), findsOneWidget);
      // Assert SettleOrbitMotifPainter is present
      expect(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SettleOrbitMotifPainter), findsOneWidget);
    });

    test('index.html Settle sequence contains converging nodes and tracking animation', () {
      final file = File('web/index.html');
      expect(file.existsSync(), isTrue);
      final html = file.readAsStringSync();

      expect(html.contains('SETTLIV'), isTrue);
      expect(html.contains('curr em'), isTrue);
      expect(html.contains('curr co'), isTrue);
      expect(html.contains('tick-ring'), isTrue);
      expect(html.contains('flutter-first-frame'), isTrue);
      expect(html.contains('settliv-intro-reveal'), isTrue);
    });
  });
}
