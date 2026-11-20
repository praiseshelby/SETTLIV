import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base solid canvas
          Container(
            color: theme.canvas,
          ),
          // Static, cached radial aurora wash
          CustomPaint(
            painter: _AuroraPainter(
              canvasColor: theme.canvas,
              violetColor: theme.auroraViolet,
              blueColor: theme.auroraBlue,
              washColor: theme.canvasWash,
              isDark: theme.isDark,
            ),
            size: Size.infinite,
          ),
          // Foreground content
          widgetChild(child),
        ],
      ),
    );
  }

  static Widget widgetChild(Widget child) => child;
}

class _AuroraPainter extends CustomPainter {
  final Color canvasColor;
  final Color violetColor;
  final Color blueColor;
  final Color washColor;
  final bool isDark;

  const _AuroraPainter({
    required this.canvasColor,
    required this.violetColor,
    required this.blueColor,
    required this.washColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    if (isDark) {
      // Midnight Glass: canvas with violet wash #1A1640 at ~45%
      final washPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.6, -0.6),
          radius: 1.2,
          colors: [
            washColor.withValues(alpha: 0.45),
            canvasColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), washPaint);

      // Subtle cool ambient glow bottom right
      final darkBluePaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.7, 0.8),
          radius: 1.0,
          colors: [
            blueColor.withValues(alpha: 0.20),
            canvasColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), darkBluePaint);
    } else {
      // Pearl Glass: soft violet radial #E9E5FF at ~50% top-left
      final violetPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.7, -0.7),
          radius: 1.2,
          colors: [
            violetColor.withValues(alpha: 0.50),
            canvasColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), violetPaint);

      // faint cool-blue #E4EEFF at ~40% bottom-right
      final bluePaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.8, 0.8),
          radius: 1.1,
          colors: [
            blueColor.withValues(alpha: 0.40),
            canvasColor.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bluePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.canvasColor != canvasColor ||
        oldDelegate.violetColor != violetColor ||
        oldDelegate.blueColor != blueColor ||
        oldDelegate.washColor != washColor ||
        oldDelegate.isDark != isDark;
  }
}
