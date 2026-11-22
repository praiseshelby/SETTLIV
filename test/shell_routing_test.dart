import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/widgets/docked_nav_bar.dart';
import 'package:settliv/routes/app_router.dart';
import 'package:settliv/core/theme/app_theme.dart';

void main() {
  testWidgets('DockedNavBar is shown on all 4 shell tabs and hidden on pushed routes', (tester) async {
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

    // Tab 0: Home ('/') -> DockedNavBar visible
    expect(find.byType(DockedNavBar), findsOneWidget);

    // Tab 1: Groups ('/groups') -> DockedNavBar visible
    router.go('/groups');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsOneWidget);

    // Tab 2: Records ('/records') -> DockedNavBar visible
    router.go('/records');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsOneWidget);

    // Tab 3: Insights ('/insights') -> DockedNavBar visible
    router.go('/insights');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsOneWidget);

    // /plan redirects to /insights/budgets
    router.go('/plan');
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), equals('/insights/budgets'));

    // Push '/balances' (pushed route above shell, NO nav bar)
    router.push('/balances');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsNothing);

    // Push '/settings' (pushed route above shell, NO nav bar)
    router.push('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsNothing);

    // Push '/add' (pushed route above shell, NO nav bar)
    router.push('/add');
    await tester.pumpAndSettle();
    expect(find.byType(DockedNavBar), findsNothing);
  });
}
