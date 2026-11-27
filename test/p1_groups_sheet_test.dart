import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/data/engine/balance_engine.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/features/groups/presentation/widgets/create_edit_group_sheet.dart';
import 'package:settliv/features/groups/presentation/widgets/group_hub_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P1: GroupHubCard & FormSheetScaffold', () {
    testWidgets('GroupHubCard is single tap target to Group Detail with no Details button', (tester) async {
      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (ctx, _) => Scaffold(
              body: SingleChildScrollView(
                child: GroupHubCard(
                  group: SeedData.goaTrip,
                  members: SeedData.people.take(3).toList(),
                  summary: const BalanceEngine().computeGroupSummary(
                    groupId: SeedData.goaTrip.id,
                    memberIds: SeedData.goaTrip.memberIds,
                    expenses: SeedData.expenses,
                    settlements: SeedData.settlements,
                  ),
                  expenses: SeedData.expenses
                      .where((e) => e.groupId == SeedData.goaTrip.id)
                      .toList(),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/group/:id',
            builder: (ctx, state) {
              pushedRoute = state.uri.toString();
              return const Scaffold(body: Text('Detail'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsNothing);
      await tester.tap(find.text('Goa Trip'));
      await tester.pumpAndSettle();
      expect(pushedRoute, '/group/${SeedData.goaTrip.id}');
    });

    for (final size in [
      const Size(320, 568),
      const Size(360, 640),
      const Size(390, 844),
    ]) {
      testWidgets(
        'CreateEditGroupSheet sticky Create group button is visible and tappable at $size with keyboard open and textScale 1.3',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());
          addTearDown(() => tester.view.resetDevicePixelRatio());

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: AppTheme.light(),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    viewInsets: const EdgeInsets.only(bottom: 300),
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: const Scaffold(
                    body: CreateEditGroupSheet(),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final createBtn = find.text('Create group');
          expect(createBtn, findsOneWidget);
          await tester.tap(createBtn, warnIfMissed: true);
          await tester.pumpAndSettle();

          expect(find.text('Group name is required'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('Manual member form validates UPI format inline', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: CreateEditGroupSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+ Add member'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Member name (Required)'), 'Vikram');
      await tester.enterText(find.widgetWithText(TextField, 'UPI ID (optional)'), 'invalid-upi');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid UPI ID format (e.g. name@bank)'), findsOneWidget);
    });
  });
}
