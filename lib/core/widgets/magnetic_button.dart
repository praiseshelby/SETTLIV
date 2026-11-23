import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile/experience_mode.dart';
import '../theme/motion_tokens.dart';

/// MagneticButton adds a subtle (<= 4px) magnetic pull toward pointer on desktop hover.
class MagneticButton extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final double maxPull;

  const MagneticButton({
    super.key,
    required this.child,
    this.onPressed,
    this.maxPull = 4.0,
  });

  @override
  ConsumerState<MagneticButton> createState() => _MagneticButtonState();
}

class _MagneticButtonState extends ConsumerState<MagneticButton> {
  Offset _pullOffset = Offset.zero;

  void _onHover(PointerHoverEvent event, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final normX = ((event.localPosition.dx - center.dx) / (size.width / 2)).clamp(-1.0, 1.0);
    final normY = ((event.localPosition.dy - center.dy) / (size.height / 2)).clamp(-1.0, 1.0);

    setState(() {
      _pullOffset = Offset(normX * widget.maxPull, normY * widget.maxPull);
    });
  }

  void _onExit() {
    setState(() {
      _pullOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(deviceProfileProvider);
    final isLite = MotionTokens.isLiteEffects(context, profile);

    if (!profile.isDesktop || isLite) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onHover: (e) => _onHover(e, Size(constraints.maxWidth, constraints.maxHeight)),
          onExit: (_) => _onExit(),
          child: AnimatedSlide(
            offset: Offset(_pullOffset.dx / (constraints.maxWidth > 0 ? constraints.maxWidth : 100),
                _pullOffset.dy / (constraints.maxHeight > 0 ? constraints.maxHeight : 44)),
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: widget.child,
          ),
        );
      },
    );
  }
}
