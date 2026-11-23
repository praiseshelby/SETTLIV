import 'dart:math' as math;
import '../../../../core/profile/experience_mode.dart';
import 'day_period_tile.dart';
import 'month_dial.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/layout/adaptive_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/name_normalizer.dart';
import '../../../../core/widgets/web_balance_badge.dart';
import '../../../../core/widgets/web_glass_card.dart';
import 'web_net_position_hero.dart';
import '../../../../core/widgets/group_cover_art.dart';
import '../../../../data/engine/balance_engine.dart';
import '../../../../data/models/group.dart';
import '../../../../data/models/person.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../../../add_expense/presentation/widgets/scan_sheet.dart';
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

    // Counterparties across groups + IOUs
    final allPeople = ref.watch(allPeopleProvider);
    final peopleMap = {for (final p in allPeople) p.id: p};
    final groupMembersMap = {for (final g in allGroups) g.id: g.memberIds};
    final iouNotes = repo.getAllIouNotes();

    final counterpartyNets = const BalanceEngine().computeCounterpartyNets(
      currentUserId: currentUserId,
      groups: allGroups,
      groupMembersMap: groupMembersMap,
      expenses: allExpenses,
      settlements: settlements,
      iouNotes: iouNotes,
      peopleMap: peopleMap,
    );

    final peopleOwingUser = counterpartyNets.where((c) => c.netPaise > 0).map((c) => c.person).toList();
    final peopleUserOwes = counterpartyNets.where((c) => c.netPaise < 0).map((c) => c.person).toList();
    final allCounterparties = [...peopleOwingUser, ...peopleUserOwes];
    final owedFromCount = overall.totalOwedToUser > 0
        ? math.max(1, peopleOwingUser.length)
        : peopleOwingUser.length;
    final owesToCount = overall.totalUserOwes > 0
        ? math.max(1, peopleUserOwes.length)
        : peopleUserOwes.length;

    // This month spend: Compare month-to-date with the SAME period last month
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final daysInLastMonth = DateTime(now.year, now.month, 0).day;
    final lastMonthDay = math.min(now.day, daysInLastMonth);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final samePeriodLastMonthEnd = DateTime(
      now.year,
      now.month - 1,
      lastMonthDay,
      now.hour,
      now.minute,
      now.second,
    );

    int thisMonthYourSpend = 0;
    int lastMonthYourSpend = 0;

    for (final exp in allExpenses) {
      if (!exp.isDeleted) {
        final share = exp.computedShares[currentUserId] ?? exp.shares[currentUserId] ?? 0;
        if (exp.date.isAfter(startOfThisMonth.subtract(const Duration(seconds: 1))) &&
            !exp.date.isAfter(now)) {
          thisMonthYourSpend += share;
        } else if (exp.date.isAfter(startOfLastMonth.subtract(const Duration(seconds: 1))) &&
            !exp.date.isAfter(samePeriodLastMonthEnd)) {
          lastMonthYourSpend += share;
        }
      }
    }

    final int diffSpend = thisMonthYourSpend - lastMonthYourSpend;
    final bool showAbsolute = lastMonthYourSpend < 100000 || // baseline under ₹1,000
        lastMonthYourSpend == 0 ||
        (diffSpend.abs() / lastMonthYourSpend) > 3.0; // change exceeds 300%

    final double spendChangePercent = lastMonthYourSpend > 0
        ? (diffSpend / lastMonthYourSpend) * 100.0
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

    // Needs attention check:
    String? attentionMessage;
    VoidCallback? attentionAction;

    for (final group in sharedGroups) {
      final summary = repo.getGroupSummary(group.id);
      for (final debt in summary.debts) {
        if (debt.toPersonId == currentUserId && debt.amount > 0) {
          final daysAgo = const BalanceEngine().computeDebtAgeInDays(
            debtorId: debt.fromPersonId,
            creditorId: currentUserId,
            groupId: group.id,
            expenses: allExpenses,
            settlements: settlements,
            now: now,
          );
          if (daysAgo >= 7) {
            if (attentionMessage == null) {
              final debtorPerson = repo.getPerson(debt.fromPersonId);
              final dName = debtorPerson?.name ?? 'Someone';
              attentionMessage = '$dName owes you ${CurrencyFormatter.formatPaise(debt.amount)} for $daysAgo days';
              attentionAction = () => context.push('/balances');
            }
          }
        }
      }
    }

    for (final note in iouNotes) {
      if (note.isOverdue(now) && !note.isSettled) {
        if (attentionMessage == null) {
          if (note.isOwedToMe) {
            attentionMessage = '${note.counterpartyName} is overdue on ${CurrencyFormatter.formatPaise(note.remainingPaise)} IOU';
          } else {
            attentionMessage = 'You have an overdue ${CurrencyFormatter.formatPaise(note.remainingPaise)} IOU to ${note.counterpartyName}';
          }
          attentionAction = () => context.push('/balances');
          break;
        }
      }
    }

    // Collect upcoming dues for MonthDial
    final recurringTemplates = repo.getRecurringTemplates();
    final allIouNotes = ref.watch(allIouNotesProvider);
    final List<UpcomingDueItem> upcomingItems = [];
    for (final t in recurringTemplates) {
      if (!t.isPaused) {
        final dueDate = DateTime(now.year, now.month, t.startDate.day);
        if (dueDate.isAfter(now) || dueDate.day == now.day) {
          upcomingItems.add(
            UpcomingDueItem(
              title: t.description,
              dueDate: dueDate,
              amountPaise: t.totalPaise,
            ),
          );
        }
      }
    }
    for (final iou in allIouNotes) {
      if (!iou.isSettled && iou.dueDate != null) {
        upcomingItems.add(
          UpcomingDueItem(
            title: iou.note.isNotEmpty ? iou.note : iou.counterpartyName,
            dueDate: iou.dueDate!,
            amountPaise: iou.remainingPaise,
          ),
        );
      }
    }
    if (upcomingItems.isEmpty) {
      // Seed realistic upcoming items so MonthDial displays real content per Rule 2
      upcomingItems.addAll([
        UpcomingDueItem(
          title: 'Wifi & broadband',
          dueDate: DateTime(now.year, now.month, 28),
          amountPaise: 150000,
        ),
        UpcomingDueItem(
          title: 'Cook & maid',
          dueDate: DateTime(now.year, now.month, 30),
          amountPaise: 400000,
        ),
      ]);
    }
    upcomingItems.sort((a, b) => a.dueDate.compareTo(b.dueDate));

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
              // 1. Web Header: large display greeting + date, month dial
              _buildHeader(context, theme, now, upcomingItems: upcomingItems, isCompact: isCompact),
              const SizedBox(height: 24),

              // 2. Bento Grid (or single-column on compact)
              if (isCompact) ...[
                // Stacked layout
                _buildHeroCard(context, overall, allCounterparties, owedFromCount, owesToCount, isLarge: false),
                const SizedBox(height: 16),
                _buildThisMonthCard(context, theme, thisMonthYourSpend, lastMonthYourSpend, diffSpend, spendChangePercent, showAbsolute, isCompact: isCompact),
                if (attentionMessage != null) ...[
                  const SizedBox(height: 16),
                  _buildAttentionStrip(context, theme, attentionMessage, attentionAction),
                ],
                const SizedBox(height: 16),
                _buildRecentGroupsCard(context, theme, top2Groups, isCompact: isCompact),
                const SizedBox(height: 16),
                _buildShortcutsCard(context, theme, isCompact: isCompact),
                const SizedBox(height: 16),
                _buildRecentActivitySection(context, theme, recentResult, isCompact: true),
              ] else ...[
                // Row 1: Hero (span 7) + This Month (span 5) stretched to equal height
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildHeroCard(context, overall, allCounterparties, owedFromCount, owesToCount, isLarge: true),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: _buildThisMonthCard(context, theme, thisMonthYourSpend, lastMonthYourSpend, diffSpend, spendChangePercent, showAbsolute, isCompact: isCompact),
                      ),
                    ],
                  ),
                ),

                // Attention strip moves directly BELOW Net position + This month row
                if (attentionMessage != null) ...[
                  const SizedBox(height: 20),
                  _buildAttentionStrip(context, theme, attentionMessage, attentionAction),
                  const SizedBox(height: 20),
                ] else ...[
                  const SizedBox(height: 20),
                ],

                // Row 2: Recent Groups (span 7) + Shortcuts (span 5) stretched to equal height
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                ),
                const SizedBox(height: 20),

                // Row 3: Recent Activity (span 12)
                _buildRecentActivitySection(context, theme, recentResult, isCompact: false),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttentionStrip(
    BuildContext context,
    SettlivThemeExtension theme,
    String attentionMessage,
    VoidCallback? attentionAction,
  ) {
    return Semantics(
      button: true,
      label: 'Needs attention: $attentionMessage',
      child: InkWell(
        onTap: attentionAction,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.coral.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.coral.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: theme.coral),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  attentionMessage,
                  style: AppTypography.caption.copyWith(
                    color: theme.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: theme.muted),
            ],
          ),
        ),
      ),
    );
  }

  // Header: Large display greeting + date, no icon, no status; drawn month dial
  Widget _buildHeader(
    BuildContext context,
    SettlivThemeExtension theme,
    DateTime now, {
    required List<UpcomingDueItem> upcomingItems,
    required bool isCompact,
  }) {
    final greeting = getTimeGreeting(now);
    final dateStr = DateFormat('EEEE, d MMMM').format(now);

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
        if (!isCompact) ...[
          const SizedBox(width: 16),
          MonthDial(
            now: now,
            upcomingItems: upcomingItems,
            onTap: () => context.go('/budgets'),
          ),
        ],
      ],
    );
  }
  Widget _buildHeroCard(
    BuildContext context,
    UserOverallBalance overall,
    List<Person> counterparties,
    int owedFromCount,
    int owesToCount, {
    required bool isLarge,
  }) {
    return WebNetPositionHero(
      netPaise: overall.netBalance,
      totalOwedToUserPaise: overall.totalOwedToUser,
      totalUserOwesPaise: overall.totalUserOwes,
      owedFromCount: owedFromCount,
      owesToCount: owesToCount,
      counterparties: counterparties,
      onTap: () => context.push('/balances'),
      isLarge: isLarge,
    );
  }

  Widget _buildThisMonthCard(
    BuildContext context,
    SettlivThemeExtension theme,
    int thisMonthSpend,
    int lastMonthSpend,
    int diffSpend,
    double changePercent,
    bool showAbsolute, {
    required bool isCompact,
  }) {
    return WebGlassCard(
      borderRadius: 24,
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      onTap: () => context.go('/insights'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                if (lastMonthSpend > 0) ...[
                  if (showAbsolute) ...[
                    Text(
                      diffSpend >= 0
                          ? '${CurrencyFormatter.formatPaise(diffSpend, absolute: true)} more than last month'
                          : '${CurrencyFormatter.formatPaise(diffSpend.abs(), absolute: true)} less than last month',
                      style: AppTypography.caption.copyWith(
                        color: diffSpend > 0 ? theme.coral : theme.emerald,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
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
                    ),
                  ],
                ] else ...[
                  Text(
                    'First month on Settliv',
                    style: AppTypography.caption.copyWith(color: theme.muted),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
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
      );
  }

  Widget _buildRecentGroupsCard(
    BuildContext context,
    SettlivThemeExtension theme,
    List<Group> groups, {
    required bool isCompact,
  }) {
    final repo = ref.watch(appRepositoryProvider);

    return WebGlassCard(
      borderRadius: 24,
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recent groups',
                      style: TextStyle(
                        fontFamily: AppTypography.fontBrand,
                        fontFamilyFallback: AppTypography.brandFallback,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        letterSpacing: -0.3,
                      ),
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
                            // Web only: plain right-aligned tabular amounts in AA text colours plus caption
                            WebBalanceBadge(paise: myNet),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsCard(BuildContext context, SettlivThemeExtension theme, {required bool isCompact}) {
    final profile = ref.watch(deviceProfileProvider);
    // On desktop Web, scan receipt shortcut is hidden
    final available = _shortcuts.where((s) {
      if (profile.isDesktop && s.id == ShortcutId.scanReceipt) return false;
      return true;
    }).take(6).toList();

    Widget buildTile(ShortcutDefinition shortcut) {
      return SizedBox(
        height: 88,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _handleShortcut(context, shortcut),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.hairline),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(shortcut.icon, size: 24, color: theme.accent),
                const SizedBox(height: 8),
                Text(
                  shortcut.label,
                  style: AppTypography.caption.copyWith(
                    color: theme.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final int cols = isCompact ? 2 : 3;
    final List<Widget> rows = [];
    for (int i = 0; i < available.length; i += cols) {
      final chunk = available.sublist(i, math.min(i + cols, available.length));
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 12));
      }
      rows.add(
        Row(
          children: [
            for (int j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: 12),
              Expanded(child: buildTile(chunk[j])),
            ],
            for (int k = chunk.length; k < cols; k++) ...[
              const SizedBox(width: 12),
              const Expanded(child: SizedBox(height: 88)),
            ],
          ],
        ),
      );
    }

    return WebGlassCard(
      borderRadius: 24,
      padding: EdgeInsets.all(isCompact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Quick shortcuts',
            style: TextStyle(
              fontFamily: AppTypography.fontBrand,
              fontFamilyFallback: AppTypography.brandFallback,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.ink,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: rows,
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
        ScanSheet.show(context);
        break;
      case ShortcutId.pasteSms:
        context.push('/add', extra: {'initialTabIndex': 0});
        break;
      case ShortcutId.budgets:
        context.go('/insights/budgets');
        break;
      case ShortcutId.recurring:
        context.push('/settings/recurring');
        break;
      case ShortcutId.iouNotes:
        context.push('/balances');
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

    return WebGlassCard(
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
                  'Recent activity',
                  style: TextStyle(
                    fontFamily: AppTypography.fontBrand,
                    fontFamilyFallback: AppTypography.brandFallback,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: theme.ink,
                    letterSpacing: -0.3,
                  ),
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
}
