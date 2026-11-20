import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/balance_hero_card.dart';
import '../../../core/widgets/group_cover_art.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../group_detail/sheets/expense_detail_sheet.dart';
import '../../group_detail/sheets/nudge_sheet.dart';
import '../domain/recent_activity_engine.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _getTimeGreeting(String name) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning, $name';
    } else if (hour < 17) {
      return 'Good afternoon, $name';
    } else {
      return 'Good evening, $name';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final overall = ref.watch(userOverallBalanceProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final sharedGroups = allGroups.where((g) => !g.isPersonal).toList();
    final people = ref.watch(allPeopleProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final allSettlements = ref.watch(allSettlementsProvider);
    final currentUser = repo.currentUser;
    final currentUserId = repo.currentUserId;
    final now = DateTime.now();

    // 1. Header date line: "Tuesday, 17 November"
    final dateLine = DateFormat('EEEE, d MMMM').format(now);

    // 2. Counterparties for Hero card footer
    final peopleOwingUser = <Person>[];
    final peopleUserOwes = <Person>[];
    for (final group in sharedGroups) {
      final summary = repo.getGroupSummary(group.id);
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

    // 3. "This month" compact calculation: YOUR share this month vs last month
    final startOfThisMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

    int thisMonthYourSpend = 0;
    int lastMonthYourSpend = 0;

    for (final exp in allExpenses) {
      if (!exp.isDeleted) {
        final share = exp.computedShares[currentUserId] ?? 0;
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
    final int daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    final double monthProgress = (now.day / daysInCurrentMonth).clamp(0.0, 1.0);

    // 4. "Needs attention" check:
    // a) Recurring bill due within 7 days
    // b) Over-budget
    // c) Counterparty owing user for 7+ days
    String? attentionMessage;
    VoidCallback? attentionAction;
    String? attentionActionLabel;

    // Check counterparties owing for 7+ days
    for (final group in sharedGroups) {
      final summary = repo.getGroupSummary(group.id);
      for (final debt in summary.debts) {
        if (debt.toPersonId == currentUserId && debt.amount > 0) {
          // Find oldest unsettled expense in this group involving them
          final debtorExpenses = allExpenses.where((e) =>
            !e.isDeleted && e.groupId == group.id && (e.computedShares[debt.fromPersonId] ?? 0) > 0
          ).toList();
          final oldest = debtorExpenses.isNotEmpty
              ? debtorExpenses.reduce((a, b) => a.date.isBefore(b.date) ? a : b)
              : null;
          if (oldest != null) {
            final daysAgo = now.difference(oldest.date).inDays;
            if (daysAgo >= 7) {
              final debtorPerson = repo.getPerson(debt.fromPersonId);
              if (debtorPerson != null) {
                attentionMessage = '${debtorPerson.name} owes you ${CurrencyFormatter.formatPaise(debt.amount)} for $daysAgo days';
                attentionActionLabel = 'Nudge';
                attentionAction = () {
                  NudgeSheet.show(
                    context: context,
                    group: group,
                    debtor: debtorPerson,
                    amountPaise: debt.amount,
                  );
                };
                break;
              }
            }
          }
        }
      }
      if (attentionMessage != null) break;
    }

    // 5. Recent activity rule using pure function RecentActivityEngine
    final recentActivityResult = RecentActivityEngine.computeRecentActivity(
      expenses: allExpenses,
      settlements: allSettlements,
      now: now,
    );

    // 6. Recent groups: max 2 by last activity
    final sortedGroups = List<Group>.from(sharedGroups)..sort((a, b) {
      // Find latest expense in each group
      final expA = allExpenses.where((e) => e.groupId == a.id && !e.isDeleted).toList();
      final expB = allExpenses.where((e) => e.groupId == b.id && !e.isDeleted).toList();
      final dateA = expA.isNotEmpty ? expA.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y) : (a.createdAt ?? DateTime(2020));
      final dateB = expB.isNotEmpty ? expB.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y) : (b.createdAt ?? DateTime(2020));
      return dateB.compareTo(dateA);
    });
    final recentGroups = sortedGroups.take(2).toList();

    return Scaffold(
      backgroundColor: theme.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
            children: [
              // 1. Header: Greeting + Date line + 44px Avatar Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTimeGreeting(currentUser?.name ?? 'Arjun'),
                          style: AppTypography.screenTitle.copyWith(
                            color: theme.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateLine,
                          style: AppTypography.caption.copyWith(
                            color: theme.muted,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 44px Avatar Button -> /settings
                  Semantics(
                    button: true,
                    label: 'Profile and Settings',
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.push('/settings');
                      },
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
              const SizedBox(height: 20),

              // 2. Hero Card: NET ACROSS GROUPS
              BalanceHeroCard(
                netPaise: overall.netBalance,
                totalOwedToUserPaise: overall.totalOwedToUser,
                totalUserOwesPaise: overall.totalUserOwes,
                owedFromCount: peopleOwingUser.length,
                owesToCount: peopleUserOwes.length,
                counterparties: allCounterparties,
                onTap: () => context.push('/balances'),
              ),
              const SizedBox(height: 18),

              // 3. "This month" compact card -> tap opens Insights
              SectionCard(
                onTap: () => context.go('/insights'),
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
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: monthProgress,
                              minHeight: 4,
                              backgroundColor: theme.hairline,
                              valueColor: AlwaysStoppedAnimation<Color>(theme.navy),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. "Needs attention" card: ONLY when something exists
              if (attentionMessage != null) ...[
                SectionCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.coralTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.priority_high_rounded, color: theme.coral, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          attentionMessage,
                          style: AppTypography.caption.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (attentionAction != null && attentionActionLabel != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: attentionAction,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            attentionActionLabel,
                            style: TextStyle(
                              color: theme.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // 5. "Recent activity" Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recent activity',
                      style: AppTypography.sectionTitle.copyWith(
                        color: theme.ink,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/records'),
                    child: Text(
                      'See all',
                      style: TextStyle(
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
                                'See all in Records ›',
                                style: TextStyle(
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
              const SizedBox(height: 24),

              // 6. "Recent groups" Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Recent groups',
                      style: AppTypography.sectionTitle.copyWith(
                        color: theme.ink,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/groups'),
                    child: Text(
                      'All groups ›',
                      style: TextStyle(
                        color: theme.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              for (final group in recentGroups) ...[
                _buildRecentGroupCard(group, repo, people, currentUserId, theme),
                const SizedBox(height: 12),
              ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getCategoryIcon(exp.category), color: theme.navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                      '$dateStr${isPayer ? "Paid by you" : "Paid by ${payer?.name ?? "Someone"}"}',
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
              Text(
                amountWords,
                style: AppTypography.caption.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
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
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settled with ${isFromMe ? payee?.name : payer?.name}',
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
            Text(
              statusWords,
              style: AppTypography.caption.copyWith(
                color: theme.textEmerald,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRecentGroupCard(
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

    return SectionCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/group/${group.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Small drawn cover strip (height 40)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 40,
              child: GroupCoverArt(
                group: group,
                height: 40,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        group.name,
                        style: AppTypography.sectionTitle.copyWith(
                          color: theme.ink,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Avatars
                    SizedBox(
                      height: 24,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final m in groupMembers.take(3))
                            Align(
                              widthFactor: 0.75,
                              child: PersonAvatar(person: m, size: 24),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Full-width balance text never truncated
                Text(
                  balanceSentence,
                  style: AppTypography.bodySemiBold.copyWith(
                    color: balanceColor,
                    fontSize: 14,
                  ),
                ),
              ],
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
        return Icons.receipt_rounded;
    }
  }
}
