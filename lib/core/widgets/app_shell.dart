import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../profile/experience_mode.dart';
import 'docked_nav_bar.dart';
import 'first_visit_compatibility_card.dart';

class AppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _checkedPreviewSheet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkedPreviewSheet) return;
    _checkedPreviewSheet = true;
    final profile = ref.read(deviceProfileProvider);
    if (!profile.isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          CompatibilityPreviewSheet.showIfNeeded(context, ref);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Stack(
      children: [
        Positioned.fill(
          child: widget.navigationShell,
        ),
        if (!isKeyboardOpen)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DockedNavBar(
              currentIndex: widget.navigationShell.currentIndex,
              onTabSelected: (index) {
                widget.navigationShell.goBranch(
                  index,
                  initialLocation: index == widget.navigationShell.currentIndex,
                );
              },
            ),
          ),
      ],
    );
  }
}
