import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import '../theme/motion_tokens.dart';

class AuroraBackground extends ConsumerStatefulWidget {
  final Widget child;
  final bool showGrid;

  const AuroraBackground({
    super.key,
    required this.child,
    this.showGrid = true,
  });

  @override
  ConsumerState<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends ConsumerState<AuroraBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _driftController;

  @override
  void initState() {
    super.initState();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _driftController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 45),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _driftController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final profile = ref.watch(deviceProfileProvider);
    final isLite = MotionTokens.isLiteEffects(context, profile);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base canvas
          Container(color: theme.canvas),

          // Pre-rendered aurora gradient orbs
          if (isLite || _driftController == null)
            CustomPaint(
              painter: _AuroraOrbsPainter(
                isDark: theme.isDark,
                driftValue: 0.0,
                theme: theme,
              ),
              size: Size.infinite,
            )
          else
            AnimatedBuilder(
              animation: _driftController!,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AuroraOrbsPainter(
                    isDark: theme.isDark,
                    driftValue: _driftController!.value,
                    theme: theme,
                  ),
                  size: Size.infinite,
                );
              },
            ),

          // Faint hairline grid overlay
          if (widget.showGrid)
            CustomPaint(
              painter: _HairlineGridPainter(
                gridColor: theme.hairline.withValues(alpha: theme.isDark ? 0.25 : 0.40),
              ),
              size: Size.infinite,
            ),

          // Foreground content
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraOrbsPainter extends CustomPainter {
  final bool isDark;
  final double driftValue;
  final SettlivThemeExtension theme;

  const _AuroraOrbsPainter({
    required this.isDark,
    required this.driftValue,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final w = size.width;
    final h = size.height;

    // Small drift offset (-12px to +12px)
    final driftX = (driftValue - 0.5) * 24.0;
    final driftY = (driftValue - 0.5) * 16.0;

    if (isDark) {
      // Midnight Glass orbs:
      // 1. Violet orb (top left)
      final violetShader = RadialGradient(
        center: Alignment(-0.6 + (driftX / w), -0.6 + (driftY / h)),
        radius: 1.1,
        colors: [
          theme.auroraViolet.withValues(alpha: 0.35),
          theme.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = violetShader);

      // 2. Deep indigo orb (center right)
      final indigoShader = RadialGradient(
        center: Alignment(0.7 - (driftX / w), -0.1 - (driftY / h)),
        radius: 0.95,
        colors: [
          theme.accent.withValues(alpha: 0.20),
          theme.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = indigoShader);

      // 3. Cool blue glow (bottom right)
      final blueShader = RadialGradient(
        center: Alignment(0.5 + (driftX / w), 0.8 + (driftY / h)),
        radius: 1.0,
        colors: [
          theme.auroraBlue.withValues(alpha: 0.22),
          theme.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = blueShader);

      // 4. Faint teal orb (bottom left)
      final tealShader = RadialGradient(
        center: const Alignment(-0.7, 0.7),
        radius: 0.8,
        colors: [
          theme.emerald.withValues(alpha: 0.10),
          theme.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = tealShader);
    } else {
      // Pearl Glass orbs:
      // 1. Soft violet (top left)
      final violetShader = RadialGradient(
        center: Alignment(-0.6 + (driftX / w), -0.6 + (driftY / h)),
        radius: 1.2,
        colors: [
          theme.auroraViolet.withValues(alpha: 0.55),
          theme.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = violetShader);

      // 2. Cool blue (bottom right)
      final blueShader = RadialGradient(
        center: Alignment(0.8 - (driftX / w), 0.7 - (driftY / h)),
        radius: 1.1,
        colors: [
          theme.auroraBlue.withValues(alpha: 0.45),
          theme.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = blueShader);

      // 3. Subtle lavender wash (center)
      final washShader = RadialGradient(
        center: const Alignment(0.1, -0.2),
        radius: 0.9,
        colors: [
          theme.canvasWash.withValues(alpha: 0.35),
          theme.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = washShader);

      // 4. Faint mint glow (bottom left)
      final mintShader = RadialGradient(
        center: const Alignment(-0.8, 0.9),
        radius: 0.75,
        colors: [
          theme.emerald.withValues(alpha: 0.08),
          theme.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..shader = mintShader);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraOrbsPainter oldDelegate) {
    return oldDelegate.isDark != isDark ||
        (oldDelegate.driftValue - driftValue).abs() > 0.02;
  }
}

class _HairlineGridPainter extends CustomPainter {
  final Color gridColor;

  const _HairlineGridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    const step = 48.0;
    // Draw horizontal lines up to top 300px
    final maxY = size.height < 360 ? size.height : 360.0;
    for (double y = 0; y <= maxY; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Draw vertical lines
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, maxY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HairlineGridPainter oldDelegate) {
    return oldDelegate.gridColor != gridColor;
  }
}
