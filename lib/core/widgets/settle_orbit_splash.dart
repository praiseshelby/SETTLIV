import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Gates the app on initial launch for at least 900ms (skipped in tests)
/// using the exact same cinematic Settle Orbit geometry & dark Midnight
/// palette as web/index.html so the handoff has zero flash.
class SettleOrbitSplashGate extends StatefulWidget {
  final Widget child;
  final bool skipInTests;

  const SettleOrbitSplashGate({
    super.key,
    required this.child,
    this.skipInTests = true,
  });

  @override
  State<SettleOrbitSplashGate> createState() => _SettleOrbitSplashGateState();
}

class _SettleOrbitSplashGateState extends State<SettleOrbitSplashGate> {
  bool _visible = true;
  bool _fadingOut = false;
  Timer? _minTimer;

  @override
  void initState() {
    super.initState();
    final isTest = widget.skipInTests &&
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      _visible = false;
      return;
    }
    _minTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _fadingOut = true);
      Future<void>.delayed(const Duration(milliseconds: 320), () {
        if (mounted) setState(() => _visible = false);
      });
    });
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _fadingOut,
            child: AnimatedOpacity(
              opacity: _fadingOut ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              child: SettleOrbitSplash(exiting: _fadingOut),
            ),
          ),
        ),
      ],
    );
  }
}

class SettleOrbitSplash extends StatefulWidget {
  final bool exiting;

  const SettleOrbitSplash({
    super.key,
    this.exiting = false,
  });

  @override
  State<SettleOrbitSplash> createState() => _SettleOrbitSplashState();
}

class _SettleOrbitSplashState extends State<SettleOrbitSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  static const List<String> _letters = ['S', 'E', 'T', 'T', 'L', 'I', 'V'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wordmarkSize = (size.width * 0.05).clamp(30.0, 48.0);
    final tracking = wordmarkSize * 0.28;
    final hairlineWidth = (size.width * 0.22).clamp(120.0, 190.0);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      _ctrl.value = 1.0;
    }

    return ColoredBox(
      color: AppColors.farDarkInkBase, // #070914 matching web/index.html
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Living background + 8-10 viewport-spanning rings + convergence nodes
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final t = reduceMotion ? 1.0 : _ctrl.value;
                return Transform.scale(
                  scale: widget.exiting && !reduceMotion ? 1.06 : 1.0,
                  child: CustomPaint(
                    painter: _CinematicOrbitPainter(
                      t: t,
                      reduceMotion: reduceMotion,
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Centered wordmark (letter-by-letter reveal) + hairline + sweep
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: tracking),
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final t = reduceMotion ? 1.0 : _ctrl.value;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int i = 0; i < _letters.length; i++) ...[
                            Builder(builder: (context) {
                              if (reduceMotion) {
                                return Text(
                                  _letters[i],
                                  style: _letterStyle(wordmarkSize, tracking),
                                );
                              }
                              final start = 0.50 + i * 0.022;
                              final local = ((t - start) / 0.18).clamp(0.0, 1.0);
                              final eased = Curves.easeOutCubic.transform(local);
                              return Opacity(
                                opacity: eased,
                                child: Transform.translate(
                                  offset: Offset(0, (1.0 - eased) * 10.0),
                                  child: Text(
                                    _letters[i],
                                    style: _letterStyle(wordmarkSize, tracking),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    final t = reduceMotion ? 1.0 : _ctrl.value;
                    final drawT = reduceMotion
                        ? 1.0
                        : Curves.easeOutCubic
                            .transform(((t - 0.65) / 0.25).clamp(0.0, 1.0));
                    final sweepT = reduceMotion
                        ? 0.5
                        : ((t - 0.72) / 0.28).clamp(0.0, 1.0);
                    return Transform.scale(
                      scaleX: drawT,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: SizedBox(
                          width: hairlineWidth,
                          height: 1.5,
                          child: ColoredBox(
                            color: AppColors.darkInk.withValues(alpha: 0.14),
                            child: Transform.translate(
                              offset: Offset(
                                -50.0 + sweepT * (hairlineWidth + 100.0),
                                0,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 56,
                                  height: 1.5,
                                  child: ColoredBox(
                                    color:
                                        AppColors.darkInk.withValues(alpha: 0.65),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _letterStyle(double fontSize, double tracking) => TextStyle(
        fontFamily: AppTypography.fontBrand,
        fontFamilyFallback: AppTypography.brandFallback,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: tracking,
        height: 1.0,
        color: AppColors.darkInk,
      );
}

class _CinematicOrbitPainter extends CustomPainter {
  final double t;
  final bool reduceMotion;

  const _CinematicOrbitPainter({
    required this.t,
    required this.reduceMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDim = math.max(size.width, size.height);

    // Soft radial vignette + drifting cool teal-slate & faint warm hint (no purple-blue AI gradient)
    final drift = math.sin(t * math.pi) * 18.0;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.48 + (drift / size.width), -0.36),
          radius: 0.85,
          colors: const [
            Color(0x44144A58), // muted cool teal-slate
            Color(0x00070914),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0.48 - (drift / size.width), 0.36),
          radius: 0.78,
          colors: const [
            Color(0x28703C34), // faint warm hint
            Color(0x00070914),
          ],
        ).createShader(Offset.zero & size),
    );

    // 9 hairline concentric rings + partial arcs spanning the viewport
    final ringBase = maxDim * 0.70;
    final breath = reduceMotion ? 1.0 : (0.985 + 0.03 * t);
    final ringPaint = Paint()
      ..color = AppColors.darkInk.withValues(alpha: 0.075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final arcPaint = Paint()
      ..color = AppColors.textEmeraldDark.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 1; i <= 9; i++) {
      final r = (ringBase * (i / 9.0)) * breath;
      canvas.drawCircle(center, r, ringPaint);
      if (i == 3 || i == 5 || i == 8) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          -math.pi * 0.35 + (t * 0.4),
          math.pi * 0.55,
          false,
          arcPaint,
        );
      }
    }

    // Nodes: reduced motion shows composed placement; otherwise curved arc convergence + comet trail + ripple
    if (reduceMotion) {
      canvas.drawCircle(
        Offset(center.dx - 44, center.dy),
        5.0,
        Paint()..color = AppColors.textEmeraldDark,
      );
      canvas.drawCircle(
        Offset(center.dx + 44, center.dy),
        5.0,
        Paint()..color = AppColors.textCoralDark,
      );
      return;
    }

    final moveT = Curves.easeOutCubic.transform((t / 0.58).clamp(0.0, 1.0));
    if (moveT < 1.0) {
      final startX = size.width * 0.42;
      final startY = size.height * 0.20;
      final arcLift = math.sin(moveT * math.pi) * 28.0;

      final ePos = Offset(
        center.dx - startX * (1.0 - moveT),
        center.dy - startY * (1.0 - moveT) - arcLift,
      );
      final cPos = Offset(
        center.dx + startX * (1.0 - moveT),
        center.dy + startY * (1.0 - moveT) + arcLift,
      );

      // Short comet trail
      for (int s = 1; s <= 3; s++) {
        final backT = (moveT - s * 0.045).clamp(0.0, 1.0);
        final backLift = math.sin(backT * math.pi) * 28.0;
        final alpha = 0.35 - s * 0.09;
        canvas.drawCircle(
          Offset(
            center.dx - startX * (1.0 - backT),
            center.dy - startY * (1.0 - backT) - backLift,
          ),
          5.0 - s * 0.8,
          Paint()..color = AppColors.textEmeraldDark.withValues(alpha: alpha),
        );
        canvas.drawCircle(
          Offset(
            center.dx + startX * (1.0 - backT),
            center.dy + startY * (1.0 - backT) + backLift,
          ),
          5.0 - s * 0.8,
          Paint()..color = AppColors.textCoralDark.withValues(alpha: alpha),
        );
      }

      canvas.drawCircle(ePos, 5.2, Paint()..color = AppColors.textEmeraldDark);
      canvas.drawCircle(cPos, 5.2, Paint()..color = AppColors.textCoralDark);
    }

    // Contact ripple ring
    if (t >= 0.52) {
      final rippleT = Curves.easeOutCubic.transform(((t - 0.52) / 0.36).clamp(0.0, 1.0));
      if (rippleT < 1.0) {
        canvas.drawCircle(
          center,
          12.0 + rippleT * 84.0,
          Paint()
            ..color = AppColors.darkInk.withValues(alpha: (1.0 - rippleT) * 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CinematicOrbitPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.reduceMotion != reduceMotion;
}
