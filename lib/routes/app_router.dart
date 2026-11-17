import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/add_expense/presentation/add_expense_screen.dart';
import '../features/group_detail/presentation/group_detail_screen.dart';
import '../features/gallery/component_gallery_screen.dart';
import '../core/widgets/phone_frame.dart';
import '../data/models/expense.dart';

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return PhoneFrame(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
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
