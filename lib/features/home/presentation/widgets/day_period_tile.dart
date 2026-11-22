import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/day_period_palette.dart';

enum DayPeriod {
  sunrise, // 5 to 12
  sun,     // 12 to 17
  sunset,  // 17 to 21
  moon,    // 21 to 5
}

DayPeriod getDayPeriod(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return DayPeriod.sunrise;
  } else if (hour >= 12 && hour < 17) {
    return DayPeriod.sun;
  } else if (hour >= 17 && hour < 21) {
    return DayPeriod.sunset;
  } else {
    return DayPeriod.moon;
  }
}

String getTimeGreeting(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return 'Good morning';
  } else if (hour >= 12 && hour < 17) {
    return 'Good afternoon';
  } else if (hour >= 17 && hour < 21) {
    return 'Good evening';
  } else {
    return 'Good night';
  }
}

class DayPeriodTile extends StatefulWidget {
  final DateTime? now;

  const DayPeriodTile({super.key, this.now});

  @override
  State<DayPeriodTile> createState() => _DayPeriodTileState();
}

class _DayPeriodTileState extends State<DayPeriodTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _riseController;
  late Animation<double> _riseAnimation;

  @override
  void initState() {
    super.initState();
    _riseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _riseAnimation = CurvedAnimation(
      parent: _riseController,
      curve: Curves.easeOutBack,
    );
    _riseController.forward();
  }

  @override
  void dispose() {
    _riseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final now = widget.now ?? DateTime.now();
    final period = getDayPeriod(now);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _riseAnimation,
        builder: (context, _) {
          return Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: _getBackgroundGradient(period, theme),
              border: Border.all(color: theme.hairline, width: 1),
              boxShadow: [
                BoxShadow(
                  color: theme.shadow.withOpacity(theme.isDark ? 0.35 : 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                painter: _DayPeriodPainter(
                  period: period,
                  progress: _riseAnimation.value,
                  isDark: theme.isDark,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  LinearGradient _getBackgroundGradient(DayPeriod period, SettlivThemeExtension theme) {
    switch (period) {
      case DayPeriod.sunrise:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: DayPeriodPalette.sunriseGradient,
        );
      case DayPeriod.sun:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: DayPeriodPalette.sunGradient,
        );
      case DayPeriod.sunset:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: DayPeriodPalette.sunsetGradient,
        );
      case DayPeriod.moon:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: DayPeriodPalette.moonGradient,
        );
    }
  }
}

class _DayPeriodPainter extends CustomPainter {
  final DayPeriod period;
  final double progress;
  final bool isDark;

  const _DayPeriodPainter({
    required this.period,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final riseOffset = (1.0 - progress) * 8.0;

    switch (period) {
      case DayPeriod.sunrise:
        // Horizon line + rising half-sun with rays
        final horizonPaint = Paint()
          ..color = DayPeriodPalette.sun
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(8, cy + 4),
          Offset(size.width - 8, cy + 4),
          horizonPaint,
        );

        final sunPaint = Paint()
          ..color = DayPeriodPalette.sun
          ..style = PaintingStyle.fill;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy + 4 + riseOffset), radius: 10),
          math.pi,
          math.pi,
          true,
          sunPaint,
        );
        break;

      case DayPeriod.sun:
        // Full bright sun with soft glow
        final glowPaint = Paint()
          ..color = DayPeriodPalette.sun.withOpacity(0.25)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy + riseOffset), 15, glowPaint);

        final sunPaint = Paint()
          ..color = DayPeriodPalette.sun
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx, cy + riseOffset), 9, sunPaint);
        break;

      case DayPeriod.sunset:
        // Setting amber sun sinking below horizon
        final horizonPaint = Paint()
          ..color = DayPeriodPalette.sunset
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(8, cy + 6),
          Offset(size.width - 8, cy + 6),
          horizonPaint,
        );

        final sunPaint = Paint()
          ..color = DayPeriodPalette.sunset
          ..style = PaintingStyle.fill;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy + 6 + riseOffset), radius: 11),
          math.pi * 0.9,
          math.pi * 1.2,
          true,
          sunPaint,
        );
        break;

      case DayPeriod.moon:
        // Crescent moon + tiny star
        final moonCenter = Offset(cx, cy + riseOffset);
        final moonPaint = Paint()
          ..color = DayPeriodPalette.moon
          ..style = PaintingStyle.fill;

        final path = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: moonCenter, radius: 9)),
          Path()..addOval(Rect.fromCircle(center: Offset(moonCenter.dx + 4, moonCenter.dy - 3), radius: 8)),
        );
        canvas.drawPath(path, moonPaint);

        // Tiny star
        final starPaint = Paint()
          ..color = DayPeriodPalette.star
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(cx + 8, cy - 6 + riseOffset), 1.5, starPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DayPeriodPainter oldDelegate) {
    return oldDelegate.period != period ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark;
  }
}
