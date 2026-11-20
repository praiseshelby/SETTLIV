import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/expense.dart';

class CategoryDonutChart extends StatelessWidget {
  final Map<ExpenseCategory, int> categorySpend; // category -> paise
  final int totalSpend; // in paise

  const CategoryDonutChart({
    super.key,
    required this.categorySpend,
    required this.totalSpend,
  });

  static Map<ExpenseCategory, Color> buildCategoryColors(SettlivThemeExtension theme) {
    return {
      ExpenseCategory.food: theme.saffron,
      ExpenseCategory.rent: theme.navy,
      ExpenseCategory.travel: theme.teal,
      ExpenseCategory.stay: theme.orchid,
      ExpenseCategory.groceries: theme.emerald,
      ExpenseCategory.bills: theme.coral,
      ExpenseCategory.fun: theme.orchid,
      ExpenseCategory.other: theme.muted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final categoryColors = buildCategoryColors(theme);

    if (totalSpend <= 0) {
      return GlassSurface(
        level: GlassLevel.level2,
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No expenses recorded yet',
            style: AppTypography.body.copyWith(color: theme.muted),
          ),
        ),
      );
    }

    final activeEntries = categorySpend.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spend by category',
            style: AppTypography.sectionHeader.copyWith(
              color: theme.ink,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(170, 170),
                    painter: _DonutChartPainter(
                      entries: activeEntries,
                      total: totalSpend,
                      categoryColors: categoryColors,
                      strokeWidth: 22.0,
                      transparentColor: theme.transparent,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: AppTypography.caption.copyWith(
                            color: theme.muted,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatPaise(totalSpend),
                          style: AppTypography.moneyMedium.copyWith(
                            color: theme.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final entry in activeEntries) ...[
                Builder(builder: (context) {
                  final pct = ((entry.value / totalSpend) * 100).toStringAsFixed(0);
                  final color = categoryColors[entry.key] ?? theme.muted;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.key.label} $pct%',
                        style: AppTypography.caption.copyWith(
                          color: theme.ink,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<MapEntry<ExpenseCategory, int>> entries;
  final int total;
  final Map<ExpenseCategory, Color> categoryColors;
  final double strokeWidth;
  final Color transparentColor;

  const _DonutChartPainter({
    required this.entries,
    required this.total,
    required this.categoryColors,
    required this.strokeWidth,
    required this.transparentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || entries.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    double startAngle = -math.pi / 2;
    const double gapAngle = 0.05;

    for (final entry in entries) {
      final sweepAngle = (entry.value / total) * (2 * math.pi) - gapAngle;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = categoryColors[entry.key] ?? transparentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + (gapAngle / 2),
        sweepAngle,
        false,
        paint,
      );

      startAngle += (entry.value / total) * (2 * math.pi);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return total != oldDelegate.total ||
        strokeWidth != oldDelegate.strokeWidth ||
        transparentColor != oldDelegate.transparentColor ||
        !listEquals(entries, oldDelegate.entries) ||
        !mapEquals(categoryColors, oldDelegate.categoryColors);
  }
}
