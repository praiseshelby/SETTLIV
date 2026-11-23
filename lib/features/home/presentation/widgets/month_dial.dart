import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';

class UpcomingDueItem {
  final String title;
  final DateTime dueDate;
  final int amountPaise;

  const UpcomingDueItem({
    required this.title,
    required this.dueDate,
    required this.amountPaise,
  });
}

class MonthDial extends StatelessWidget {
  final DateTime now;
  final double size;
  final List<UpcomingDueItem> upcomingItems;
  final VoidCallback? onTap;

  const MonthDial({
    super.key,
    required this.now,
    this.size = 64.0,
    this.upcomingItems = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final int today = now.day;
    final int daysLeft = math.max(0, daysInMonth - today);

    // Extract days with upcoming dues (days >= today in this month)
    final Set<int> dueDays = {};
    final List<UpcomingDueItem> futureItems = [];
    for (final item in upcomingItems) {
      if (item.dueDate.year == now.year && item.dueDate.month == now.month) {
        if (item.dueDate.day >= today) {
          dueDays.add(item.dueDate.day);
          futureItems.add(item);
        }
      }
    }
    futureItems.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final String tooltipMessage;
    if (futureItems.isNotEmpty) {
      tooltipMessage = futureItems.take(3).map((item) {
        final dateStr = DateFormat('EEE, d MMM').format(item.dueDate);
        final amt = CurrencyFormatter.formatPaise(item.amountPaise, absolute: true);
        return '${item.title} ($amt) · $dateStr';
      }).join('\n');
    } else {
      tooltipMessage = 'No dues this month';
    }

    final UpcomingDueItem? nextItem = futureItems.isNotEmpty ? futureItems.first : null;

    return Semantics(
      button: true,
      label: 'Month overview: $daysLeft days left. $tooltipMessage',
      child: Tooltip(
        message: tooltipMessage,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Beside the dial: two short lines
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nextItem != null
                          ? 'Next: ${nextItem.title} · ${DateFormat('EEE d MMM').format(nextItem.dueDate)}'
                          : 'No dues this month',
                      style: AppTypography.caption.copyWith(
                        color: theme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (nextItem != null)
                      Text(
                        CurrencyFormatter.formatPaise(nextItem.amountPaise, absolute: true),
                        style: TextStyle(
                          fontFamily: AppTypography.fontDisplay,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    else
                      Text(
                        'All settled',
                        style: AppTypography.caption.copyWith(
                          color: theme.textEmerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Radial Dial
                SizedBox(
                  width: size,
                  height: size,
                  child: CustomPaint(
                    painter: MonthDialPainter(
                      today: today,
                      daysInMonth: daysInMonth,
                      daysLeft: daysLeft,
                      dueDays: dueDays,
                      accentColor: theme.accent,
                      hairlineColor: theme.hairline,
                      inkColor: theme.ink,
                      mutedColor: theme.muted,
                      coralColor: theme.coral,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MonthDialPainter extends CustomPainter {
  final int today;
  final int daysInMonth;
  final int daysLeft;
  final Set<int> dueDays;
  final Color accentColor;
  final Color hairlineColor;
  final Color inkColor;
  final Color mutedColor;
  final Color coralColor;

  const MonthDialPainter({
    required this.today,
    required this.daysInMonth,
    required this.daysLeft,
    required this.dueDays,
    required this.accentColor,
    required this.hairlineColor,
    required this.inkColor,
    required this.mutedColor,
    required this.coralColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 2.5;
    const startAngle = -math.pi / 2; // 12 o'clock

    final tickPaintInactive = Paint()
      ..color = hairlineColor
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    final tickPaintActive = Paint()
      ..color = accentColor
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);

    final dueDotPaint = Paint()
      ..color = coralColor
      ..style = PaintingStyle.fill;

    // Draw ticks around the dial for each day
    for (int day = 1; day <= daysInMonth; day++) {
      final angle = startAngle + (day / daysInMonth) * 2 * math.pi;
      final isPassedOrToday = day <= today;
      final isToday = day == today;
      final hasDue = dueDays.contains(day);

      final innerR = radius - (isToday ? 6.0 : 4.5);
      final outerR = radius;

      final p1 = Offset(center.dx + innerR * math.cos(angle), center.dy + innerR * math.sin(angle));
      final p2 = Offset(center.dx + outerR * math.cos(angle), center.dy + outerR * math.sin(angle));

      if (isToday) {
        canvas.drawCircle(p2, 3.5, glowPaint);
        canvas.drawLine(p1, p2, tickPaintActive..strokeWidth = 2.0);
      } else if (isPassedOrToday) {
        canvas.drawLine(p1, p2, tickPaintActive..strokeWidth = 1.3);
      } else {
        canvas.drawLine(p1, p2, tickPaintInactive);
      }

      // Small marker dot (not capsule) on days with upcoming dues
      if (hasDue) {
        final dotR = radius + 1.8;
        final dotCenter = Offset(center.dx + dotR * math.cos(angle), center.dy + dotR * math.sin(angle));
        canvas.drawCircle(dotCenter, 1.8, dueDotPaint);
      }
    }

    // Filled arc up to today
    final arcPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final sweepAngle = (today / daysInMonth) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 7.5),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );

    // Center: Large "N" (days left)
    final numPainter = TextPainter(
      text: TextSpan(
        text: '$daysLeft',
        style: TextStyle(
          fontFamily: AppTypography.fontHeading,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: inkColor,
          letterSpacing: -0.8,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final numOffset = Offset(
      center.dx - (numPainter.width / 2),
      center.dy - (numPainter.height / 2) - 4.5,
    );
    numPainter.paint(canvas, numOffset);

    // Below "N": "days left"
    final labelPainter = TextPainter(
      text: TextSpan(
        text: 'days left',
        style: TextStyle(
          fontFamily: AppTypography.fontBody,
          fontSize: 8.0,
          fontWeight: FontWeight.w600,
          color: mutedColor,
          letterSpacing: 0.2,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final labelOffset = Offset(
      center.dx - (labelPainter.width / 2),
      center.dy + 8.5,
    );
    labelPainter.paint(canvas, labelOffset);
  }

  @override
  bool shouldRepaint(covariant MonthDialPainter oldDelegate) {
    return oldDelegate.today != today ||
        oldDelegate.daysInMonth != daysInMonth ||
        oldDelegate.daysLeft != daysLeft ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.inkColor != inkColor ||
        oldDelegate.dueDays != dueDays;
  }
}
