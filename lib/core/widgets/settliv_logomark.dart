import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Abstract logomark: a circle cut by a diagonal ribbon (single colour, CustomPainter).
class SettlivLogomark extends StatelessWidget {
  final double size;
  final Color? color;
  const SettlivLogomark({super.key, this.size = 48, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.settliv.ink;
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogomarkPainter(c)),
      ),
    );
  }
}

class _LogomarkPainter extends CustomPainter {
  final Color color;
  _LogomarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeW = size.width * 0.065;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Clip subsequent drawing to circle interior
    canvas.save();
    canvas.clipPath(
      Path()
        ..addOval(
          Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2),
        ),
    );

    // Ribbon: a diagonal band (parallelogram) from top-left to bottom-right
    final halfBand = size.width * 0.085;
    final angle = math.pi / 4; // 45°
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    // Normal to the ribbon direction is perpendicular to the diagonal
    final nx = sinA * halfBand;
    final ny = cosA * halfBand;

    // Ribbon runs along the diagonal; extend beyond the circle bounds
    const ext = 1.5; // extend factor beyond size
    final p1 = Offset(-size.width * ext, -size.height * ext);
    final p2 = Offset(size.width * ext, size.height * ext);

    final ribbonPath = Path()
      ..moveTo(p1.dx - nx, p1.dy + ny)
      ..lineTo(p2.dx - nx, p2.dy + ny)
      ..lineTo(p2.dx + nx, p2.dy - ny)
      ..lineTo(p1.dx + nx, p1.dy - ny)
      ..close();

    canvas.drawPath(ribbonPath, fillPaint);
    canvas.restore();

    // Draw circle outline on top
    canvas.drawCircle(Offset(cx, cy), r, strokePaint);
  }

  @override
  bool shouldRepaint(_LogomarkPainter old) => old.color != color;
}
