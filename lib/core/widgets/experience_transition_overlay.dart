import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../theme/motion_tokens.dart';

class ExperienceTransitionEvent {
  final int id;
  final Offset origin;
  final String targetLabel;

  const ExperienceTransitionEvent({
    required this.id,
    required this.origin,
    required this.targetLabel,
  });
}

class ExperienceTransitionNotifier extends Notifier<ExperienceTransitionEvent?> {
  int _counter = 0;

  @override
  ExperienceTransitionEvent? build() => null;

  void trigger({
    required Offset origin,
    required String targetLabel,
  }) {
    _counter++;
    state = ExperienceTransitionEvent(
      id: _counter,
      origin: origin,
      targetLabel: targetLabel,
    );
  }
}

final experienceTransitionProvider =
    NotifierProvider<ExperienceTransitionNotifier, ExperienceTransitionEvent?>(
  ExperienceTransitionNotifier.new,
);

/// Full-viewport choreographed transition overlay (650ms) when switching
/// between App and Web layouts. Uses transform & opacity only, no BackdropFilter.
class ExperienceTransitionOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const ExperienceTransitionOverlay({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ExperienceTransitionOverlay> createState() =>
      _ExperienceTransitionOverlayState();
}

class _ExperienceTransitionOverlayState
    extends ConsumerState<ExperienceTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  ExperienceTransitionEvent? _activeEvent;
  int _lastHandledId = 0;
  bool _liteMode = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _activeEvent = null);
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _startIfNeeded(ExperienceTransitionEvent? event) {
    if (event == null || event.id == _lastHandledId) return;
    _lastHandledId = event.id;
    final profile = ref.read(deviceProfileProvider);
    final isLite = MotionTokens.isLiteEffects(context, profile);
    _liteMode = isLite;
    _activeEvent = event;
    _ctrl.duration = isLite
        ? const Duration(milliseconds: 150)
        : const Duration(milliseconds: 650);
    _ctrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final event = ref.watch(experienceTransitionProvider);
    if (event != null && event.id != _lastHandledId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _startIfNeeded(event));
        }
      });
    }

    if (_activeEvent == null) {
      return widget.child;
    }

    final theme = context.settliv;
    final size = MediaQuery.sizeOf(context);
    final origin = _activeEvent!.origin;
    final maxDx = math.max(origin.dx, size.width - origin.dx);
    final maxDy = math.max(origin.dy, size.height - origin.dy);
    final maxRadius = math.sqrt(maxDx * maxDx + maxDy * maxDy) + 24;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = _ctrl.value;

                if (_liteMode) {
                  // Plain 150ms cross-fade
                  final fadeOut = (1.0 - t).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: fadeOut * 0.6,
                    child: ColoredBox(color: theme.surfaceSolid),
                  );
                }

                // 0.00 -> 0.40: Circle scales out from tapped tile
                final expandT = Curves.easeOutCubic.transform(
                  (t / 0.40).clamp(0.0, 1.0),
                );
                // 0.12 -> 0.65: Orbit converges
                final orbitT = Curves.easeInOutCubic.transform(
                  ((t - 0.12) / 0.53).clamp(0.0, 1.0),
                );
                // 0.65 -> 1.00: Overlay fades out
                final overlayOpacity = t < 0.65
                    ? 1.0
                    : 1.0 -
                        Curves.easeOut.transform(
                          ((t - 0.65) / 0.35).clamp(0.0, 1.0),
                        );

                final circleScale = expandT.clamp(0.02, 1.0);
                final contentOpacity = t < 0.12
                    ? 0.0
                    : (t < 0.25 ? (t - 0.12) / 0.13 : 1.0);

                return Opacity(
                  opacity: overlayOpacity,
                  child: Stack(
                    children: [
                      // Expanding theme-coloured circle (transform only)
                      Positioned(
                        left: origin.dx - maxRadius,
                        top: origin.dy - maxRadius,
                        width: maxRadius * 2,
                        height: maxRadius * 2,
                        child: Transform.scale(
                          scale: circleScale,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.surfaceSolid,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      // Center Settle Orbit motif + target layout name
                      Center(
                        child: Opacity(
                          opacity: contentOpacity,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RepaintBoundary(
                                child: SizedBox(
                                  width: 112,
                                  height: 112,
                                  child: CustomPaint(
                                    painter: _OrbitConvergePainter(
                                      progress: orbitT,
                                      ringColor: theme.hairline,
                                      accentColor: theme.accent,
                                      emeraldColor: theme.emerald,
                                      coralColor: theme.coral,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _activeEvent!.targetLabel,
                                style: TextStyle(
                                  fontFamily: AppTypography.fontBrand,
                                  fontFamilyFallback: AppTypography.brandFallback,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: theme.ink,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _OrbitConvergePainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color accentColor;
  final Color emeraldColor;
  final Color coralColor;

  const _OrbitConvergePainter({
    required this.progress,
    required this.ringColor,
    required this.accentColor,
    required this.emeraldColor,
    required this.coralColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width * 0.44;
    final innerR = size.width * 0.28;

    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..color = accentColor.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Emerald & coral nodes converge smoothly toward the center
    final convergeFactor = 1.0 - (progress * 0.85);
    final emeraldAngle = -math.pi / 4 + progress * math.pi * 0.75;
    final coralAngle = (3 * math.pi) / 4 + progress * math.pi * 0.75;

    canvas.drawCircle(
      Offset(
        center.dx + outerR * convergeFactor * math.cos(emeraldAngle),
        center.dy + outerR * convergeFactor * math.sin(emeraldAngle),
      ),
      5.5,
      Paint()..color = emeraldColor,
    );
    canvas.drawCircle(
      Offset(
        center.dx + innerR * convergeFactor * math.cos(coralAngle),
        center.dy + innerR * convergeFactor * math.sin(coralAngle),
      ),
      5.5,
      Paint()..color = coralColor,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitConvergePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
