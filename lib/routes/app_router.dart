import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/groups/presentation/groups_screen.dart';
import '../features/activity/presentation/activity_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/plan/presentation/plan_screen.dart';
import '../features/balances/presentation/balances_screen.dart';
import '../features/add_expense/presentation/add_expense_screen.dart';
import '../features/group_detail/presentation/group_detail_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/recurring_expenses_screen.dart';
import '../core/widgets/phone_frame.dart';
import '../core/widgets/app_shell.dart';
import '../core/widgets/gradient_primary_button.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_theme.dart';
import '../data/models/expense.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialLocation,
  errorBuilder: (context, state) {
    final theme = context.settliv;
    return PhoneFrame(
      child: Scaffold(
        backgroundColor: theme.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.explore_off_rounded,
                  size: 56,
                  color: theme.coral,
                ),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: AppTypography.titleLarge.copyWith(color: theme.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'The page you are looking for does not exist.',
                  style: AppTypography.body.copyWith(color: theme.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GradientPrimaryButton(
                  label: 'Home',
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  },
  routes: [
    // 4-Tab Navigation Shell: Home, Groups, Records, Insights (+ is centre button)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return PhoneFrame(
          child: AppShell(
            navigationShell: navigationShell,
          ),
        );
      },
      branches: [
        // Tab 0: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Tab 1: Groups
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/groups',
              builder: (context, state) => const GroupsScreen(),
            ),
          ],
        ),
        // Tab 2: Records
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/records',
              builder: (context, state) => const ActivityScreen(),
            ),
          ],
        ),
        // Tab 3: Insights
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/insights',
              builder: (context, state) => const InsightsScreen(),
              routes: [
                GoRoute(
                  path: 'budgets',
                  builder: (context, state) => const PlanScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // Backward-compatibility redirects
    GoRoute(
      path: '/activity',
      redirect: (context, state) => '/records',
    ),
    GoRoute(
      path: '/plan',
      redirect: (context, state) => '/insights/budgets',
    ),

    // Pushed routes (ABOVE the shell, docked bar is never shown on them)
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/balances',
      builder: (context, state) => const PhoneFrame(
        child: BalancesScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/add',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final initialExpense = extra?['initialExpense'] as Expense?;
        final initialText = extra?['initialText'] as String?;
        final preselectedGroupId = extra?['preselectedGroupId'] as String?;
        final initialTabIndex = (extra?['initialTabIndex'] as int?) ?? 0;

        return CustomTransitionPage<String?>(
          key: state.pageKey,
          child: PhoneFrame(
            child: AddExpenseScreen(
              initialExpense: initialExpense,
              initialText: initialText,
              preselectedGroupId: preselectedGroupId,
              initialTabIndex: initialTabIndex,
            ),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/group/:id',
      builder: (context, state) {
        final groupId = state.pathParameters['id'] ?? '';
        return PhoneFrame(
          child: GroupDetailScreen(groupId: groupId),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings',
      builder: (context, state) => const PhoneFrame(
        child: SettingsScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings/recurring',
      builder: (context, state) => const PhoneFrame(
        child: RecurringExpensesScreen(),
      ),
    ),
  ],
);

final appRouter = createAppRouter();
