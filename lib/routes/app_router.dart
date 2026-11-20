import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/groups/presentation/groups_screen.dart';
import '../features/activity/presentation/activity_screen.dart';
import '../features/add_expense/presentation/add_expense_screen.dart';
import '../features/group_detail/presentation/group_detail_screen.dart';
import '../features/gallery/component_gallery_screen.dart';
import '../core/widgets/phone_frame.dart';
import '../core/widgets/app_shell.dart';
import '../core/widgets/gradient_primary_button.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/theme/app_theme.dart';
import '../data/models/expense.dart';

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
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
                const Icon(
                  Icons.explore_off_rounded,
                  size: 56,
                  color: AppColors.coral,
                ),
                const SizedBox(height: 16),
                Text(
                  'Page not found',
                  style: AppTypography.titleLarge.copyWith(color: theme.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'The page you are looking for does not exist.',
                  style: AppTypography.body.copyWith(color: theme.secondary),
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
    ShellRoute(
      builder: (context, state, child) {
        return PhoneFrame(
          child: AppShell(
            currentPath: state.uri.path,
            child: child,
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/groups',
          builder: (context, state) => const GroupsScreen(),
        ),
        GoRoute(
          path: '/activity',
          builder: (context, state) => const ActivityScreen(),
        ),
        GoRoute(
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
                final tween =
                    Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                return SlideTransition(
                  position: animation.drive(tween),
                  child: child,
                );
              },
            );
          },
        ),
        GoRoute(
          path: '/group/:id',
          builder: (context, state) {
            final groupId = state.pathParameters['id'] ?? '';
            return GroupDetailScreen(groupId: groupId);
          },
        ),
        GoRoute(
          path: '/gallery',
          builder: (context, state) => const ComponentGalleryScreen(),
        ),
      ],
    ),
  ],
);

final appRouter = createAppRouter();
