import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 12 built-in abstract geometric stock avatars drawn with CustomPainter.
class StockAvatarPainter extends CustomPainter {
  final int index;
  final SettlivThemeExtension theme;

  const StockAvatarPainter({
    required this.index,
    required this.theme,
  });

  static const int count = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final idx = index % count;
    final palette = theme.avatarGradients[idx % theme.avatarGradients.length];
    final bg = palette.first;
    final fg = palette.last;
    final accent = idx.isEven ? theme.emerald : theme.saffron;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(center, r, Paint()..color = bg);

    final shapePaint = Paint()
      ..color = fg.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.08)
      ..strokeCap = StrokeCap.round;

    switch (idx) {
      case 0:
        canvas.drawCircle(center + Offset(-r * 0.2, -r * 0.2), r * 0.45, shapePaint);
        canvas.drawCircle(center + Offset(r * 0.25, r * 0.25), r * 0.25, linePaint);
      case 1:
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r * 0.65),
          -math.pi / 4,
          math.pi,
          true,
          shapePaint,
        );
        canvas.drawCircle(center - Offset(r * 0.25, r * 0.2), r * 0.16, Paint()..color = accent);
      case 2:
        final p = Path()
          ..moveTo(center.dx, center.dy - r * 0.55)
          ..lineTo(center.dx + r * 0.5, center.dy + r * 0.4)
          ..lineTo(center.dx - r * 0.5, center.dy + r * 0.4)
          ..close();
        canvas.drawPath(p, shapePaint);
      case 3:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: r * 1.1, height: r * 0.6),
            Radius.circular(r * 0.3),
          ),
          shapePaint,
        );
        canvas.drawCircle(center, r * 0.2, Paint()..color = accent);
      case 4:
        canvas.drawCircle(center, r * 0.52, linePaint);
        canvas.drawCircle(center, r * 0.22, shapePaint);
      case 5:
        canvas.drawLine(
          Offset(center.dx - r * 0.5, center.dy + r * 0.35),
          Offset(center.dx + r * 0.5, center.dy - r * 0.35),
          linePaint,
        );
        canvas.drawCircle(center + Offset(-r * 0.25, -r * 0.25), r * 0.22, shapePaint);
      case 6:
        final diamond = Path()
          ..moveTo(center.dx, center.dy - r * 0.6)
          ..lineTo(center.dx + r * 0.55, center.dy)
          ..lineTo(center.dx, center.dy + r * 0.6)
          ..lineTo(center.dx - r * 0.55, center.dy)
          ..close();
        canvas.drawPath(diamond, shapePaint);
      case 7:
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r * 0.6),
          0,
          math.pi * 1.35,
          false,
          linePaint,
        );
        canvas.drawCircle(center, r * 0.28, shapePaint);
      case 8:
        canvas.drawCircle(center + Offset(0, -r * 0.25), r * 0.35, shapePaint);
        canvas.drawArc(
          Rect.fromCircle(center: center + Offset(0, r * 0.55), radius: r * 0.55),
          math.pi,
          math.pi,
          true,
          Paint()..color = accent.withValues(alpha: 0.85),
        );
      case 9:
        for (int i = -1; i <= 1; i++) {
          canvas.drawLine(
            Offset(center.dx - r * 0.45, center.dy + i * r * 0.28),
            Offset(center.dx + r * 0.45, center.dy + i * r * 0.28),
            linePaint,
          );
        }
      case 10:
        canvas.drawCircle(center + Offset(-r * 0.22, 0), r * 0.32, shapePaint);
        canvas.drawCircle(center + Offset(r * 0.22, 0), r * 0.32, Paint()..color = accent.withValues(alpha: 0.85));
      case 11:
      default:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: r * 0.9, height: r * 0.9),
            Radius.circular(r * 0.22),
          ),
          linePaint,
        );
        canvas.drawCircle(center, r * 0.24, shapePaint);
    }
  }

  @override
  bool shouldRepaint(covariant StockAvatarPainter oldDelegate) =>
      index != oldDelegate.index || theme != oldDelegate.theme;
}
