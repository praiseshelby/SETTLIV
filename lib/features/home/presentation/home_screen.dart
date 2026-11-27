import 'dart:math' as math;
import 'widgets/dashboard_web_view.dart';
import '../../../core/profile/experience_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/category_palette.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/name_normalizer.dart';
import '../../../core/widgets/balance_hero_card.dart';
import '../../../core/widgets/group_cover_art.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/section_card.dart';
import '../../onboarding/domain/tour_scope.dart';
import '../../../data/engine/balance_engine.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../group_detail/sheets/expense_detail_sheet.dart';
import '../domain/recent_activity_engine.dart';
import 'widgets/day_period_tile.dart';
import 'widgets/home_shortcuts_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final effective = ref.watch(effectiveExperienceProvider);
    if (effective == EffectiveExperience.web) {
      return const DashboardWebView();
    }
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final overall = ref.watch(userOverallBalanceProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final sharedGroups = allGroups.where((g) => !g.isPersonal).toList();
    final people = ref.watch(allPeopleProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final settlements = ref.watch(allSettlementsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.id ?? repo.currentUserId;
    final now = DateTime.now();

    // 1. Counterparties across groups + IOUs for Hero card
    final allPeople = ref.watch(allPeopleProvider);
    final peopleMap = {for (final p in allPeople) p.id: p};
    final groupMembersMap = {for (final g in allGroups) g.id: g.memberIds};
    final iouNotes = ref.watch(allIouNotesProvider);

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

    // 2. "This month" compact calculation: compare month-to-date with SAME period last month
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

    // 3. "Needs attention" check:
    // a) Overdue balances / counterparties owing 7+ days (computed via FIFO matching)
    // b) Due recurring bills (if any)
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
              final dName = NameNormalizer.normalize(debtorPerson?.name ?? 'Someone');
              attentionMessage = '$dName owes you ${CurrencyFormatter.formatPaise(debt.amount)} for $daysAgo days';
              attentionAction = () => context.push('/balances');
            }
          }
        }
      }
    }

    // Check overdue IOU notes
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

    // 4. Header date line: weekday + date only
    final dateStr = DateFormat('EEEE, d MMM').format(now);

    // 5. Recent activity rule: pure function RecentActivityEngine
    final recentActivityResult = RecentActivityEngine.computeRecentActivity(
      expenses: allExpenses,
      settlements: settlements,
      now: now,
    );

    // 6. Recent groups: max 2 by last activity
    final sortedGroups = List<Group>.from(sharedGroups)..sort((a, b) {
      final expA = allExpenses.where((e) => e.groupId == a.id && !e.isDeleted).toList();
      final expB = allExpenses.where((e) => e.groupId == b.id && !e.isDeleted).toList();
      final dateA = expA.isNotEmpty ? expA.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y) : (a.createdAt ?? DateTime(2020));
      final dateB = expB.isNotEmpty ? expB.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y) : (b.createdAt ?? DateTime(2020));
      return dateB.compareTo(dateA);
    });
    final recentGroups = sortedGroups.take(2).toList();

    return ScreenScaffold(
      header: ScreenHeader(
        title: getTimeGreeting(now),
        subtitle: Text(
          dateStr,
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Profile and Settings',
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/settings');
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.hairline),
                ),
                padding: const EdgeInsets.all(3),
                child: PersonAvatar(
                  person: currentUser,
                  size: 38,
                  showRing: false,
                ),
              ),
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 2. Hero Card (NET POSITION)
              KeyedSubtree(
                key: TourScope.maybeOf(context)?.homeHeroKey,
                child: BalanceHeroCard(
                  netPaise: overall.netBalance,
                  totalOwedToUserPaise: overall.totalOwedToUser,
                  totalUserOwesPaise: overall.totalUserOwes,
                  owedFromCount: owedFromCount,
                  owesToCount: owesToCount,
                  counterparties: allCounterparties,
                  onTap: () {
                    final tour = TourScope.maybeOf(context);
                    if (tour != null) {
                      tour.onInterceptRoute?.call('/balances');
                    } else {
                      context.push('/balances');
                    }
                  },
                ),
              ),
              const SizedBox(height: 28),

              // 3. Shortcuts Row (5 equal tiles, pure function ranking)
              const HomeShortcutsRow(),
              const SizedBox(height: 28),

              // 4. "Needs attention" Card (Shown only when something exists, NO inline nudge buttons)
              if (attentionMessage != null) ...[
                KeyedSubtree(
                  key: TourScope.maybeOf(context)?.homeAttentionKey,
                  child: Semantics(
                    button: true,
                    label: 'Needs attention: $attentionMessage',
                    child: InkWell(
                      onTap: () {
                        final tour = TourScope.maybeOf(context);
                        if (tour != null) {
                          tour.onInterceptRoute?.call('/balances');
                        } else {
                          attentionAction?.call();
                        }
                      },
                    borderRadius: BorderRadius.circular(20),
                    child: SectionCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.coralTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.priority_high_rounded, color: theme.coral, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'NEEDS ATTENTION',
                                  style: AppTypography.eyebrow.copyWith(
                                    color: theme.coral,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  attentionMessage,
                                  style: AppTypography.caption.copyWith(
                                    color: theme.ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.chevron_right_rounded, size: 18, color: theme.muted),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
                const SizedBox(height: 28),
              ],

              // 5. "This month": compact single-row card -> tap opens Insights
              Semantics(
                button: true,
                label: 'This month spending overview',
                child: InkWell(
                  onTap: () => context.go('/insights'),
                  borderRadius: BorderRadius.circular(20),
                  child: SectionCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.calendar_month_rounded, color: theme.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'This month: ${CurrencyFormatter.formatPaise(thisMonthYourSpend)}',
                                      style: AppTypography.bodySemiBold.copyWith(
                                        color: theme.ink,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, size: 16, color: theme.muted),
                                ],
                              ),
                              if (lastMonthYourSpend > 0) ...[
                                const SizedBox(height: 3),
                                if (showAbsolute) ...[
                                  Text(
                                    diffSpend >= 0
                                        ? '${CurrencyFormatter.formatPaise(diffSpend, absolute: true)} more than last month'
                                        : '${CurrencyFormatter.formatPaise(diffSpend.abs(), absolute: true)} less than last month',
                                    style: AppTypography.caption.copyWith(
                                      color: diffSpend > 0 ? theme.coral : theme.emerald,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Icon(
                                        spendChangePercent >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                        size: 13,
                                        color: spendChangePercent > 0 ? theme.coral : theme.emerald,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${spendChangePercent.abs().toStringAsFixed(0)}% vs last month',
                                          style: AppTypography.caption.copyWith(
                                            color: spendChangePercent > 0 ? theme.coral : theme.emerald,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 6. Recent groups (Max 2 by last activity, compact ~96px, with small "All groups ›" row)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent groups',
                    style: AppTypography.sectionTitle.copyWith(color: theme.ink),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              for (final group in recentGroups) ...[
                _buildCompactRecentGroupCard(group, repo, people, currentUserId, theme),
                const SizedBox(height: 10),
              ],

              // Small "All groups ›" row switching to Groups tab
              InkWell(
                onTap: () => context.go('/groups'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'All groups',
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
                          color: theme.accent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 16, color: theme.accent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // 7. Recent activity (BELOW groups, max 3 rows, newest first, expenses + settlements)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recent activity',
                      style: AppTypography.sectionTitle.copyWith(color: theme.ink),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/records'),
                    child: Text(
                      'See all',
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        color: theme.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (recentActivityResult.items.isEmpty) ...[
                SectionCard(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No recent activity yet',
                      style: AppTypography.caption.copyWith(color: theme.muted),
                    ),
                  ),
                ),
              ] else ...[
                SectionCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < recentActivityResult.items.length; i++) ...[
                        _buildActivityRow(
                          item: recentActivityResult.items[i],
                          repo: repo,
                          currentUserId: currentUserId,
                          spansMultipleDays: recentActivityResult.spansMultipleDays,
                          theme: theme,
                        ),
                        if (i < recentActivityResult.items.length - 1)
                          Divider(height: 1, color: theme.hairline),
                      ],
                      if (recentActivityResult.hasMoreToday) ...[
                        Divider(height: 1, color: theme.hairline),
                        InkWell(
                          onTap: () => context.go('/records'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                '${recentActivityResult.moreTodayCount} more today · See all',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontBody,
                                  color: theme.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildCompactRecentGroupCard(
    Group group,
    dynamic repo,
    List<Person> people,
    String currentUserId,
    SettlivThemeExtension theme,
  ) {
    final summary = repo.getGroupSummary(group.id);
    final userNet = summary.netBalances[currentUserId] ?? 0;
    final groupMembers = people.where((p) => group.memberIds.contains(p.id)).toList();

    final String balanceSentence;
    final Color balanceColor;
    if (userNet > 0) {
      balanceSentence = 'You are owed ${CurrencyFormatter.formatPaise(userNet)}';
      balanceColor = theme.textEmerald;
    } else if (userNet < 0) {
      balanceSentence = 'You owe ${CurrencyFormatter.formatPaise(userNet.abs())}';
      balanceColor = theme.textCoral;
    } else {
      balanceSentence = 'Settled up';
      balanceColor = theme.muted;
    }

    return Semantics(
      button: true,
      label: '${group.name}, $balanceSentence',
      child: InkWell(
        onTap: () => context.push('/group/${group.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.hairline),
          ),
          child: Row(
            children: [
              // 56px drawn cover tile with radius 16
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: GroupCoverArt(group: group),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name,
                            style: AppTypography.titleCard.copyWith(
                              color: theme.ink,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Small avatar stack
                        if (groupMembers.isNotEmpty)
                          SizedBox(
                            height: 20,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int i = 0; i < groupMembers.take(2).length; i++)
                                  Align(
                                    widthFactor: 0.7,
                                    child: PersonAvatar(person: groupMembers[i], size: 20),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Full-width balance text never truncated
                    Text(
                      balanceSentence,
                      style: AppTypography.caption.copyWith(
                        color: balanceColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${group.memberIds.length} members',
                      style: AppTypography.caption.copyWith(
                        color: theme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: theme.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityRow({
    required ActivityItem item,
    required dynamic repo,
    required String currentUserId,
    required bool spansMultipleDays,
    required SettlivThemeExtension theme,
  }) {
    if (item is ExpenseActivityItem) {
      final exp = item.expense;
      final payer = repo.getPerson(exp.paidBy);
      final isPayer = exp.paidBy == currentUserId;
      final userShare = exp.computedShares[currentUserId] ?? 0;
      final isInvolved = userShare > 0 || isPayer;

      final String amountWords;
      final Color amountColor;
      if (!isInvolved) {
        amountWords = 'Not involved';
        amountColor = theme.muted;
      } else if (isPayer) {
        final lent = exp.totalPaise - userShare;
        if (lent > 0) {
          amountWords = 'You lent ${CurrencyFormatter.formatPaise(lent)}';
          amountColor = theme.textEmerald;
        } else {
          amountWords = 'You paid ${CurrencyFormatter.formatPaise(userShare)}';
          amountColor = theme.ink;
        }
      } else {
        amountWords = 'You owe ${CurrencyFormatter.formatPaise(userShare)}';
        amountColor = theme.textCoral;
      }

      final dateStr = spansMultipleDays
          ? '${DateFormat('d MMM').format(exp.date)} · '
          : '';

      final catColors = CategoryPalette.getColors(exp.category, isDark: theme.isDark);
      final payerSubtitle = NameNormalizer.formatPayer(
        isPayer: isPayer,
        payerName: payer?.name,
      );

      return InkWell(
        onTap: () {
          ExpenseDetailSheet.show(
            context: context,
            expense: exp,
            onEdit: () {
              Navigator.pop(context);
              context.push('/add', extra: {
                'initialExpense': exp,
                'initialTabIndex': 1,
              });
            },
            onDelete: () {
              Navigator.pop(context);
              repo.deleteExpense(exp.id);
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Category icon tile with fixed dark-mode colours
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: catColors.tile,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getCategoryIcon(exp.category), color: catColors.icon, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exp.description,
                      style: AppTypography.bodySemiBold.copyWith(
                        color: theme.ink,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr$payerSubtitle',
                      style: AppTypography.caption.copyWith(
                        color: theme.muted,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  amountWords,
                  style: AppTypography.caption.copyWith(
                    color: amountColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (item is SettlementActivityItem) {
      final s = item.settlement;
      final payer = repo.getPerson(s.from);
      final payee = repo.getPerson(s.to);
      final isFromMe = s.from == currentUserId;
      final isToMe = s.to == currentUserId;

      final String statusWords = isFromMe
          ? 'You paid ${CurrencyFormatter.formatPaise(s.paise)}'
          : (isToMe ? 'You received ${CurrencyFormatter.formatPaise(s.paise)}' : 'Settlement');

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.emeraldTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.check_rounded, color: theme.emerald, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settled with ${isFromMe ? NameNormalizer.normalize(payee?.name ?? "") : NameNormalizer.normalize(payer?.name ?? "")}',
                    style: AppTypography.bodySemiBold.copyWith(
                      color: theme.ink,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM').format(s.date),
                    style: AppTypography.caption.copyWith(
                      color: theme.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 2,
              child: Text(
                statusWords,
                style: AppTypography.caption.copyWith(
                  color: theme.textEmerald,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
