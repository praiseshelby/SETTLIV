import '../../../../core/profile/experience_mode.dart';
import 'day_period_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/layout/adaptive_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_palette.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/name_normalizer.dart';
import '../../../../core/widgets/balance_hero_card.dart';
import '../../../../core/widgets/balance_pill.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/group_cover_art.dart';
import '../../../../data/engine/balance_engine.dart';
import '../../../../data/models/group.dart';
import '../../../../data/models/person.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../../../group_detail/sheets/expense_detail_sheet.dart';
import '../../domain/recent_activity_engine.dart';
import '../../domain/shortcut_engine.dart';
import 'split_calculator_sheet.dart';

class DashboardWebView extends ConsumerStatefulWidget {
  const DashboardWebView({super.key});

  @override
  ConsumerState<DashboardWebView> createState() => _DashboardWebViewState();
}

class _DashboardWebViewState extends ConsumerState<DashboardWebView> {
  List<ShortcutDefinition> _shortcuts = [];

  @override
  void initState() {
    super.initState();
    _loadShortcuts();
  }

  Future<void> _loadShortcuts() async {
    final usages = ShortcutEngine.decayAll({}, DateTime.now());
    final ranked = ShortcutEngine.rankShortcuts(usages);
    if (mounted) {
      setState(() {
        _shortcuts = ranked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final layout = AdaptiveLayout.of(context);
    final isCompact = layout == LayoutClass.compact;

    final repo = ref.watch(appRepositoryProvider);
    final overall = ref.watch(userOverallBalanceProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final sharedGroups = allGroups.where((g) => !g.isPersonal).toList();
    final allExpenses = ref.watch(allExpensesProvider);
    final settlements = ref.watch(allSettlementsProvider);
    final currentUserId = repo.currentUserId;
    final now = DateTime.now();

    // Counterparties
    final peopleOwingUser = <Person>[];
    final peopleUserOwes = <Person>[];
    for (final g in sharedGroups) {
      final summary = repo.getGroupSummary(g.id);
      for (final debt in summary.debts) {
        if (debt.toPersonId == currentUserId) {
          final p = repo.getPerson(debt.fromPersonId);
          if (p != null && !peopleOwingUser.any((item) => item.id == p.id)) {
            peopleOwingUser.add(p);
          }
        } else if (debt.fromPersonId == currentUserId) {
          final p = repo.getPerson(debt.toPersonId);
          if (p != null && !peopleUserOwes.any((item) => item.id == p.id)) {
            peopleUserOwes.add(p);
          }
        }
      }
    }
    final allCounterparties = [...peopleOwingUser, ...peopleUserOwes];

    // This month spend
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

    int thisMonthYourSpend = 0;
    int lastMonthYourSpend = 0;

    for (final exp in allExpenses) {
      if (!exp.isDeleted) {
        final share = exp.shares[currentUserId] ?? 0;
        if (exp.date.isAfter(startOfThisMonth.subtract(const Duration(seconds: 1)))) {
          thisMonthYourSpend += share;
        } else if (exp.date.isAfter(startOfLastMonth.subtract(const Duration(seconds: 1))) &&
            exp.date.isBefore(endOfLastMonth.add(const Duration(seconds: 1)))) {
          lastMonthYourSpend += share;
        }
      }
    }

    final double spendChangePercent = lastMonthYourSpend > 0
        ? ((thisMonthYourSpend - lastMonthYourSpend) / lastMonthYourSpend) * 100.0
        : 0.0;

    // Recent Activity
    final recentResult = RecentActivityEngine.computeRecentActivity(
      expenses: allExpenses,
      settlements: settlements,
      now: now,
    );

    // Recent Groups (sorted by last activity)
    final recentGroups = List<Group>.from(sharedGroups)
      ..sort((a, b) {
        final aLast = repo.getExpensesForGroup(a.id).fold<DateTime>(
              a.createdAt ?? DateTime.now(),
              (max, e) => e.date.isAfter(max) ? e.date : max,
            );
        final bLast = repo.getExpensesForGroup(b.id).fold<DateTime>(
              b.createdAt ?? DateTime.now(),
              (max, e) => e.date.isAfter(max) ? e.date : max,
            );
        return bLast.compareTo(aLast);
      });
    final top2Groups = recentGroups.take(2).toList();

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
              // 1. Web Header: large display greeting + date, theme toggle
              _buildHeader(context, theme, now),
              const SizedBox(height: 24),

              // 2. Bento Grid (or single-column on compact)
              if (isCompact) ...[
                // Stacked layout
                _buildHeroCard(context, overall, allCounterparties, isLarge: false),
                const SizedBox(height: 16),
                _buildThisMonthCard(context, theme, thisMonthYourSpend, lastMonthYourSpend, spendChangePercent, isCompact: isCompact),
                const SizedBox(height: 16),
                _buildRecentGroupsCard(context, theme, top2Groups, isCompact: isCompact),
                const SizedBox(height: 16),
                _buildShortcutsCard(context, theme, isCompact: isCompact),
                const SizedBox(height: 16),
                _buildRecentActivitySection(context, theme, recentResult, isCompact: true),
              ] else ...[
                // Row 1: Hero (span 7) + This Month (span 5)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildHeroCard(context, overall, allCounterparties, isLarge: true),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _buildThisMonthCard(context, theme, thisMonthYourSpend, lastMonthYourSpend, spendChangePercent, isCompact: isCompact),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Row 2: Recent Groups (span 7) + Shortcuts (span 5)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _buildRecentGroupsCard(context, theme, top2Groups, isCompact: isCompact),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 5,
                      child: _buildShortcutsCard(context, theme, isCompact: isCompact),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Row 3: Recent Activity (span 12)
                _buildRecentActivitySection(context, theme, recentResult, isCompact: false),
              ],

              const SizedBox(height: 36),
              // Footer compatibility line
              _buildFooter(context, theme),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Header: Large display greeting + date, no icon, no status; theme toggle
  Widget _buildHeader(BuildContext context, SettlivThemeExtension theme, DateTime now) {
    final greeting = getTimeGreeting(now);
    final dateStr = DateFormat('EEEE, d MMMM').format(now);
    final isDark = theme.isDark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontFamily: AppTypography.fontBrand,
                  fontFamilyFallback: AppTypography.brandFallback,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: theme.ink,
                  letterSpacing: -0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: AppTypography.body.copyWith(
                  color: theme.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Theme toggle button
        IconButton(
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          icon: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: theme.ink,
          ),
          onPressed: () {
            ref.read(themeModeProvider.notifier).toggleTheme();
          },
        ),
      ],
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    UserOverallBalance overall,
    List<Person> counterparties, {
    required bool isLarge,
  }) {
    return BalanceHeroCard(
      netPaise: overall.netBalance,
      totalOwedToUserPaise: overall.totalOwedToUser,
      totalUserOwesPaise: overall.totalUserOwes,
      owedFromCount: counterparties.where((p) => overall.netBalance > 0).length,
      owesToCount: counterparties.where((p) => overall.netBalance < 0).length,
      counterparties: counterparties,
      onTap: () => context.push('/balances'),
    );
  }

  Widget _buildThisMonthCard(
    BuildContext context,
    SettlivThemeExtension theme,
    int thisMonthSpend,
    int lastMonthSpend,
    double changePercent,
    {required bool isCompact}) {
    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go('/insights'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'THIS MONTH',
                  style: AppTypography.eyebrow.copyWith(color: theme.muted),
                ),
                Icon(Icons.arrow_forward_rounded, size: 16, color: theme.muted),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              CurrencyFormatter.formatPaise(thisMonthSpend),
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
            ),
            const SizedBox(height: 8),
            if (lastMonthSpend > 0)
              Row(
                children: [
                  Icon(
                    changePercent >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 14,
                    color: changePercent > 0 ? theme.coral : theme.emerald,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${changePercent.abs().toStringAsFixed(0)}% vs last month',
                      style: AppTypography.caption.copyWith(
                        color: changePercent > 0 ? theme.coral : theme.emerald,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else
              Text(
                'First month on Settliv',
                style: AppTypography.caption.copyWith(color: theme.muted),
              ),
            const SizedBox(height: 20),
            // Spend indicator bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: lastMonthSpend > 0
                    ? (thisMonthSpend / (lastMonthSpend * 1.5)).clamp(0.05, 1.0)
                    : 0.5,
                backgroundColor: theme.hairline,
                color: theme.accent,
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentGroupsCard(
    BuildContext context,
    SettlivThemeExtension theme,
    List<Group> groups,
    {required bool isCompact}) {
    final repo = ref.watch(appRepositoryProvider);

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'RECENT GROUPS',
                  style: AppTypography.eyebrow.copyWith(color: theme.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => context.go('/groups'),
                child: Row(
                  children: [
                    Text(
                      'All groups',
                      style: AppTypography.caption.copyWith(
                        color: theme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: theme.accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (groups.isEmpty)
            Text(
              'No groups created yet',
              style: AppTypography.body.copyWith(color: theme.muted),
            )
          else
            ...groups.map((group) {
              final summary = repo.getGroupSummary(group.id);
              final myNet = summary.netBalances[repo.currentUserId] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/group/${group.id}'),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.hairline),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 56,
                            height: 56,
                            child: GroupCoverArt(group: group, height: 56),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.name,
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${group.memberIds.length} members',
                                style: AppTypography.caption.copyWith(color: theme.muted),
                              ),
                            ],
                          ),
                        ),
                        BalancePill(paise: myNet),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildShortcutsCard(BuildContext context, SettlivThemeExtension theme, {required bool isCompact}) {
    final profile = ref.watch(deviceProfileProvider);
    // On desktop, scan receipt shortcut is hidden
    final available = _shortcuts.where((s) {
      if (profile.isDesktop && s.id == ShortcutId.scanReceipt) return false;
      return true;
    }).take(6).toList();

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK SHORTCUTS',
            style: AppTypography.eyebrow.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: available.map((shortcut) {
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _handleShortcut(context, shortcut),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.hairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(shortcut.icon, size: 18, color: theme.accent),
                      const SizedBox(width: 8),
                      Text(
                        shortcut.label,
                        style: AppTypography.caption.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _handleShortcut(BuildContext context, ShortcutDefinition shortcut) {
    switch (shortcut.id) {
      case ShortcutId.splitCalculator:
        SplitCalculatorSheet.show(context);
        break;
      case ShortcutId.scanReceipt:
        context.push('/add');
        break;
      case ShortcutId.budgets:
        context.go('/insights/budgets');
        break;
      case ShortcutId.recurring:
        context.push('/settings/recurring');
        break;
      default:
        context.push('/add');
        break;
    }
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    SettlivThemeExtension theme,
    RecentActivityResult result, {
    required bool isCompact,
  }) {
    final repo = ref.watch(appRepositoryProvider);
    final items = result.items;

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'RECENT ACTIVITY',
                  style: AppTypography.eyebrow.copyWith(color: theme.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => context.go('/records'),
                child: Row(
                  children: [
                    Text(
                      'All records',
                      style: AppTypography.caption.copyWith(
                        color: theme.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: theme.accent),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              'No recent activity',
              style: AppTypography.body.copyWith(color: theme.muted),
            )
          else if (isCompact)
            // Compact view: stacked list
            ...items.map((item) => _buildCompactActivityItem(context, theme, item, repo))
          else
            // Desktop/Expanded: Proper table
            _buildActivityTable(context, theme, items, repo),
        ],
      ),
    );
  }

  Widget _buildActivityTable(
    BuildContext context,
    SettlivThemeExtension theme,
    List<ActivityItem> items,
    dynamic repo,
  ) {
    final currentUserId = repo.currentUserId;

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(4), // Description
        1: FlexColumnWidth(2.5), // Group
        2: FlexColumnWidth(2.5), // Paid by
        3: FlexColumnWidth(2), // Date
        4: FlexColumnWidth(2), // Share / Amount
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        // Table Header
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.hairline, width: 1)),
          ),
          children: [
            _buildTableHeaderCell('Description', theme),
            _buildTableHeaderCell('Group', theme),
            _buildTableHeaderCell('Paid by', theme),
            _buildTableHeaderCell('Date', theme),
            _buildTableHeaderCell('Your share', theme, alignRight: true),
          ],
        ),
        // Table Rows
        ...items.map((item) {
          if (item is ExpenseActivityItem) {
            final exp = item.expense;
            final group = repo.getGroup(exp.groupId);
            final yourShare = exp.shares[currentUserId] ?? 0;
            final payer = repo.getPerson(exp.paidBy);
            final payerName = NameNormalizer.formatPayer(
              payerId: exp.paidBy,
              currentUserId: currentUserId,
              fallbackName: payer?.name ?? 'Unknown',
            );
            final colors = CategoryPalette.getColors(exp.category, isDark: theme.isDark);

            return TableRow(
              children: [
                _buildTableCell(
                  InkWell(
                    onTap: () => ExpenseDetailSheet.show(
                      context: context,
                      expense: exp,
                      onEdit: () {},
                      onDelete: () {},
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: colors.tile,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              CategoryPalette.getIcon(exp.category),
                              size: 16,
                              color: colors.icon,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              exp.title,
                              style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildTableCell(
                  Text(
                    group?.name ?? 'Direct',
                    style: AppTypography.body.copyWith(color: theme.muted),
                  ),
                ),
                _buildTableCell(
                  Text(
                    payerName,
                    style: AppTypography.body.copyWith(color: theme.ink),
                  ),
                ),
                _buildTableCell(
                  Text(
                    DateFormat('d MMM').format(exp.date),
                    style: AppTypography.caption.copyWith(color: theme.muted),
                  ),
                ),
                _buildTableCell(
                  Text(
                    CurrencyFormatter.formatPaise(yourShare),
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w700,
                      color: theme.ink,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            );
          } else if (item is SettlementActivityItem) {
            final s = item.settlement;
            final group = repo.getGroup(s.groupId);
            final isPayer = s.from == currentUserId;

            return TableRow(
              children: [
                _buildTableCell(
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: theme.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.check_circle_rounded, size: 16, color: theme.emerald),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Settlement',
                            style: AppTypography.bodySemiBold.copyWith(color: theme.emerald),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildTableCell(
                  Text(group?.name ?? 'Direct', style: AppTypography.body.copyWith(color: theme.muted)),
                ),
                _buildTableCell(
                  Text(isPayer ? 'You paid' : 'You received', style: AppTypography.body.copyWith(color: theme.ink)),
                ),
                _buildTableCell(
                  Text(DateFormat('d MMM').format(s.date), style: AppTypography.caption.copyWith(color: theme.muted)),
                ),
                _buildTableCell(
                  Text(
                    CurrencyFormatter.formatPaise(s.paise),
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontWeight: FontWeight.w700,
                      color: theme.emerald,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            );
          }
          return const TableRow(children: [SizedBox(), SizedBox(), SizedBox(), SizedBox(), SizedBox()]);
        }),
      ],
    );
  }

  Widget _buildTableHeaderCell(String text, SettlivThemeExtension theme, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: theme.muted,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }

  Widget _buildCompactActivityItem(
    BuildContext context,
    SettlivThemeExtension theme,
    ActivityItem item,
    dynamic repo,
  ) {
    final currentUserId = repo.currentUserId;

    if (item is ExpenseActivityItem) {
      final exp = item.expense;
      final yourShare = exp.shares[currentUserId] ?? 0;
      final colors = CategoryPalette.getColors(exp.category, isDark: theme.isDark);

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => ExpenseDetailSheet.show(
            context: context,
            expense: exp,
            onEdit: () {},
            onDelete: () {},
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.hairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.tile,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CategoryPalette.getIcon(exp.category),
                    size: 18,
                    color: colors.icon,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exp.title, style: AppTypography.bodySemiBold.copyWith(color: theme.ink)),
                      const SizedBox(height: 2),
                      Text(DateFormat('d MMM').format(exp.date), style: AppTypography.caption.copyWith(color: theme.muted)),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatPaise(yourShare),
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: theme.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox();
  }

  Widget _buildFooter(BuildContext context, SettlivThemeExtension theme) {
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/settings'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Also runs as a mobile app and a website · See versions in Settings ›',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
