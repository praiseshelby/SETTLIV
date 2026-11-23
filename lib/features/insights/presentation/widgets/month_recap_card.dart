import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/expense.dart';

class MonthRecapCard extends StatelessWidget {
  final List<Expense> expenses;
  final String currentUserId;
  final DateTime now;

  const MonthRecapCard({
    super.key,
    required this.expenses,
    required this.currentUserId,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    // Filter active expenses for this month and last month
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    int thisMonthSpendPaise = 0;
    int lastMonthSpendPaise = 0;
    final categoryTotals = <ExpenseCategory, int>{};

    for (final e in expenses) {
      if (e.isDeleted) continue;
      // User's share of spending
      final userShare = e.computedShares[currentUserId] ?? 0;
      if (userShare <= 0) continue;

      if (!e.date.isBefore(thisMonthStart) && !e.date.isAfter(thisMonthEnd)) {
        thisMonthSpendPaise += userShare;
        categoryTotals[e.category] = (categoryTotals[e.category] ?? 0) + userShare;
      } else if (!e.date.isBefore(lastMonthStart) && !e.date.isAfter(lastMonthEnd)) {
        lastMonthSpendPaise += userShare;
      }
    }

    // Identify biggest category
    ExpenseCategory? topCategory;
    int topCategoryPaise = 0;
    categoryTotals.forEach((cat, paise) {
      if (paise > topCategoryPaise) {
        topCategoryPaise = paise;
        topCategory = cat;
      }
    });

    // Build plain sentences
    final spendStr = CurrencyFormatter.formatPaise(thisMonthSpendPaise);
    String comparisonStr = '';
    if (lastMonthSpendPaise > 0) {
      final diff = thisMonthSpendPaise - lastMonthSpendPaise;
      final pct = ((diff.abs() / lastMonthSpendPaise) * 100).round();
      if (diff > 0) {
        comparisonStr = ', $pct% more than last month';
      } else if (diff < 0) {
        comparisonStr = ', $pct% less than last month';
      } else {
        comparisonStr = ', identical to last month';
      }
    }

    String topCategoryStr = '';
    if (topCategory != null && topCategoryPaise > 0) {
      topCategoryStr = ' ${topCategory!.label} was your largest category.';
    }

    final recapSentence = thisMonthSpendPaise > 0
        ? 'You spent $spendStr this month$comparisonStr.$topCategoryStr'
        : 'No personal spending logged this month yet.';

    return GlassSurface(
      level: GlassLevel.level1,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: theme.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month in Review',
                      style: AppTypography.bodySemiBold.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Based on expenses you\'ve logged',
                      style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            recapSentence,
            style: AppTypography.body.copyWith(
              color: theme.ink,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
