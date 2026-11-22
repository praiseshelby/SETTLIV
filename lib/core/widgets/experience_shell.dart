import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../profile/experience_mode.dart';
import '../theme/motion_tokens.dart';
import 'adaptive_web_shell.dart';
import 'app_shell.dart';

class ExperienceShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const ExperienceShell({
    super.key,
    required this.navigationShell,
  });

  @override
  ConsumerState<ExperienceShell> createState() => _ExperienceShellState();
}

class _ExperienceShellState extends ConsumerState<ExperienceShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  EffectiveExperience? _previousExperience;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.durationCrossFade,
    )..value = 1.0;
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: MotionTokens.curveStandard,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effective = ref.watch(effectiveExperienceProvider);

    if (_previousExperience != null && _previousExperience != effective) {
      _controller.forward(from: 0.0);
    }
    _previousExperience = effective;

    final child = effective == EffectiveExperience.web
        ? AdaptiveWebShell(
            key: const ValueKey('web_shell'),
            navigationShell: widget.navigationShell,
          )
        : AppShell(
            key: const ValueKey('app_shell'),
            navigationShell: widget.navigationShell,
          );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: child,
    );
  }
}
