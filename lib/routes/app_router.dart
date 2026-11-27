import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth/auth_provider.dart';
import '../core/auth/oauth_web_helper_stub.dart'
    if (dart.library.js_interop) '../core/auth/oauth_web_helper_web.dart';
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
import '../features/auth/presentation/auth_screens.dart';
import '../features/auth/presentation/privacy_policy_screen.dart';
import '../features/onboarding/presentation/onboarding_tour_screen.dart';
import '../core/auth/auth_repository.dart';
import '../core/widgets/experience_shell.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_theme.dart';
import '../data/models/expense.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter({
  String initialLocation = '/',
  AuthStatus Function()? readAuthStatus,
  Listenable? refreshListenable,
  bool Function()? hasPendingOAuthCode,
  bool Function()? isOnboardingPending,
}) => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: initialLocation,
  refreshListenable: refreshListenable,
  redirect: (context, state) {
    if (readAuthStatus == null) return null;
    final status = readAuthStatus();
    final loc = state.uri.path;
    final fullUri = state.uri.toString();
    final isAuthRoute =
        loc == '/welcome' || loc == '/signin' || loc == '/signup';
    final isLoadingRoute = loc == '/auth-loading';
    final isTourRoute = loc == '/tour';
    final isPublicRoute = isAuthRoute || loc == '/privacy';
    final pendingOAuth = hasPendingOAuthCode?.call() ??
        (Uri.base.queryParameters['code']?.isNotEmpty == true);

    if (status is AuthLoading || (status is AuthSignedOut && pendingOAuth && !isAuthRoute)) {
      if (isLoadingRoute) return null;
      if (fullUri == '/' || fullUri.isEmpty || isAuthRoute) {
        return '/auth-loading';
      }
      return '/auth-loading?from=${Uri.encodeComponent(fullUri)}';
    }

    if (status is AuthSignedIn) {
      final onboardingPending = isOnboardingPending?.call() ?? false;
      if (onboardingPending) {
        return isTourRoute ? null : '/tour';
      }
      if (isTourRoute) {
        return '/';
      }
      if (isAuthRoute || isLoadingRoute) {
        final from = state.uri.queryParameters['from'];
        if (from != null &&
            from.startsWith('/') &&
            !from.startsWith('/welcome') &&
            !from.startsWith('/signin') &&
            !from.startsWith('/signup') &&
            !from.startsWith('/auth-loading') &&
            !from.startsWith('/tour')) {
          return from;
        }
        return '/';
      }
      return null;
    }

    if (status is AuthGuest) {
      final onboardingPending = isOnboardingPending?.call() ?? false;
      if (onboardingPending) {
        return isTourRoute ? null : '/tour';
      }
      if (isAuthRoute || isLoadingRoute || isTourRoute) {
        final from = state.uri.queryParameters['from'];
        if (from != null &&
            from.startsWith('/') &&
            !from.startsWith('/welcome') &&
            !from.startsWith('/signin') &&
            !from.startsWith('/signup') &&
            !from.startsWith('/auth-loading') &&
            !from.startsWith('/tour')) {
          return from;
        }
        return '/';
      }
      return null;
    }

    if (status is AuthConfirmationPending) {
      if (isPublicRoute) return null;
      return '/signin';
    }

    if (status is AuthSignedOut) {
      if (isPublicRoute) return null;
      if (isLoadingRoute) {
        return '/welcome';
      }
      if (fullUri == '/' || fullUri.isEmpty) return '/welcome';
      return '/welcome?from=${Uri.encodeComponent(fullUri)}';
    }

    return null;
  },
  errorBuilder: (context, state) {
    if (kDebugMode) {
      debugPrint('GoRouter errorBuilder (${state.uri}): ${state.error}');
    }
    return const WelcomeAuthScreen();
  },
  routes: [
    // 4-Tab Navigation Shell: Home, Groups, Records, Insights (+ is centre button)
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ExperienceShell(
          navigationShell: navigationShell,
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
                  builder: (context, state) => const InsightsScreen(initialTab: InsightsTab.budgets),
                ),
              ],
            ),
          ],
        ),
        // Tab 4: Budgets (Standalone top-level route on Web)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/budgets',
              builder: (context, state) => const PlanScreen(),
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
    // 280ms fade + 8px rise + blur 8 to 0 page transition
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/balances',
      pageBuilder: (context, state) => _buildWebPageTransition(
        key: state.pageKey,
        child: const BalancesScreen(),
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
          child: AddExpenseScreen(
              initialExpense: initialExpense,
              initialText: initialText,
              preselectedGroupId: preselectedGroupId,
              initialTabIndex: initialTabIndex,
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
      pageBuilder: (context, state) => _buildWebPageTransition(
        key: state.pageKey,
        child: GroupDetailScreen(groupId: state.pathParameters['id'] ?? ''),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings',
      pageBuilder: (context, state) {
        final section = state.uri.queryParameters['section'];
        return _buildWebPageTransition(
          key: state.pageKey,
          child: SettingsScreen(initialSection: section),
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/settings/recurring',
      pageBuilder: (context, state) => _buildWebPageTransition(
        key: state.pageKey,
        child: const RecurringExpensesScreen(),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/auth-loading',
      builder: (context, state) => const _AuthLoadingScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/welcome',
      builder: (context, state) => WelcomeAuthScreen(
        fromLocation: state.uri.queryParameters['from'],
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/signin',
      builder: (context, state) => AuthScreen(
        initialMode: AuthFormMode.signIn,
        fromLocation: state.uri.queryParameters['from'],
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/signup',
      builder: (context, state) => AuthScreen(
        initialMode: AuthFormMode.signUp,
        fromLocation: state.uri.queryParameters['from'],
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/tour',
      builder: (context, state) => const OnboardingTourScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/privacy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
  ],
);

Page<dynamic> _buildWebPageTransition({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );

      final slide = Tween<Offset>(
        begin: const Offset(0.0, 0.012),
        end: Offset.zero,
      ).animate(curved);

      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

      return AnimatedBuilder(
        animation: curved,
        builder: (context, _) {
          final blurSigma = (1.0 - curved.value) * 8.0;
          Widget content = FadeTransition(
            opacity: fade,
            child: SlideTransition(
              position: slide,
              child: child,
            ),
          );

          if (blurSigma > 0.4) {
            content = ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: content,
            );
          }
          return content;
        },
      );
    },
  );
}

final appRouter = createAppRouter();

class _AuthLoadingScreen extends ConsumerStatefulWidget {
  const _AuthLoadingScreen();

  @override
  ConsumerState<_AuthLoadingScreen> createState() => _AuthLoadingScreenState();
}

class _AuthLoadingScreenState extends ConsumerState<_AuthLoadingScreen> {
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      ref.read(authStateProvider.notifier).forceSignedOut();
      replaceUrlToWelcome();
      context.go('/welcome');
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.settliv.canvas,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
