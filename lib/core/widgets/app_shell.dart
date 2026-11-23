import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'docked_nav_bar.dart';
import 'phone_frame.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final appContent = Stack(
      children: [
        Positioned.fill(
          child: navigationShell,
        ),
        if (!isKeyboardOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DockedNavBar(
              currentIndex: navigationShell.currentIndex,
              onTabSelected: (index) {
                navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            ),
          ),
      ],
    );

    return PhoneFrame(child: appContent);
  }
}
