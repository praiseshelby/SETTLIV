import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

class MonthDial extends StatelessWidget {
  final DateTime now;
  final double size;

  const MonthDial({
    super.key,
    required this.now,
    this.size = 68.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final int today = now.day;
    final String tooltip = 'Day $today of $daysInMonth';
    final String monthAbbr = _getMonthAbbr(now.month);

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: MonthDialPainter(
              today: today,
              daysInMonth: daysInMonth,
              monthAbbr: monthAbbr,
              accentColor: theme.accent,
              hairlineColor: theme.hairline,
              inkColor: theme.ink,
              mutedColor: theme.muted,
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'
    ];
    return months[month - 1];
  }
}

class MonthDialPainter extends CustomPainter {
  final int today;
  final int daysInMonth;
  final String monthAbbr;
  final Color accentColor;
  final Color hairlineColor;
  final Color inkColor;
  final Color mutedColor;

  const MonthDialPainter({
    required this.today,
    required this.daysInMonth,
    required this.monthAbbr,
    required this.accentColor,
    required this.hairlineColor,
    required this.inkColor,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.0;
    const startAngle = -math.pi / 2; // 12 o'clock

    final tickPaintInactive = Paint()
      ..color = hairlineColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final tickPaintActive = Paint()
      ..color = accentColor
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    // Draw ticks around the dial
    for (int day = 1; day <= daysInMonth; day++) {
      final angle = startAngle + (day / daysInMonth) * 2 * math.pi;
      final isPassedOrToday = day <= today;
      final isToday = day == today;

      final innerR = radius - (isToday ? 6.5 : 5.0);
      final outerR = radius;

      final p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
      final p2 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));

      if (isToday) {
        // Draw soft glow behind today's tick
        canvas.drawCircle(p2, 4.0, glowPaint);
        canvas.drawLine(p1, p2, tickPaintActive..strokeWidth = 2.0);
      } else if (isPassedOrToday) {
        canvas.drawLine(p1, p2, tickPaintActive..strokeWidth = 1.4);
      } else {
        canvas.drawLine(p1, p2, tickPaintInactive);
      }
    }

    // Filled arc up to today
    final arcPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final sweepAngle = (today / daysInMonth) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 8.0),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Large day number in center
    final dayTextPainter = TextPainter(
      text: TextSpan(
        text: '$today',
        style: TextStyle(
          fontFamily: AppTypography.fontHeading,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: inkColor,
          letterSpacing: -0.8,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dayOffset = Offset(
      center.dx - (dayTextPainter.width / 2),
      center.dy - (dayTextPainter.height / 2) - 5.0,
    );
    dayTextPainter.paint(canvas, dayOffset);

    // Month abbreviation under the day number
    final monthTextPainter = TextPainter(
      text: TextSpan(
        text: monthAbbr,
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          color: mutedColor,
          letterSpacing: 0.6,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final monthOffset = Offset(
      center.dx - (monthTextPainter.width / 2),
      center.dy + 8.0,
    );
    monthTextPainter.paint(canvas, monthOffset);
  }

  @override
  bool shouldRepaint(covariant MonthDialPainter oldDelegate) {
    return oldDelegate.today != today ||
        oldDelegate.daysInMonth != daysInMonth ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.inkColor != inkColor;
  }
}
