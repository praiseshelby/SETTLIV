import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Gates the app on initial launch for at least 900ms (skipped in tests/reduced
/// motion) using the exact same dark Settle Orbit geometry as web/index.html.
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
      Future<void>.delayed(const Duration(milliseconds: 280), () {
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
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              child: SettleOrbitSplash(converging: _fadingOut),
            ),
          ),
        ),
      ],
    );
  }
}

class SettleOrbitSplash extends StatefulWidget {
  final bool converging;

  const SettleOrbitSplash({
    super.key,
    this.converging = false,
  });

  @override
  State<SettleOrbitSplash> createState() => _SettleOrbitSplashState();
}

class _SettleOrbitSplashState extends State<SettleOrbitSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final shorter = math.min(size.width, size.height);
    final sceneSize = (shorter * 0.60).clamp(210.0, 560.0);
    final wordmarkSize = (size.width * 0.05).clamp(32.0, 44.0);
    final tracking = wordmarkSize * 0.26;
    final hairlineWidth = (size.width * 0.22).clamp(120.0, 180.0);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      _ctrl.stop();
    }

    return ColoredBox(
      color: AppColors.farDarkInkBase, // #070914 matching web/index.html
      child: Center(
        child: SizedBox(
          width: sceneSize,
          height: sceneSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _SplashOrbitPainter(
                          t: reduceMotion ? 0.25 : _ctrl.value,
                          converge: widget.converging ? 1.0 : 0.0,
                          reduceMotion: reduceMotion,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: tracking),
                    child: Text(
                      'SETTLIV',
                      style: TextStyle(
                        fontFamily: AppTypography.fontBrand,
                        fontFamilyFallback: AppTypography.brandFallback,
                        fontSize: wordmarkSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: tracking,
                        height: 1.0,
                        color: AppColors.darkInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: SizedBox(
                      width: hairlineWidth,
                      height: 1.5,
                      child: ColoredBox(
                        color: AppColors.darkHairline,
                        child: reduceMotion
                            ? const Align(
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: 48,
                                  height: 1.5,
                                  child: ColoredBox(color: AppColors.prismViolet),
                                ),
                              )
                            : AnimatedBuilder(
                                animation: _ctrl,
                                builder: (context, _) {
                                  final sweepT = (_ctrl.value * 2.4) % 1.0;
                                  final dx = -60.0 + sweepT * (hairlineWidth + 120.0);
                                  return Transform.translate(
                                    offset: Offset(dx, 0),
                                    child: const Align(
                                      alignment: Alignment.centerLeft,
                                      child: SizedBox(
                                        width: 56,
                                        height: 1.5,
                                        child: ColoredBox(
                                          color: AppColors.prismViolet,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashOrbitPainter extends CustomPainter {
  final double t;
  final double converge;
  final bool reduceMotion;

  const _SplashOrbitPainter({
    required this.t,
    required this.converge,
    required this.reduceMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;

    // Expanding concentric pulse rings (transform & opacity)
    if (reduceMotion) {
      canvas.drawCircle(
        center,
        maxR * 0.88,
        Paint()
          ..color = AppColors.prismViolet.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    } else {
      for (int i = 0; i < 3; i++) {
        final phase = (t + i / 3.0) % 1.0;
        final scale = 0.50 + phase * 0.55;
        final alpha = (1.0 - phase) * 0.45;
        canvas.drawCircle(
          center,
          maxR * 0.88 * scale,
          Paint()
            ..color = AppColors.prismViolet.withValues(alpha: alpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }

    // Orbit tracks
    final outerR = maxR * 0.76;
    final innerR = maxR * 0.52;
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..color = AppColors.darkHairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..color = AppColors.prismViolet.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Emerald & coral nodes orbiting and converging on ready
    final factor = 1.0 - (converge * 0.75);
    final emeraldAngle = -math.pi / 2 + t * 2 * math.pi;
    final coralAngle = math.pi / 2 - t * 2 * math.pi;

    canvas.drawCircle(
      Offset(
        center.dx + outerR * factor * math.cos(emeraldAngle),
        center.dy + outerR * factor * math.sin(emeraldAngle),
      ),
      5.0,
      Paint()..color = AppColors.textEmeraldDark,
    );
    canvas.drawCircle(
      Offset(
        center.dx + innerR * factor * math.cos(coralAngle),
        center.dy + innerR * factor * math.sin(coralAngle),
      ),
      5.0,
      Paint()..color = AppColors.textCoralDark,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashOrbitPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.converge != converge ||
      oldDelegate.reduceMotion != reduceMotion;
}
