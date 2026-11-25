import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import '../theme/motion_tokens.dart';

class ExperienceTransitionEvent {
  final int id;
  final bool fromWeb;
  final bool toWeb;

  const ExperienceTransitionEvent({
    required this.id,
    required this.fromWeb,
    required this.toWeb,
  });
}

class ExperienceTransitionNotifier extends Notifier<ExperienceTransitionEvent?> {
  int _counter = 0;

  @override
  ExperienceTransitionEvent? build() => null;

  void trigger({
    required bool fromWeb,
    required bool toWeb,
  }) {
    _counter++;
    state = ExperienceTransitionEvent(
      id: _counter,
      fromWeb: fromWeb,
      toWeb: toWeb,
    );
  }
}

final experienceTransitionProvider =
    NotifierProvider<ExperienceTransitionNotifier, ExperienceTransitionEvent?>(
  ExperienceTransitionNotifier.new,
);

/// Full-viewport 650ms device-morph transition overlay when switching
/// between App and Web layouts. No text, no blur, transform & opacity +
/// paint-only CustomPainter inside RepaintBoundary.
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
                  final fade = (1.0 - t).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: fade * 0.75,
                    child: ColoredBox(color: theme.surfaceSolid),
                  );
                }

                // 0-120ms (0.00..0.185): veil fades in
                // 120-480ms (0.185..0.738): device morph + nodes converge + ripple
                // 480-650ms (0.738..1.00): new outline scales up past viewport & veil fades out
                final double veilOpacity;
                if (t < 0.185) {
                  veilOpacity = Curves.easeOut.transform(t / 0.185);
                } else if (t <= 0.738) {
                  veilOpacity = 1.0;
                } else {
                  veilOpacity = 1.0 -
                      Curves.easeIn.transform(
                        ((t - 0.738) / 0.262).clamp(0.0, 1.0),
                      );
                }

                final double morphT = Curves.easeInOutCubic.transform(
                  ((t - 0.185) / (0.738 - 0.185)).clamp(0.0, 1.0),
                );

                final double exitScale = t <= 0.738
                    ? 1.0
                    : 1.0 +
                        Curves.easeInCubic.transform(
                              ((t - 0.738) / 0.262).clamp(0.0, 1.0),
                            ) *
                            3.2;

                final double deviceOpacity = t < 0.12
                    ? (t / 0.12).clamp(0.0, 1.0)
                    : (t > 0.738
                        ? (1.0 - ((t - 0.738) / 0.262)).clamp(0.0, 1.0)
                        : 1.0);

                return Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: veilOpacity,
                        child: ColoredBox(color: theme.surfaceSolid),
                      ),
                    ),
                    Center(
                      child: Opacity(
                        opacity: deviceOpacity,
                        child: Transform.scale(
                          scale: exitScale,
                          child: RepaintBoundary(
                            child: SizedBox(
                              width: 240,
                              height: 220,
                              child: CustomPaint(
                                painter: _DeviceMorphPainter(
                                  morphT: morphT,
                                  fromWeb: _activeEvent!.fromWeb,
                                  toWeb: _activeEvent!.toWeb,
                                  inkColor: theme.ink,
                                  mutedColor: theme.muted,
                                  hairlineColor: theme.hairline,
                                  accentColor: theme.accent,
                                  emeraldColor: theme.emerald,
                                  coralColor: theme.coral,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceMorphPainter extends CustomPainter {
  final double morphT;
  final bool fromWeb;
  final bool toWeb;
  final Color inkColor;
  final Color mutedColor;
  final Color hairlineColor;
  final Color accentColor;
  final Color emeraldColor;
  final Color coralColor;

  const _DeviceMorphPainter({
    required this.morphT,
    required this.fromWeb,
    required this.toWeb,
    required this.inkColor,
    required this.mutedColor,
    required this.hairlineColor,
    required this.accentColor,
    required this.emeraldColor,
    required this.coralColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Monitor dimensions vs Phone dimensions
    const double monW = 200;
    const double monH = 132;
    const double monR = 10;

    const double phoneW = 102;
    const double phoneH = 192;
    const double phoneR = 22;

    final startW = fromWeb ? monW : phoneW;
    final startH = fromWeb ? monH : phoneH;
    final startR = fromWeb ? monR : phoneR;

    final endW = toWeb ? monW : phoneW;
    final endH = toWeb ? monH : phoneH;
    final endR = toWeb ? monR : phoneR;

    final w = lerpDouble(startW, endW, morphT)!;
    final h = lerpDouble(startH, endH, morphT)!;
    final r = lerpDouble(startR, endR, morphT)!;

    final rect = Rect.fromCenter(center: center, width: w, height: h);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));

    // Device outline
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = inkColor.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Cross-fade skeletons inside the morphed frame
    canvas.save();
    canvas.clipRRect(rrect);
    final double webAlpha = fromWeb == toWeb
        ? (toWeb ? 1.0 : 0.0)
        : (toWeb ? morphT : (1.0 - morphT));
    final double phoneAlpha = 1.0 - webAlpha;

    if (webAlpha > 0.02) {
      final p = Paint()..color = mutedColor.withValues(alpha: 0.16 * webAlpha);
      // Sidebar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 8, rect.top + 8, w * 0.22, h - 16),
          const Radius.circular(4),
        ),
        p,
      );
      // Hero + card
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              rect.left + 14 + w * 0.22, rect.top + 8, w * 0.70 - 20, h * 0.44),
          const Radius.circular(5),
        ),
        p,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 14 + w * 0.22, rect.top + 14 + h * 0.44,
              w * 0.70 - 20, h * 0.36),
          const Radius.circular(5),
        ),
        p,
      );
    }

    if (phoneAlpha > 0.02) {
      final p = Paint()..color = mutedColor.withValues(alpha: 0.16 * phoneAlpha);
      // Top header strip
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 10, rect.top + 14, w - 20, 14),
          const Radius.circular(4),
        ),
        p,
      );
      // Hero card
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 10, rect.top + 36, w - 20, h * 0.30),
          const Radius.circular(6),
        ),
        p,
      );
      // List card
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
              rect.left + 10, rect.top + 44 + h * 0.30, w - 20, h * 0.24),
          const Radius.circular(6),
        ),
        p,
      );
      // Docked bottom bar
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(rect.left + 10, rect.bottom - 24, w - 20, 14),
          const Radius.circular(7),
        ),
        p,
      );
    }
    canvas.restore();

    // Emerald & coral nodes slide from opposite sides of outline and meet at center
    final nodeProgress = (morphT / 0.72).clamp(0.0, 1.0);
    final offsetX = lerpDouble(w * 0.48, 0.0, nodeProgress)!;
    final emeraldPos = Offset(center.dx - offsetX, center.dy);
    final coralPos = Offset(center.dx + offsetX, center.dy);

    canvas.drawCircle(emeraldPos, 5.0, Paint()..color = emeraldColor);
    canvas.drawCircle(coralPos, 5.0, Paint()..color = coralColor);

    // One soft ring ripple when nodes meet (nodeProgress >= 0.72)
    if (morphT > 0.65) {
      final rippleT = ((morphT - 0.65) / 0.35).clamp(0.0, 1.0);
      final rippleR = lerpDouble(6.0, 36.0, rippleT)!;
      final rippleAlpha = (1.0 - rippleT) * 0.55;
      canvas.drawCircle(
        center,
        rippleR,
        Paint()
          ..color = accentColor.withValues(alpha: rippleAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DeviceMorphPainter oldDelegate) =>
      oldDelegate.morphT != morphT ||
      oldDelegate.fromWeb != fromWeb ||
      oldDelegate.toWeb != toWeb;
}
