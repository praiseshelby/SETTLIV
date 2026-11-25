import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/web_glass_card.dart';
import '../../../../data/models/expense.dart';

class ThisMonthWebCard extends StatefulWidget {
  final List<Expense> expenses;
  final String currentUserId;
  final DateTime now;
  final int thisMonthSpend;
  final int lastMonthSpend;
  final bool isCompact;

  const ThisMonthWebCard({
    super.key,
    required this.expenses,
    required this.currentUserId,
    required this.now,
    required this.thisMonthSpend,
    required this.lastMonthSpend,
    this.isCompact = false,
  });

  @override
  State<ThisMonthWebCard> createState() => _ThisMonthWebCardState();
}

class _ThisMonthWebCardState extends State<ThisMonthWebCard> {
  int? _hoveredDay;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final now = widget.now;
    final monthName = DateFormat('MMMM').format(now);
    final int daysInThisMonth = DateTime(now.year, now.month + 1, 0).day;
    final int daysInLastMonth = DateTime(now.year, now.month, 0).day;
    final int maxDays = math.max(daysInThisMonth, daysInLastMonth);

    // Build daily spend buckets for this month and last month
    final List<int> thisDaily = List.filled(maxDays + 1, 0);
    final List<int> lastDaily = List.filled(maxDays + 1, 0);
    Expense? biggestExpense;
    int biggestShare = 0;

    final int lastMonthYear = now.month == 1 ? now.year - 1 : now.year;
    final int lastMonthNum = now.month == 1 ? 12 : now.month - 1;

    for (final exp in widget.expenses) {
      if (exp.isDeleted) continue;
      final share = exp.computedShares[widget.currentUserId] ??
          exp.shares[widget.currentUserId] ??
          0;
      if (share <= 0) continue;

      if (exp.date.year == now.year && exp.date.month == now.month) {
        if (exp.date.day >= 1 && exp.date.day <= maxDays) {
          thisDaily[exp.date.day] += share;
        }
        if (share > biggestShare) {
          biggestShare = share;
          biggestExpense = exp;
        }
      } else if (exp.date.year == lastMonthYear &&
          exp.date.month == lastMonthNum) {
        if (exp.date.day >= 1 && exp.date.day <= maxDays) {
          lastDaily[exp.date.day] += share;
        }
      }
    }

    // Cumulative arrays
    final List<int> thisCum = List.filled(now.day + 1, 0);
    for (int d = 1; d <= now.day; d++) {
      thisCum[d] = thisCum[d - 1] + thisDaily[d];
    }

    final List<int> lastCum = List.filled(daysInLastMonth + 1, 0);
    for (int d = 1; d <= daysInLastMonth; d++) {
      lastCum[d] = lastCum[d - 1] + lastDaily[d];
    }

    final int dailyAvg = now.day > 0 ? widget.thisMonthSpend ~/ now.day : 0;
    final int diff = widget.thisMonthSpend - widget.lastMonthSpend;
    final bool disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return WebGlassCard(
      borderRadius: 24,
      padding: EdgeInsets.all(widget.isCompact ? 16 : 22),
      onTap: () => context.go('/insights'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: "This month" + month name
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'This month',
                    style: TextStyle(
                      fontFamily: AppTypography.fontBrand,
                      fontFamilyFallback: AppTypography.brandFallback,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    monthName,
                    style: AppTypography.caption.copyWith(
                      color: theme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Icon(Icons.arrow_forward_rounded, size: 16, color: theme.muted),
            ],
          ),
          const SizedBox(height: 10),

          // Big amount (count-up)
          TweenAnimationBuilder<int>(
            tween: IntTween(
              begin: disableAnimations ? widget.thisMonthSpend : 0,
              end: widget.thisMonthSpend,
            ),
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                CurrencyFormatter.formatPaise(value, absolute: true),
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: theme.ink,
                  letterSpacing: -0.6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),
          const SizedBox(height: 4),

          // Delta line
          _buildDeltaLine(theme, diff),
          const SizedBox(height: 12),

          // Cumulative spend chart with hover tooltip
          SizedBox(
            height: 82,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onHover: (event) {
                    if (constraints.maxWidth <= 0) return;
                    final frac =
                        (event.localPosition.dx / constraints.maxWidth)
                            .clamp(0.0, 1.0);
                    final day =
                        (1 + (frac * (maxDays - 1)).round()).clamp(1, maxDays);
                    if (_hoveredDay != day) {
                      setState(() => _hoveredDay = day);
                    }
                  },
                  onExit: (_) {
                    if (_hoveredDay != null) {
                      setState(() => _hoveredDay = null);
                    }
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _CumulativeSpendChartPainter(
                              thisCum: thisCum,
                              lastCum: lastCum,
                              today: now.day,
                              maxDays: maxDays,
                              hoveredDay: _hoveredDay,
                              accentColor: theme.accent,
                              mutedColor: theme.muted,
                              hairlineColor: theme.hairline,
                              surfaceColor: theme.surfaceSolid,
                            ),
                          ),
                        ),
                      ),
                      if (_hoveredDay != null)
                        Positioned(
                          top: -4,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.surfaceSolid,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.hairline),
                            ),
                            child: Text(
                              'Day $_hoveredDay · ${_hoveredDay! <= now.day ? CurrencyFormatter.formatPaise(thisCum[_hoveredDay!], absolute: true) : "—"} (prev ${_hoveredDay! <= daysInLastMonth ? CurrencyFormatter.formatPaise(lastCum[_hoveredDay!], absolute: true) : "—"})',
                              style: AppTypography.caption.copyWith(
                                color: theme.ink,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Quiet stats row: Daily average & Biggest expense
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.hairline)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily average',
                        style: AppTypography.caption.copyWith(
                          color: theme.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.formatPaise(dailyAvg, absolute: true),
                        style: AppTypography.bodySemiBold.copyWith(
                          color: theme.ink,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Biggest expense',
                        style: AppTypography.caption.copyWith(
                          color: theme.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        biggestExpense != null
                            ? '${CurrencyFormatter.formatPaise(biggestShare, absolute: true)} · ${biggestExpense.title}'
                            : 'None yet',
                        style: AppTypography.bodySemiBold.copyWith(
                          color: theme.ink,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaLine(SettlivThemeExtension theme, int diff) {
    if (widget.lastMonthSpend == 0) {
      return Text(
        'First month on Settliv',
        style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 12),
      );
    }
    if (widget.lastMonthSpend < 100000) {
      return Text(
        'Last month: ${CurrencyFormatter.formatPaise(widget.lastMonthSpend, absolute: true)}',
        style: AppTypography.caption.copyWith(
          color: theme.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    final isMore = diff > 0;
    final color = isMore ? theme.textCoral : theme.textEmerald;
    final formatted = CurrencyFormatter.formatPaise(diff.abs(), absolute: true);
    return Row(
      children: [
        Icon(
          isMore ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            isMore
                ? '$formatted more than last month'
                : '$formatted less than last month',
            style: AppTypography.caption.copyWith(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CumulativeSpendChartPainter extends CustomPainter {
  final List<int> thisCum;
  final List<int> lastCum;
  final int today;
  final int maxDays;
  final int? hoveredDay;
  final Color accentColor;
  final Color mutedColor;
  final Color hairlineColor;
  final Color surfaceColor;

  const _CumulativeSpendChartPainter({
    required this.thisCum,
    required this.lastCum,
    required this.today,
    required this.maxDays,
    required this.hoveredDay,
    required this.accentColor,
    required this.mutedColor,
    required this.hairlineColor,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || maxDays <= 1) return;

    int maxVal = 100;
    for (final v in thisCum) {
      if (v > maxVal) maxVal = v;
    }
    for (final v in lastCum) {
      if (v > maxVal) maxVal = v;
    }

    double xForDay(int day) => ((day - 1) / (maxDays - 1)) * size.width;
    double yForVal(int val) {
      final norm = (val / maxVal).clamp(0.0, 1.0);
      return size.height - 6 - (norm * (size.height - 14));
    }

    // Baseline
    canvas.drawLine(
      Offset(0, size.height - 6),
      Offset(size.width, size.height - 6),
      Paint()
        ..color = hairlineColor
        ..strokeWidth = 1.0,
    );

    // Last month dashed line
    if (lastCum.length > 1) {
      final lastPaint = Paint()
        ..color = mutedColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;

      final lastPath = Path();
      for (int d = 1; d < lastCum.length; d++) {
        final pt = Offset(xForDay(d), yForVal(lastCum[d]));
        if (d == 1) {
          lastPath.moveTo(pt.dx, pt.dy);
        } else {
          lastPath.lineTo(pt.dx, pt.dy);
        }
      }
      for (final metric in lastPath.computeMetrics()) {
        double dist = 0.0;
        while (dist < metric.length) {
          final next = math.min(dist + 4.0, metric.length);
          canvas.drawPath(metric.extractPath(dist, next), lastPaint);
          dist += 8.0;
        }
      }
    }

    // This month solid line + soft area
    if (thisCum.length > 1) {
      final linePath = Path();
      final areaPath = Path();
      for (int d = 1; d <= today && d < thisCum.length; d++) {
        final pt = Offset(xForDay(d), yForVal(thisCum[d]));
        if (d == 1) {
          linePath.moveTo(pt.dx, pt.dy);
          areaPath.moveTo(pt.dx, size.height - 6);
          areaPath.lineTo(pt.dx, pt.dy);
        } else {
          linePath.lineTo(pt.dx, pt.dy);
          areaPath.lineTo(pt.dx, pt.dy);
        }
      }
      final lastPt = Offset(xForDay(today), yForVal(thisCum[today]));
      areaPath.lineTo(lastPt.dx, size.height - 6);
      areaPath.close();

      canvas.drawPath(
        areaPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withValues(alpha: 0.22),
              accentColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );

      canvas.drawPath(
        linePath,
        Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      // Today marker
      canvas.drawCircle(lastPt, 4.5, Paint()..color = accentColor);
      canvas.drawCircle(lastPt, 2.0, Paint()..color = surfaceColor);
    }

    // Hover crosshair
    if (hoveredDay != null) {
      final hx = xForDay(hoveredDay!);
      canvas.drawLine(
        Offset(hx, 2),
        Offset(hx, size.height - 6),
        Paint()
          ..color = mutedColor.withValues(alpha: 0.35)
          ..strokeWidth = 1.0,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CumulativeSpendChartPainter oldDelegate) =>
      oldDelegate.today != today ||
      oldDelegate.hoveredDay != hoveredDay ||
      oldDelegate.thisCum != thisCum ||
      oldDelegate.accentColor != accentColor;
}
