import 'widgets/insights_web_view.dart';
import '../../../core/profile/experience_mode.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/category_palette.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

enum InsightPeriod { thisMonth, lastMonth, threeMonths, sixMonths, year }

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightPeriod _period = InsightPeriod.thisMonth;
  ExpenseCategory? _selectedCategory;

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
    final repo = ref.watch(appRepositoryProvider);
    final currentUserId = repo.currentUserId;
    final allExpenses = ref.watch(allExpensesProvider);
    final allSettlements = ref.watch(allSettlementsProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final overall = ref.watch(userOverallBalanceProvider);

    final now = DateTime.now();
    final (start, end, prevStart, prevEnd) = _getDateRanges(now);

    // Current period active expenses
    final currentExpenses = allExpenses.where((e) =>
      !e.isDeleted && e.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
      e.date.isBefore(end.add(const Duration(seconds: 1)))
    ).toList();

    // Previous period active expenses
    final prevExpenses = allExpenses.where((e) =>
      !e.isDeleted && e.date.isAfter(prevStart.subtract(const Duration(seconds: 1))) &&
      e.date.isBefore(prevEnd.add(const Duration(seconds: 1)))
    ).toList();

    // Current period settlements
    final currentSettlements = allSettlements.where((s) =>
      !s.isDeleted && s.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
      s.date.isBefore(end.add(const Duration(seconds: 1)))
    ).toList();

    // Compute YOUR SPENDING (your share only)
    int totalYourSpend = 0;
    int groupSpend = 0;
    int personalSpend = 0;
    final Map<ExpenseCategory, int> categorySpend = {
      for (final c in ExpenseCategory.values) c: 0,
    };
    final Map<String, int> groupShareMap = {};
    final Map<int, int> weekdaySpend = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    Expense? largestExpense;
    int largestUserShare = 0;

    for (final exp in currentExpenses) {
      final userShare = exp.computedShares[currentUserId] ?? 0;
      if (userShare <= 0) continue;

      totalYourSpend += userShare;
      categorySpend[exp.category] = (categorySpend[exp.category] ?? 0) + userShare;
      groupShareMap[exp.groupId] = (groupShareMap[exp.groupId] ?? 0) + userShare;
      weekdaySpend[exp.date.weekday] = (weekdaySpend[exp.date.weekday] ?? 0) + userShare;

      if (userShare > largestUserShare) {
        largestUserShare = userShare;
        largestExpense = exp;
      }

      if (exp.groupId == 'group_personal') {
        personalSpend += userShare;
      } else {
        groupSpend += userShare;
      }
    }

    // Previous period spend for % comparison
    int prevYourSpend = 0;
    for (final exp in prevExpenses) {
      final share = exp.computedShares[currentUserId] ?? 0;
      prevYourSpend += share;
    }

    final double changePercent = prevYourSpend > 0
        ? ((totalYourSpend - prevYourSpend) / prevYourSpend) * 100.0
        : 0.0;

    // Settled this period (involving current user)
    int settledThisPeriod = 0;
    for (final s in currentSettlements) {
      if (s.from == currentUserId || s.to == currentUserId) {
        settledThisPeriod += s.amount;
      }
    }

    // Habits data
    int maxWeekday = 1;
    int maxWeekdaySpend = 0;
    weekdaySpend.forEach((day, amount) {
      if (amount > maxWeekdaySpend) {
        maxWeekdaySpend = amount;
        maxWeekday = day;
      }
    });
    const weekdayNames = ['', 'Mondays', 'Tuesdays', 'Wednesdays', 'Thursdays', 'Fridays', 'Saturdays', 'Sundays'];
    final highestSpendDayName = maxWeekdaySpend > 0 ? weekdayNames[maxWeekday] : 'N/A';

    final daysInPeriod = math.max(1, end.difference(start).inDays);
    final avgPerDay = totalYourSpend ~/ daysInPeriod;

    // Active category entries sorted descending
    final activeCategories = categorySpend.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final effective = ref.watch(effectiveExperienceProvider);
    if (effective == EffectiveExperience.web) {
      return const InsightsWebView();
    }

    return ScreenScaffold(
      header: ScreenHeader(
        title: 'Insights',
        subtitle: Text(
          'Your spending and debt analytics',
          style: AppTypography.caption.copyWith(color: theme.muted),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Period Selector
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
              const SizedBox(height: 20),

          if (currentExpenses.isEmpty || totalYourSpend == 0) ...[
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                title: 'No spending in this period',
                subtitle: 'Log expenses in groups or personal space to see your share breakdown here.',
              ),
            ),
          ] else ...[
            // 2. Debts block: "Settled this month" vs "Still owed", mini net trend
            SectionCard(
              title: 'DEBTS & SETTLEMENTS',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settled in period',
                              style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaise(settledThisPeriod),
                              style: AppTypography.moneyMedium.copyWith(
                                color: theme.textEmerald,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 36, color: theme.hairline),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Net still owed',
                              style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatPaise(overall.netBalance.abs()),
                              style: AppTypography.moneyMedium.copyWith(
                                color: overall.netBalance >= 0 ? theme.ink : theme.textCoral,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. "Your spending" hero card: total for period, % vs previous period, "Spent in groups ₹A · Personal ₹B", horizontal bar
            SectionCard(
              title: 'YOUR SPENDING',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        CurrencyFormatter.formatPaise(totalYourSpend),
                        style: AppTypography.moneyHero.copyWith(
                          color: theme.ink,
                          fontSize: 34,
                        ),
                      ),
                      if (prevYourSpend > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              changePercent >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              size: 14,
                              color: changePercent > 0 ? theme.textCoral : theme.textEmerald,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${changePercent.abs().toStringAsFixed(1)}% vs prev',
                              style: AppTypography.caption.copyWith(
                                color: changePercent > 0 ? theme.textCoral : theme.textEmerald,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Spent in groups ${CurrencyFormatter.formatPaise(groupSpend)} · Personal ${CurrencyFormatter.formatPaise(personalSpend)}',
                    style: AppTypography.caption.copyWith(
                      color: theme.muted,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Horizontal bar of group vs personal
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          if (totalYourSpend > 0) ...[
                            Flexible(
                              flex: math.max(1, groupSpend),
                              child: Container(color: theme.navy),
                            ),
                            const SizedBox(width: 2),
                            Flexible(
                              flex: math.max(1, personalSpend),
                              child: Container(color: theme.accent),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Category breakdown: crisp donut chart + list below sorted descending
            SectionCard(
              title: 'CATEGORY BREAKDOWN',
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(160, 160),
                        painter: _CategoryDonutPainter(
                          categorySpend: categorySpend,
                          totalSpend: totalYourSpend,
                          theme: theme,
                          selectedCategory: _selectedCategory,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCategory != null
                                    ? _selectedCategory!.displayName
                                    : 'Your Share',
                                style: AppTypography.caption.copyWith(
                                  color: theme.muted,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                CurrencyFormatter.formatPaise(
                                  _selectedCategory != null
                                      ? (categorySpend[_selectedCategory] ?? 0)
                                      : totalYourSpend,
                                ),
                                style: AppTypography.moneyMedium.copyWith(
                                  color: theme.ink,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Category List
                  for (final entry in activeCategories) ...[
                    InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedCategory = _selectedCategory == entry.key ? null : entry.key;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedCategory == entry.key
                              ? theme.surfaceSolid
                              : theme.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final catColors = CategoryPalette.getColors(entry.key, isDark: theme.isDark);
                                return Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: catColors.tile,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(entry.key),
                                    color: catColors.icon,
                                    size: 18,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.key.displayName,
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: theme.ink,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatPaise(entry.value),
                                  style: AppTypography.bodySemiBold.copyWith(
                                    color: theme.ink,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${((entry.value / totalYourSpend) * 100).toStringAsFixed(1)}%',
                                  style: AppTypography.caption.copyWith(
                                    color: theme.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: 1, color: theme.hairline),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. "By group and Personal": list of groups + Personal with your share and percentage bar
            SectionCard(
              title: 'BY GROUP AND PERSONAL',
              child: Column(
                children: [
                  for (final group in allGroups) ...[
                    if ((groupShareMap[group.id] ?? 0) > 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  group.isPersonal ? 'Personal' : group.name,
                                  style: AppTypography.bodySemiBold.copyWith(
                                    color: theme.ink,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.formatPaise(groupShareMap[group.id] ?? 0),
                                  style: AppTypography.bodySemiBold.copyWith(
                                    color: theme.ink,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: totalYourSpend > 0
                                    ? (groupShareMap[group.id] ?? 0) / totalYourSpend
                                    : 0,
                                backgroundColor: theme.hairline,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  group.isPersonal ? theme.accent : theme.navy,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 6. "Habits": simple data-derived facts
            SectionCard(
              title: 'HABITS & HIGHLIGHTS',
              child: Column(
                children: [
                  _buildHabitRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Highest spend day',
                    value: highestSpendDayName,
                    theme: theme,
                  ),
                  Divider(height: 1, color: theme.hairline),
                  if (largestExpense != null) ...[
                    _buildHabitRow(
                      icon: Icons.star_rounded,
                      label: 'Largest expense',
                      value: '${largestExpense.description} (${CurrencyFormatter.formatPaise(largestUserShare)})',
                      theme: theme,
                    ),
                    Divider(height: 1, color: theme.hairline),
                  ],
                  _buildHabitRow(
                    icon: Icons.speed_rounded,
                    label: 'Average per day',
                    value: CurrencyFormatter.formatPaise(avgPerDay),
                    theme: theme,
                  ),
                ],
              ),
            ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodChip(String label, InsightPeriod p, SettlivThemeExtension theme) {
    final isSelected = _period == p;
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _period = p;
            _selectedCategory = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? (theme.isDark ? theme.raised : theme.navy) : theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.hairline),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? (theme.isDark ? theme.ink : theme.white) : theme.muted,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitRow({
    required IconData icon,
    required String label,
    required String value,
    required SettlivThemeExtension theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.muted),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySemiBold.copyWith(color: theme.ink, fontSize: 13),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.rent:
        return Icons.home_rounded;
      case ExpenseCategory.travel:
        return Icons.directions_car_rounded;
      case ExpenseCategory.stay:
        return Icons.hotel_rounded;
      case ExpenseCategory.groceries:
        return Icons.shopping_basket_rounded;
      case ExpenseCategory.bills:
        return Icons.bolt_rounded;
      case ExpenseCategory.fun:
        return Icons.movie_rounded;
      case ExpenseCategory.other:
        return Icons.more_horiz_rounded;
    }
  }
}

class _CategoryDonutPainter extends CustomPainter {
  final Map<ExpenseCategory, int> categorySpend;
  final int totalSpend;
  final SettlivThemeExtension theme;
  final ExpenseCategory? selectedCategory;

  const _CategoryDonutPainter({
    required this.categorySpend,
    required this.totalSpend,
    required this.theme,
    required this.selectedCategory,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSpend <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 20.0;

    double startAngle = -math.pi / 2;

    categorySpend.forEach((category, amount) {
      if (amount <= 0) return;

      final sweepAngle = (amount / totalSpend) * 2 * math.pi;
      final isSelected = selectedCategory == null || selectedCategory == category;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth : strokeWidth - 4
        ..color = _getCatColor(category, theme).withValues(alpha: isSelected ? 1.0 : 0.4);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.04, // small gap between slices
        false,
        paint,
      );

      startAngle += sweepAngle;
    });
  }

  Color _getCatColor(ExpenseCategory category, SettlivThemeExtension theme) {
    return CategoryPalette.getColors(category, isDark: theme.isDark).base;
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) {
    return oldDelegate.totalSpend != totalSpend ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.theme.isDark != theme.isDark;
  }
}
