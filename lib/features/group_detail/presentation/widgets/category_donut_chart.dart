import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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

  static Color getCategoryColor(ExpenseCategory category, bool isDark) {
    switch (category) {
      case ExpenseCategory.food:
        return AppColors.amber;
      case ExpenseCategory.rent:
        return AppColors.sapphire;
      case ExpenseCategory.travel:
        return AppColors.aqua;
      case ExpenseCategory.stay:
        return AppColors.lilac;
      case ExpenseCategory.groceries:
        return AppColors.emerald;
      case ExpenseCategory.bills:
        return AppColors.coral;
      case ExpenseCategory.fun:
        return AppColors.orchid;
      case ExpenseCategory.other:
        return isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    if (totalSpend <= 0) {
      return GlassSurface(
        level: GlassLevel.level2,
        borderRadius: 24,
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No expenses recorded yet',
            style: AppTypography.body.copyWith(color: theme.secondary),
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
                      isDark: isDark,
                      strokeWidth: 22.0,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total',
                          style: AppTypography.caption.copyWith(
                            color: theme.secondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatPaise(totalSpend,
                              absolute: true),
                          style: AppTypography.displayMoney.copyWith(
                            fontSize: 18,
                            color: theme.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Legend grid
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              for (final entry in activeEntries) ...[
                Builder(builder: (context) {
                  final pct = ((entry.value / totalSpend) * 100).round();
                  final color = getCategoryColor(entry.key, isDark);

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
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
                          fontWeight: FontWeight.w600,
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
  final bool isDark;
  final double strokeWidth;

  const _DonutChartPainter({
    required this.entries,
    required this.total,
    required this.isDark,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || entries.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    double startAngle = -math.pi / 2;
    const double gapAngle = 0.05; // Small gap between segments

    for (final entry in entries) {
      final sweepAngle = (entry.value / total) * (2 * math.pi) - gapAngle;
      if (sweepAngle <= 0) continue;

      final paint = Paint()
        ..color = CategoryDonutChart.getCategoryColor(entry.key, isDark)
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
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}
