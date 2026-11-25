import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../core/widgets/expense_tile.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/expense.dart';

class SpendingCalendar extends StatefulWidget {
  final List<Expense> expenses;
  final String currentUserId;
  final DateTime initialDate;
  final double? maxWidth;
  final bool compactCells;

  const SpendingCalendar({
    super.key,
    required this.expenses,
    required this.currentUserId,
    required this.initialDate,
    this.maxWidth,
    this.compactCells = false,
  });

  @override
  State<SpendingCalendar> createState() => _SpendingCalendarState();
}

class _SpendingCalendarState extends State<SpendingCalendar> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  void _showDayExpensesSheet(BuildContext context, DateTime date, List<Expense> dayExpenses, int totalPaise) {
    final theme = context.settliv;
    final dateStr = '${date.day} ${_monthName(date.month)} ${date.year}';

    AdaptivePresenter.show(
      context: context,
      title: dateStr,
      child: dayExpenses.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Center(
                child: Text(
                  'No expenses logged on this day.',
                  style: AppTypography.caption.copyWith(color: theme.muted),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your share on this day',
                          style: TextStyle(fontSize: 13, color: theme.ink, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(totalPaise),
                          style: TextStyle(fontSize: 15, color: theme.accent, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...dayExpenses.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ExpenseTile(
                        expense: e,
                        currentUserId: widget.currentUserId,
                        showGroupName: true,
                        onTap: () {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    final year = _selectedMonth.year;
    final month = _selectedMonth.month;
    final firstDayOfWeek = DateTime(year, month, 1).weekday; // 1 = Mon, 7 = Sun
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Calculate daily totals and max daily spend
    final dailyTotals = <int, int>{};
    final dailyExpensesMap = <int, List<Expense>>{};

    for (final e in widget.expenses) {
      if (e.isDeleted) continue;
      if (e.date.year == year && e.date.month == month) {
        final day = e.date.day;
        final share = e.computedShares[widget.currentUserId] ?? 0;
        if (share > 0) {
          dailyTotals[day] = (dailyTotals[day] ?? 0) + share;
          dailyExpensesMap.putIfAbsent(day, () => []).add(e);
        }
      }
    }

    int maxDailySpend = 0;
    dailyTotals.forEach((_, amount) {
      if (amount > maxDailySpend) maxDailySpend = amount;
    });

    final isTodayInThisMonth = DateTime.now().year == year && DateTime.now().month == month;
    final today = DateTime.now().day;

    final calendarCard = GlassSurface(
      level: GlassLevel.level1,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Spending Calendar',
                style: AppTypography.bodySemiBold.copyWith(
                  color: theme.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: theme.ink,
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(year, month - 1, 1);
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_monthName(month)} $year',
                    style: AppTypography.caption.copyWith(
                      color: theme.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: theme.ink,
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(year, month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Day headers (Mon - Sun)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((day) => SizedBox(
                      width: 32,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.muted),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42, // 6 weeks
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              mainAxisExtent: widget.compactCells ? 38.0 : null,
            ),
            itemBuilder: (context, index) {
              final dayOffset = index - (firstDayOfWeek - 1);
              final dayNumber = dayOffset + 1;

              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final spend = dailyTotals[dayNumber] ?? 0;
              final isToday = isTodayInThisMonth && dayNumber == today;
              final intensity = maxDailySpend > 0 ? (spend / maxDailySpend).clamp(0.08, 0.85) : 0.0;
              final tooltipMsg = spend > 0
                  ? '$dayNumber ${_monthName(month)}: ${CurrencyFormatter.formatPaise(spend, absolute: true)}'
                  : '$dayNumber ${_monthName(month)}: No spend';

              return Tooltip(
                message: tooltipMsg,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final date = DateTime(year, month, dayNumber);
                    final expenses = dailyExpensesMap[dayNumber] ?? [];
                    _showDayExpensesSheet(context, date, expenses, spend);
                  },
                  child: Container(
                  decoration: BoxDecoration(
                    color: spend > 0 ? theme.accent.withValues(alpha: intensity) : theme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isToday
                          ? theme.accent
                          : spend > 0
                              ? theme.accent.withValues(alpha: 0.3)
                              : theme.hairline,
                      width: isToday ? 1.5 : 0.75,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isToday ? FontWeight.w800 : (spend > 0 ? FontWeight.w600 : FontWeight.w400),
                        color: spend > 0 && intensity > 0.45 ? theme.surface : theme.ink,
                      ),
                    ),
                  ),
                ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: TextStyle(fontSize: 10, color: theme.muted)),
              const SizedBox(width: 4),
              ...[0.1, 0.35, 0.65, 0.85].map(
                (op) => Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: op),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text('More', style: TextStyle(fontSize: 10, color: theme.muted)),
            ],
          ),
        ],
      ),
    );
    if (widget.maxWidth != null) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth!),
        child: calendarCard,
      );
    }
    return calendarCard;
  }
}
