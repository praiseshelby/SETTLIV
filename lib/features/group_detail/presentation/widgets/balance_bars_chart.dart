import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/person.dart';

class BalanceBarsChart extends StatefulWidget {
  final Map<String, int> netBalances; // personId -> paise
  final List<Person> people;

  const BalanceBarsChart({
    super.key,
    required this.netBalances,
    required this.people,
  });

  @override
  State<BalanceBarsChart> createState() => _BalanceBarsChartState();
}

class _BalanceBarsChartState extends State<BalanceBarsChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    // Find maximum absolute balance for scaling
    int maxAbsPaise = 1;
    widget.netBalances.forEach((_, val) {
      if (val.abs() > maxAbsPaise) {
        maxAbsPaise = val.abs();
      }
    });

    final sortedEntries = widget.netBalances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Member balances',
                style: AppTypography.sectionHeader.copyWith(
                  color: theme.ink,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 16),
              for (final entry in sortedEntries) ...[
                Builder(builder: (context) {
                  final person = widget.people.firstWhere(
                    (p) => p.id == entry.key,
                    orElse: () => Person(
                      id: entry.key,
                      name: 'Member',
                      avatarInitials: 'M',
                    ),
                  );

                  final int paise = entry.value;
                  final double ratio =
                      (paise.abs() / maxAbsPaise) * _animation.value;
                  final bool isOwed = paise > 0;
                  final bool isZero = paise == 0;

                  final Color barColor = isZero
                      ? theme.tertiary.withValues(alpha: 0.3)
                      : (isOwed
                          ? (isDark
                              ? AppColors.emeraldBright
                              : AppColors.emerald)
                          : (isDark
                              ? AppColors.coralBright
                              : AppColors.coral));

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              person.id == 'person_arjun'
                                  ? 'You (${person.name})'
                                  : person.name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: theme.ink,
                                fontWeight: person.id == 'person_arjun'
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              isZero
                                  ? 'Settled'
                                  : CurrencyFormatter.formatPaise(
                                      paise,
                                      showSign: true,
                                      absolute: false,
                                    ),
                              style: AppTypography.caption.copyWith(
                                color: barColor,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Bi-directional bar centered at zero
                        SizedBox(
                          height: 8,
                          child: CustomPaint(
                            size: const Size(double.infinity, 8),
                            painter: _BalanceBarPainter(
                              ratio: ratio,
                              isOwed: isOwed,
                              isZero: isZero,
                              barColor: barColor,
                              trackColor: theme.raised,
                              hairlineColor: theme.hairline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _BalanceBarPainter extends CustomPainter {
  final double ratio;
  final bool isOwed;
  final bool isZero;
  final Color barColor;
  final Color trackColor;
  final Color hairlineColor;

  const _BalanceBarPainter({
    required this.ratio,
    required this.isOwed,
    required this.isZero,
    required this.barColor,
    required this.trackColor,
    required this.hairlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double midX = size.width / 2;
    final double radius = size.height / 2;

    // Draw background track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      trackPaint,
    );

    // Draw center zero line
    final linePaint = Paint()
      ..color = hairlineColor
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), linePaint);

    if (isZero || ratio <= 0.0) return;

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final double availableWidth = size.width / 2;
    final double barWidth = math.max(radius * 2, availableWidth * ratio);

    if (isOwed) {
      // Bar extends to the right from midX
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(midX, 0, barWidth, size.height),
          Radius.circular(radius),
        ),
        barPaint,
      );
    } else {
      // Bar extends to the left from midX
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(midX - barWidth, 0, barWidth, size.height),
          Radius.circular(radius),
        ),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BalanceBarPainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.barColor != barColor ||
        oldDelegate.trackColor != trackColor;
  }
}
