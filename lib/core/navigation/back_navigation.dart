import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BackNavigation {
  BackNavigation._();

  static const List<String> rootRoutes = ['/', '/groups', '/records', '/insights'];

  static bool isRootRoute(String path) {
    return rootRoutes.contains(path);
  }

  static String? getParentRoute(String path) {
    if (path.startsWith('/group/')) return '/groups';
    if (path == '/balances') return '/';
    if (path == '/add') return '/';
    if (path == '/settings/recurring') return '/settings';
    if (path == '/settings') return '/';
    if (path == '/insights/budgets') return '/insights';
    if (!isRootRoute(path)) return '/';
    return null;
  }

  static String getParentLabel(String path) {
    if (path.startsWith('/group/')) return 'Groups';
    if (path == '/balances') return 'Home';
    if (path == '/add') return 'Home';
    if (path == '/settings/recurring') return 'Settings';
    if (path == '/settings') return 'Home';
    if (path == '/insights/budgets') return 'Insights';
    return 'Back';
  }

  static void handleBack(BuildContext context, {String? currentPath, VoidCallback? customOnBack}) {
    if (customOnBack != null) {
      customOnBack();
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    final path = currentPath ?? GoRouterState.of(context).matchedLocation;
    final parent = getParentRoute(path) ?? '/';
    context.go(parent);
  }
}
