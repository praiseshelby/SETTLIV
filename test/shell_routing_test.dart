import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/widgets/docked_nav_bar.dart';
import 'package:settliv/routes/app_router.dart';
import 'package:settliv/core/theme/app_theme.dart';

void main() {
  testWidgets('DockedNavBar is shown on shell tabs and hidden on pushed routes', (tester) async {
    final router = createAppRouter(initialLocation: '/');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // On '/' (Home), DockedNavBar is visible
    expect(find.byType(DockedNavBar), findsOneWidget);

    // Navigate to '/records' tab
    router.go('/records');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsOneWidget);

    // Navigate to '/insights' tab
    router.go('/insights');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsOneWidget);

    // Navigate to '/plan' tab
    router.go('/plan');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsOneWidget);

    // Push '/groups' (pushed route above shell, NO nav bar)
    router.push('/groups');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsNothing);

    // Push '/balances' (pushed route above shell, NO nav bar)
    router.push('/balances');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsNothing);

    // Push '/settings' (which uses parentNavigatorKey: rootNavigatorKey)
    router.push('/settings');
    await tester.pumpAndSettle();

    // DockedNavBar must be completely hidden / not present on settings screen
    expect(find.byType(DockedNavBar), findsNothing);
  });
}
