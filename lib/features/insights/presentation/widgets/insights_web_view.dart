import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/layout/adaptive_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/expense.dart';
import '../../../../data/models/group.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../insights_screen.dart';
import 'spending_calendar.dart';

class InsightsWebView extends ConsumerStatefulWidget {
  const InsightsWebView({super.key});

  /// Formats the spend delta line for Insights.
  ///
  /// When [prevSpendPaise] is under ₹5,000 (500,000 paise) or the relative
  /// change exceeds 300%, returns an absolute rupee difference and never a
  /// percentage.
  static String formatSpendDelta(
    int totalSpendPaise,
    int prevSpendPaise, {
    String comparisonLabel = 'last month',
  }) {
    if (prevSpendPaise <= 0) {
      return 'No spending logged in $comparisonLabel';
    }
    final diff = totalSpendPaise - prevSpendPaise;
    if (diff == 0) {
      return 'Same as $comparisonLabel';
    }
    final absDiff = diff.abs();
    final pct = (absDiff / prevSpendPaise) * 100.0;
    final direction = diff > 0 ? 'more' : 'less';

    if (prevSpendPaise < 500000 || pct > 300.0) {
      return '${CurrencyFormatter.formatPaise(absDiff, absolute: true)} $direction than $comparisonLabel';
    }
    return '${pct.toStringAsFixed(0)}% $direction than $comparisonLabel';
  }

  @override
  ConsumerState<InsightsWebView> createState() => _InsightsWebViewState();
}

class _InsightsWebViewState extends ConsumerState<InsightsWebView> {
  InsightPeriod _period = InsightPeriod.thisMonth;

  (DateTime start, DateTime end, DateTime prevStart, DateTime prevEnd)
      _getDateRanges(DateTime now) {
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

  String get _comparisonLabel =>
      _period == InsightPeriod.thisMonth ? 'last month' : 'previous period';

  String get _currentRowLabel => switch (_period) {
        InsightPeriod.thisMonth => 'This month',
        InsightPeriod.lastMonth => 'Last month',
        _ => 'This period',
      };

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final layout = AdaptiveLayout.of(context);
    final isCompact = layout == LayoutClass.compact;

    final repo = ref.watch(appRepositoryProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final allSettlements = ref.watch(allSettlementsProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final currentUserId = repo.currentUserId;
    final now = DateTime.now();

    final (start, end, prevStart, prevEnd) = _getDateRanges(now);

    final currentExpenses = allExpenses.where((e) {
      if (e.isDeleted) return false;
      return !e.date.isBefore(start) && !e.date.isAfter(end);
    }).toList();

    final prevExpenses = allExpenses.where((e) {
      if (e.isDeleted) return false;
      return !e.date.isBefore(prevStart) && !e.date.isAfter(prevEnd);
    }).toList();

    int totalYourSpend = 0;
    final Map<ExpenseCategory, int> categorySpend = {
      for (final cat in ExpenseCategory.values) cat: 0,
    };
    final Map<int, int> weekdaySpend = {for (int i = 1; i <= 7; i++) i: 0};
    final Map<DateTime, int> dailySpend = {};
    final Map<String, int> groupSpend = {};

    for (final exp in currentExpenses) {
      final yourShare =
          exp.computedShares[currentUserId] ?? exp.shares[currentUserId] ?? 0;
      totalYourSpend += yourShare;
      categorySpend[exp.category] =
          (categorySpend[exp.category] ?? 0) + yourShare;
      weekdaySpend[exp.date.weekday] =
          (weekdaySpend[exp.date.weekday] ?? 0) + yourShare;
      final dayKey = DateTime(exp.date.year, exp.date.month, exp.date.day);
      dailySpend[dayKey] = (dailySpend[dayKey] ?? 0) + yourShare;
      if (yourShare > 0) {
        groupSpend[exp.groupId] = (groupSpend[exp.groupId] ?? 0) + yourShare;
      }
    }

    int prevTotalSpend = 0;
    for (final exp in prevExpenses) {
      prevTotalSpend +=
          exp.computedShares[currentUserId] ?? exp.shares[currentUserId] ?? 0;
    }

    int settledThisPeriod = 0;
    for (final s in allSettlements) {
      if (!s.date.isBefore(start) && !s.date.isAfter(end)) {
        if (s.from == currentUserId || s.to == currentUserId) {
          settledThisPeriod += s.amount;
        }
      }
    }

    final activeCategories =
        categorySpend.entries.where((e) => e.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final groupMap = {for (final g in allGroups) g.id: g};
    final activeGroupEntries = groupSpend.entries
        .where((e) => e.value > 0 && groupMap.containsKey(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    DateTime? busiestDay;
    int busiestDaySpend = 0;
    dailySpend.forEach((day, amount) {
      if (amount > busiestDaySpend) {
        busiestDaySpend = amount;
        busiestDay = day;
      }
    });

    final daysInPeriod = math.max(1, end.difference(start).inDays + 1);
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
              _buildTopControls(context, theme, isCompact: isCompact),
              const SizedBox(height: 24),
              if (currentExpenses.isEmpty || totalYourSpend == 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: EmptyState(
                    title: 'No spending in this period',
                    subtitle:
                        'Log expenses in groups or personal space to see your share breakdown here.',
                  ),
                )
              else if (isCompact) ...[
                _buildSpendSummaryCard(
                  context,
                  theme,
                  totalYourSpend,
                  prevTotalSpend,
                ),
                const SizedBox(height: 24),
                _buildHabitsCard(context, theme, avgPerDay, weekdaySpend),
                const SizedBox(height: 24),
                _buildMonthReviewCard(
                  context,
                  theme,
                  topCategory: activeCategories.isNotEmpty
                      ? activeCategories.first.key
                      : null,
                  busiestDay: busiestDay,
                ),
                const SizedBox(height: 24),
                _buildDebtsSettlementsCard(context, theme, settledThisPeriod),
                const SizedBox(height: 24),
                _buildCategoryCard(
                  context,
                  theme,
                  activeCategories,
                  totalYourSpend,
                ),
                const SizedBox(height: 24),
                SpendingCalendar(
                  expenses: allExpenses,
                  currentUserId: currentUserId,
                  initialDate: now,
                  compactCells: true,
                  padding: const EdgeInsets.all(24),
                  uppercaseHeader: true,
                ),
                const SizedBox(height: 24),
                _buildByGroupCard(
                  context,
                  theme,
                  activeGroupEntries,
                  groupMap,
                  totalYourSpend,
                ),
              ] else ...[
                // Row 1: Total spend (7 cols) | Spending habits (5 cols)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildSpendSummaryCard(
                          context,
                          theme,
                          totalYourSpend,
                          prevTotalSpend,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: _buildHabitsCard(
                          context,
                          theme,
                          avgPerDay,
                          weekdaySpend,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Row 2: Month in Review (7 cols) | Debts and settlements (5 cols)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildMonthReviewCard(
                          context,
                          theme,
                          topCategory: activeCategories.isNotEmpty
                              ? activeCategories.first.key
                              : null,
                          busiestDay: busiestDay,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: _buildDebtsSettlementsCard(
                          context,
                          theme,
                          settledThisPeriod,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Row 3: By category (7 cols) | Spending calendar + By group (5 cols)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildCategoryCard(
                          context,
                          theme,
                          activeCategories,
                          totalYourSpend,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SpendingCalendar(
                              expenses: allExpenses,
                              currentUserId: currentUserId,
                              initialDate: now,
                              compactCells: true,
                              padding: const EdgeInsets.all(24),
                              uppercaseHeader: true,
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: _buildByGroupCard(
                                context,
                                theme,
                                activeGroupEntries,
                                groupMap,
                                totalYourSpend,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(
    BuildContext context,
    SettlivThemeExtension theme, {
    bool isCompact = false,
  }) {
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
            icon: Icon(
              Icons.account_balance_wallet_outlined,
              size: 18,
              color: theme.ink,
            ),
            label: Text(
              'Budgets & Limits',
              style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.surface,
              elevation: 0,
              side: BorderSide(color: theme.hairline),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        ElevatedButton.icon(
          onPressed: () => context.go('/insights/budgets'),
          icon: Icon(
            Icons.account_balance_wallet_outlined,
            size: 18,
            color: theme.ink,
          ),
          label: Text(
            'Budgets & Limits',
            style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.surface,
            elevation: 0,
            side: BorderSide(color: theme.hairline),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(
    String label,
    InsightPeriod p,
    SettlivThemeExtension theme,
  ) {
    final isSelected = _period == p;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _period = p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryButtonBg : theme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.primaryButtonBg : theme.hairline,
          ),
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
  ) {
    final diff = totalSpend - prevSpend;
    final deltaText = InsightsWebView.formatSpendDelta(
      totalSpend,
      prevSpend,
      comparisonLabel: _comparisonLabel,
    );
    final deltaColor = prevSpend <= 0 || diff == 0
        ? theme.muted
        : (diff > 0 ? theme.textCoral : theme.textEmerald);
    final maxBarValue = math.max(1, math.max(totalSpend, prevSpend));

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL SPEND (YOUR SHARE)',
                style: AppTypography.eyebrow.copyWith(color: theme.muted),
              ),
              const SizedBox(height: 14),
              Text(
                CurrencyFormatter.formatPaise(totalSpend),
                style: TextStyle(
                  fontFamily: AppTypography.fontDisplay,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: theme.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (prevSpend > 0 && diff != 0) ...[
                    Icon(
                      diff > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 14,
                      color: deltaColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      deltaText,
                      style: AppTypography.caption.copyWith(
                        color: deltaColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Two-row proportional comparison
          Column(
            children: [
              _buildComparisonRow(
                label: _currentRowLabel,
                amountPaise: totalSpend,
                fraction: totalSpend / maxBarValue,
                barColor: theme.accent,
                theme: theme,
              ),
              const SizedBox(height: 12),
              _buildComparisonRow(
                label: _period == InsightPeriod.thisMonth
                    ? 'Last month'
                    : 'Previous',
                amountPaise: prevSpend,
                fraction: prevSpend / maxBarValue,
                barColor: theme.muted.withValues(alpha: 0.4),
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required int amountPaise,
    required double fraction,
    required Color barColor,
    required SettlivThemeExtension theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              CurrencyFormatter.formatPaise(amountPaise),
              style: AppTypography.caption.copyWith(
                color: theme.ink,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            backgroundColor: theme.hairline,
            color: barColor,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthReviewCard(
    BuildContext context,
    SettlivThemeExtension theme, {
    required ExpenseCategory? topCategory,
    required DateTime? busiestDay,
  }) {
    final String recapText;
    if (topCategory == null && busiestDay == null) {
      recapText = 'No personal spending logged in this period yet.';
    } else {
      final catName = topCategory?.label ?? 'Other';
      final dayStr =
          busiestDay != null ? DateFormat('d MMM').format(busiestDay) : 'today';
      recapText =
          '$catName was your largest category, and $dayStr was your busiest day.';
    }

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MONTH IN REVIEW',
                style: AppTypography.eyebrow.copyWith(color: theme.muted),
              ),
              const SizedBox(height: 14),
              Text(
                recapText,
                style: AppTypography.body.copyWith(
                  color: theme.ink,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Based on expenses you've logged",
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsSettlementsCard(
    BuildContext context,
    SettlivThemeExtension theme,
    int settledPaise,
  ) {
    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DEBTS & SETTLEMENTS',
                style: AppTypography.eyebrow.copyWith(color: theme.muted),
              ),
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
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: theme.emerald,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settled this period',
                          style: AppTypography.caption.copyWith(
                            color: theme.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.formatPaise(settledPaise),
                          style: TextStyle(
                            fontFamily: AppTypography.fontDisplay,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: theme.textEmerald,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => context.push('/balances'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'View outstanding balances',
                    style: AppTypography.caption.copyWith(
                      color: theme.accent,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: theme.accent,
                ),
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
          Text(
            'BY CATEGORY',
            style: AppTypography.eyebrow.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 18),
          ...activeCategories.map((entry) {
            final cat = entry.key;
            final amount = entry.value;
            final percent =
                totalSpend > 0 ? (amount / totalSpend) * 100.0 : 0.0;
            final colors =
                CategoryPalette.getColors(cat, isDark: theme.isDark);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
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
                        child: Icon(
                          CategoryPalette.getIcon(cat),
                          size: 15,
                          color: colors.icon,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cat.displayName,
                          style: AppTypography.bodySemiBold.copyWith(
                            color: theme.ink,
                          ),
                        ),
                      ),
                      Text(
                        '${percent.toStringAsFixed(0)}% · ${CurrencyFormatter.formatPaise(amount)}',
                        style: TextStyle(
                          fontFamily: AppTypography.fontDisplay,
                          fontWeight: FontWeight.w700,
                          color: theme.ink,
                          fontSize: 13,
                          fontFeatures: const [FontFeature.tabularFigures()],
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

  Widget _buildByGroupCard(
    BuildContext context,
    SettlivThemeExtension theme,
    List<MapEntry<String, int>> activeGroupEntries,
    Map<String, Group> groupMap,
    int totalSpend,
  ) {
    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BY GROUP & PERSONAL',
            style: AppTypography.eyebrow.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 16),
          if (activeGroupEntries.isEmpty)
            Text(
              'No group spending in this period.',
              style: AppTypography.caption.copyWith(color: theme.muted),
            )
          else
            ...activeGroupEntries.map((entry) {
              final group = groupMap[entry.key]!;
              final amount = entry.value;
              final percent =
                  totalSpend > 0 ? (amount / totalSpend) * 100.0 : 0.0;
              final label = group.isPersonal ? 'Personal' : group.name;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: AppTypography.bodySemiBold.copyWith(
                              color: theme.ink,
                              fontSize: 13.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${percent.toStringAsFixed(0)}% · ${CurrencyFormatter.formatPaise(amount)}',
                          style: AppTypography.caption.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (percent / 100.0).clamp(0.0, 1.0),
                        backgroundColor: theme.hairline,
                        color: group.isPersonal ? theme.emerald : theme.accent,
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
    const weekdayNames = [
      '',
      'Mondays',
      'Tuesdays',
      'Wednesdays',
      'Thursdays',
      'Fridays',
      'Saturdays',
      'Sundays',
    ];
    final highestSpendDay =
        maxWeekdaySpend > 0 ? weekdayNames[maxWeekday] : 'N/A';

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SPENDING HABITS',
                style: AppTypography.eyebrow.copyWith(color: theme.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily average',
                          style: AppTypography.caption.copyWith(
                            color: theme.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatPaise(avgPerDay),
                          style: TextStyle(
                            fontFamily: AppTypography.fontDisplay,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.ink,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peak day',
                          style: AppTypography.caption.copyWith(
                            color: theme.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          highestSpendDay,
                          style: TextStyle(
                            fontFamily: AppTypography.fontBrand,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: theme.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekday bars in a fixed 120px area with hover tooltips
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (idx) {
                final dayIndex = idx + 1;
                const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                final amount = weekdaySpend[dayIndex] ?? 0;
                final maxAmount = maxWeekdaySpend > 0 ? maxWeekdaySpend : 1;
                final h = (amount / maxAmount) * 88.0;

                return Tooltip(
                  message:
                      '${weekdayNames[dayIndex]}: ${CurrencyFormatter.formatPaise(amount, absolute: true)}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 20,
                        height: math.max(6.0, h),
                        decoration: BoxDecoration(
                          color: dayIndex == maxWeekday && maxWeekdaySpend > 0
                              ? theme.accent
                              : theme.accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        days[idx],
                        style: AppTypography.caption.copyWith(
                          color: theme.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
