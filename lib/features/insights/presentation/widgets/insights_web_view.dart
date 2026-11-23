import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/layout/adaptive_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/expense.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../insights_screen.dart';
import 'month_recap_card.dart';
import 'spending_calendar.dart';

class InsightsWebView extends ConsumerStatefulWidget {
  const InsightsWebView({super.key});

  @override
  ConsumerState<InsightsWebView> createState() => _InsightsWebViewState();
}

class _InsightsWebViewState extends ConsumerState<InsightsWebView> {
  InsightPeriod _period = InsightPeriod.thisMonth;

  (DateTime start, DateTime end, DateTime prevStart, DateTime prevEnd) _getDateRanges(DateTime now) {
    switch (_period) {
      case InsightPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        final prevStart = DateTime(now.year, now.month - 1, 1);
        final prevEnd = DateTime(now.year, now.month, 0, 23, 59, 59);
        return (start, end, prevStart, prevEnd);

      case InsightPeriod.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0, 23, 59, 59);
        final prevStart = DateTime(now.year, now.month - 2, 1);
        final prevEnd = DateTime(now.year, now.month - 1, 0, 23, 59, 59);
        return (start, end, prevStart, prevEnd);

      case InsightPeriod.threeMonths:
        final start = DateTime(now.year, now.month - 3, now.day);
        final end = now;
        final prevStart = DateTime(now.year, now.month - 6, now.day);
        final prevEnd = start;
        return (start, end, prevStart, prevEnd);

      case InsightPeriod.sixMonths:
        final start = DateTime(now.year, now.month - 6, now.day);
        final end = now;
        final prevStart = DateTime(now.year, now.month - 12, now.day);
        final prevEnd = start;
        return (start, end, prevStart, prevEnd);

      case InsightPeriod.year:
        final start = DateTime(now.year - 1, now.month, now.day);
        final end = now;
        final prevStart = DateTime(now.year - 2, now.month, now.day);
        final prevEnd = start;
        return (start, end, prevStart, prevEnd);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final layout = AdaptiveLayout.of(context);
    final isCompact = layout == LayoutClass.compact;

    final repo = ref.watch(appRepositoryProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final allSettlements = ref.watch(allSettlementsProvider);
    final currentUserId = repo.currentUserId;
    final now = DateTime.now();

    final (start, end, prevStart, prevEnd) = _getDateRanges(now);

    // Current period expenses
    final currentExpenses = allExpenses.where((e) {
      if (e.isDeleted) return false;
      return e.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(end.add(const Duration(seconds: 1)));
    }).toList();

    // Previous period expenses
    final prevExpenses = allExpenses.where((e) {
      if (e.isDeleted) return false;
      return e.date.isAfter(prevStart.subtract(const Duration(seconds: 1))) &&
          e.date.isBefore(prevEnd.add(const Duration(seconds: 1)));
    }).toList();

    int totalYourSpend = 0;
    final Map<ExpenseCategory, int> categorySpend = {
      for (final cat in ExpenseCategory.values) cat: 0,
    };
    final Map<int, int> weekdaySpend = {for (int i = 1; i <= 7; i++) i: 0};

    for (final exp in currentExpenses) {
      final yourShare = exp.shares[currentUserId] ?? 0;
      totalYourSpend += yourShare;
      categorySpend[exp.category] = (categorySpend[exp.category] ?? 0) + yourShare;
      final weekday = exp.date.weekday;
      weekdaySpend[weekday] = (weekdaySpend[weekday] ?? 0) + yourShare;
    }

    int prevTotalSpend = 0;
    for (final exp in prevExpenses) {
      prevTotalSpend += exp.shares[currentUserId] ?? 0;
    }

    final double spendChangePercent = prevTotalSpend > 0
        ? ((totalYourSpend - prevTotalSpend) / prevTotalSpend) * 100.0
        : 0.0;

    int settledThisPeriod = 0;
    for (final s in allSettlements) {
      if (s.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
          s.date.isBefore(end.add(const Duration(seconds: 1)))) {
        if (s.from == currentUserId || s.to == currentUserId) {
          settledThisPeriod += s.amount;
        }
      }
    }

    final activeCategories = categorySpend.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final daysInPeriod = math.max(1, end.difference(start).inDays);
    final avgPerDay = totalYourSpend ~/ daysInPeriod;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 32,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Controls: Period selector + Budgets Link
              _buildTopControls(context, theme, isCompact: isCompact),
              const SizedBox(height: 24),

              if (currentExpenses.isEmpty || totalYourSpend == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: EmptyState(
                    title: 'No spending in this period',
                    subtitle: 'Log expenses in groups or personal space to see your share breakdown here.',
                  ),
                )
              else if (isCompact) ...[
                // Compact Web: Stacked
                MonthRecapCard(
                  expenses: allExpenses,
                  currentUserId: currentUserId,
                  now: now,
                ),
                const SizedBox(height: 16),
                _buildSpendSummaryCard(context, theme, totalYourSpend, prevTotalSpend, spendChangePercent),
                const SizedBox(height: 16),
                _buildDebtsSettlementsCard(context, theme, settledThisPeriod),
                const SizedBox(height: 16),
                _buildCategoryCard(context, theme, activeCategories, totalYourSpend),
                const SizedBox(height: 16),
                _buildHabitsCard(context, theme, avgPerDay, weekdaySpend),
                const SizedBox(height: 16),
                SpendingCalendar(
                  expenses: allExpenses,
                  currentUserId: currentUserId,
                  initialDate: now,
                ),
              ] else ...[
                // Expanded / Medium: Bento Grid
                MonthRecapCard(
                  expenses: allExpenses,
                  currentUserId: currentUserId,
                  now: now,
                ),
                const SizedBox(height: 20),
                // Row 1: Spend summary (span 7) + Debts & settlements (span 5)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildSpendSummaryCard(context, theme, totalYourSpend, prevTotalSpend, spendChangePercent),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _buildDebtsSettlementsCard(context, theme, settledThisPeriod),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Row 2: Category breakdown (span 6) + Habits & Daily average (span 6)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildCategoryCard(context, theme, activeCategories, totalYourSpend),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 6,
                      child: _buildHabitsCard(context, theme, avgPerDay, weekdaySpend),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Row 3: Spending Calendar
                SpendingCalendar(
                  expenses: allExpenses,
                  currentUserId: currentUserId,
                  initialDate: now,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(BuildContext context, SettlivThemeExtension theme, {bool isCompact = false}) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPeriodChip('This month', InsightPeriod.thisMonth, theme),
                const SizedBox(width: 8),
                _buildPeriodChip('Last month', InsightPeriod.lastMonth, theme),
                const SizedBox(width: 8),
                _buildPeriodChip('3M', InsightPeriod.threeMonths, theme),
                const SizedBox(width: 8),
                _buildPeriodChip('6M', InsightPeriod.sixMonths, theme),
                const SizedBox(width: 8),
                _buildPeriodChip('Year', InsightPeriod.year, theme),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => context.go('/insights/budgets'),
            icon: Icon(Icons.account_balance_wallet_outlined, size: 18, color: theme.ink),
            label: Text('Budgets & Limits', style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.surface,
              elevation: 0,
              side: BorderSide(color: theme.hairline),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Period chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPeriodChip('This month', InsightPeriod.thisMonth, theme),
              const SizedBox(width: 8),
              _buildPeriodChip('Last month', InsightPeriod.lastMonth, theme),
              const SizedBox(width: 8),
              _buildPeriodChip('3M', InsightPeriod.threeMonths, theme),
              const SizedBox(width: 8),
              _buildPeriodChip('6M', InsightPeriod.sixMonths, theme),
              const SizedBox(width: 8),
              _buildPeriodChip('Year', InsightPeriod.year, theme),
            ],
          ),
        ),
        // Budgets button
        ElevatedButton.icon(
          onPressed: () => context.go('/insights/budgets'),
          icon: Icon(Icons.account_balance_wallet_outlined, size: 18, color: theme.ink),
          label: Text('Budgets & Limits', style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.surface,
            elevation: 0,
            side: BorderSide(color: theme.hairline),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, InsightPeriod p, SettlivThemeExtension theme) {
    final isSelected = _period == p;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _period = p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryButtonBg : theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? theme.primaryButtonBg : theme.hairline),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? theme.primaryButtonText : theme.ink,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSpendSummaryCard(
    BuildContext context,
    SettlivThemeExtension theme,
    int totalSpend,
    int prevSpend,
    double changePercent,
  ) {
    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('TOTAL SPEND (YOUR SHARE)', style: AppTypography.eyebrow.copyWith(color: theme.muted)),
              if (prevSpend > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      changePercent >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                      size: 14,
                      color: changePercent > 0 ? theme.coral : theme.emerald,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${changePercent.abs().toStringAsFixed(0)}% vs previous',
                      style: AppTypography.caption.copyWith(
                        color: changePercent > 0 ? theme.coral : theme.emerald,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            CurrencyFormatter.formatPaise(totalSpend),
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: theme.ink,
            ),
          ),
          const SizedBox(height: 20),
          // Interactive progress comparison bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: prevSpend > 0 ? (totalSpend / (prevSpend * 1.5)).clamp(0.05, 1.0) : 0.6,
              backgroundColor: theme.hairline,
              color: theme.accent,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text('Reconciled with Records', style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11)),
              if (prevSpend > 0)
                Text('Prev: ${CurrencyFormatter.formatPaise(prevSpend)}', style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsSettlementsCard(BuildContext context, SettlivThemeExtension theme, int settledPaise) {
    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DEBTS & SETTLEMENTS', style: AppTypography.eyebrow.copyWith(color: theme.muted)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.check_circle_rounded, color: theme.emerald, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settled this period', style: AppTypography.caption.copyWith(color: theme.muted)),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.formatPaise(settledPaise),
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: theme.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () => context.push('/balances'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'View outstanding balances',
                    style: AppTypography.caption.copyWith(color: theme.accent, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 14, color: theme.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    SettlivThemeExtension theme,
    List<MapEntry<ExpenseCategory, int>> activeCategories,
    int totalSpend,
  ) {
    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BY CATEGORY', style: AppTypography.eyebrow.copyWith(color: theme.muted)),
          const SizedBox(height: 18),
          ...activeCategories.map((entry) {
            final cat = entry.key;
            final amount = entry.value;
            final percent = totalSpend > 0 ? (amount / totalSpend) * 100.0 : 0.0;
            final colors = CategoryPalette.getColors(cat, isDark: theme.isDark);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: colors.tile,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(CategoryPalette.getIcon(cat), size: 15, color: colors.icon),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(cat.displayName, style: AppTypography.bodySemiBold.copyWith(color: theme.ink)),
                      ),
                      Text(
                        '${percent.toStringAsFixed(0)}% · ${CurrencyFormatter.formatPaise(amount)}',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontWeight: FontWeight.w700,
                          color: theme.ink,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: percent / 100.0,
                      backgroundColor: theme.hairline,
                      color: colors.icon,
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHabitsCard(
    BuildContext context,
    SettlivThemeExtension theme,
    int avgPerDay,
    Map<int, int> weekdaySpend,
  ) {
    int maxWeekday = 1;
    int maxWeekdaySpend = 0;
    weekdaySpend.forEach((day, amount) {
      if (amount > maxWeekdaySpend) {
        maxWeekdaySpend = amount;
        maxWeekday = day;
      }
    });
    const weekdayNames = ['', 'Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'];
    final highestSpendDay = maxWeekdaySpend > 0 ? weekdayNames[maxWeekday] : 'N/A';

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SPENDING HABITS', style: AppTypography.eyebrow.copyWith(color: theme.muted)),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Average', style: AppTypography.caption.copyWith(color: theme.muted)),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.formatPaise(avgPerDay),
                      style: TextStyle(fontFamily: AppTypography.fontFamily, fontSize: 20, fontWeight: FontWeight.w700, color: theme.ink),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Peak Spending Day', style: AppTypography.caption.copyWith(color: theme.muted)),
                    const SizedBox(height: 4),
                    Text(
                      highestSpendDay,
                      style: TextStyle(fontFamily: AppTypography.fontBrand, fontSize: 18, fontWeight: FontWeight.w800, color: theme.ink),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Weekday bars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (idx) {
              final dayIndex = idx + 1;
              const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final amount = weekdaySpend[dayIndex] ?? 0;
              final maxAmount = maxWeekdaySpend > 0 ? maxWeekdaySpend : 1;
              final h = (amount / maxAmount) * 50.0;

              return Column(
                children: [
                  Container(
                    width: 18,
                    height: math.max(6.0, h),
                    decoration: BoxDecoration(
                      color: dayIndex == maxWeekday && maxWeekdaySpend > 0 ? theme.accent : theme.accent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(days[idx], style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 10)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
