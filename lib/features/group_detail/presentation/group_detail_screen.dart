import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/balance_pill.dart';
import '../../../core/widgets/coming_soon_tag.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/group_cover_art.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/engine/balance_engine.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../sheets/expense_detail_sheet.dart';
import '../sheets/settle_sheet.dart';
import 'widgets/balance_bars_chart.dart';
import 'widgets/category_donut_chart.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;

  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  int _selectedTabIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final collapsed = _scrollController.hasClients &&
          _scrollController.offset > 110;
      if (collapsed != _isCollapsed) {
        setState(() => _isCollapsed = collapsed);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ({int currentDay, int totalDays}) _calculateTripProgress(Group group) {
    if (group.startDate == null || group.endDate == null) {
      return (currentDay: 1, totalDays: 1);
    }
    final total = group.endDate!.difference(group.startDate!).inDays + 1;
    final now = DateTime.now();
    final current = now.difference(group.startDate!).inDays + 1;
    final clampedCurrent = current.clamp(1, total);
    return (currentDay: clampedCurrent, totalDays: total);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final group = ref.watch(groupProvider(widget.groupId));
    final repo = ref.watch(appRepositoryProvider);
    final allPeople = ref.watch(allPeopleProvider);

    // Designed "Group not found" state
    if (group == null) {
      return Scaffold(
        backgroundColor: theme.canvas,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: AppColors.coral,
                ),
                const SizedBox(height: 16),
                Text(
                  'Group not found',
                  style: AppTypography.titleLarge.copyWith(color: theme.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'The group you requested does not exist or has been removed.',
                  style: AppTypography.body.copyWith(color: theme.secondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Back to Home',
                  onPressed: () => context.go('/'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final summary = repo.getGroupSummary(group.id);
    final expenses = repo.getExpensesForGroup(group.id);
    final currentUserId = repo.currentUserId;
    final userNetPaise = summary.netBalances[currentUserId] ?? 0;
    final groupMembers =
        allPeople.where((p) => group.memberIds.contains(p.id)).toList();

    return Scaffold(
      backgroundColor: theme.canvas,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Collapsing SliverAppBar
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                elevation: 0,
                backgroundColor: theme.surface,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.35),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _isCollapsed ? 1.0 : 0.0,
                  child: Text(
                    group.name,
                    style: AppTypography.titleLarge
                        .copyWith(color: theme.ink, fontSize: 18),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      GroupCoverArt(
                        coverType: group.coverType,
                        borderRadius: 0,
                        heroTag: 'group-cover-${group.id}',
                        height: 200,
                      ),
                      // Scrim overlay
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 16,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    group.type == GroupType.home
                                        ? 'Home group'
                                        : 'Trip',
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    group.name,
                                    style: AppTypography.titleLarge.copyWith(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                AvatarStack(
                                  people: groupMembers,
                                  size: 28,
                                  overlap: 8,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Group Header Summary Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: BalancePill(paise: userNetPaise)),
                          const SizedBox(width: 8),
                          Text(
                            '${groupMembers.length} members',
                            style: AppTypography.caption.copyWith(
                              color: theme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      // Trip Progress Bar (Trip groups only)
                      if (group.type == GroupType.trip) ...[
                        const SizedBox(height: 14),
                        Builder(builder: (context) {
                          final progress = _calculateTripProgress(group);
                          final double ratio = progress.totalDays > 0
                              ? progress.currentDay / progress.totalDays
                              : 1.0;

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.hairline),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Day ${progress.currentDay} of ${progress.totalDays} · ${group.name}',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: theme.ink,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${(ratio * 100).round()}%',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.saffron,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: SizedBox(
                                    height: 6,
                                    child: LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor: theme.raised,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        AppColors.saffron,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 12),
                      // Two quiet ComingSoonTag chips: Nudge reminders & Invite link
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: const [
                          ComingSoonTag(
                            label: 'Nudge reminders',
                            featureDescription:
                                'Send polite WhatsApp or push reminders for pending debts.',
                          ),
                          ComingSoonTag(
                            label: 'Invite link',
                            featureDescription:
                                'Share a join link via WhatsApp with other roommates or trip buddies.',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // SegmentedTabs: Expenses / Balances
                      SegmentedTabs(
                        labels: const ['Expenses', 'Balances'],
                        selectedIndex: _selectedTabIndex,
                        onTabSelected: (idx) =>
                            setState(() => _selectedTabIndex = idx),
                      ),
                    ],
                  ),
                ),
              ),

              // Content: Expenses tab OR Balances tab
              if (_selectedTabIndex == 0) ...[
                _buildExpensesTab(expenses, repo),
              ] else ...[
                _buildBalancesTab(summary, groupMembers, repo, currentUserId),
              ],

              // Bottom padding for sticky buttons
              const SliverToBoxAdapter(
                child: SizedBox(height: 110),
              ),
            ],
          ),

          // Sticky Bottom Actions: Floating Add Button & Settle up Primary Button
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Floating Add Button positioned cleanly above bottom bar
                FloatingActionButton.small(
                  heroTag: 'group_add_expense_btn',
                  backgroundColor: AppColors.midnightNavy,
                  elevation: 6,
                  shape: const CircleBorder(),
                  onPressed: () {
                    context.push(
                      '/add',
                      extra: {'preselectedGroupId': widget.groupId},
                    );
                  },
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(height: 12),
                // Full-width Settle Up primary button
                PrimaryButton(
                  label: userNetPaise < 0
                      ? 'Settle up · ${CurrencyFormatter.formatPaise(userNetPaise.abs(), absolute: true)}'
                      : 'Settle up',
                  onPressed: () {
                    SettleSheet.show(
                      context: context,
                      group: group,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Expenses List
  // ---------------------------------------------------------------------------
  Widget _buildExpensesTab(List<Expense> expenses, AppRepository repo) {
    if (expenses.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            title: 'No expenses in this group',
            subtitle: 'Add the first bill, grocery run or ticket to split.',
            action: ElevatedButton.icon(
              onPressed: () {
                context.push(
                  '/add',
                  extra: {'preselectedGroupId': widget.groupId},
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add group expense'),
            ),
          ),
        ),
      );
    }

    // Group by day header
    final Map<String, List<Expense>> grouped = {};
    for (final exp in expenses) {
      final header = DateFormatter.formatDayHeader(exp.date);
      grouped.putIfAbsent(header, () => []).add(exp);
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = grouped.entries.elementAt(index);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Text(
                    entry.key,
                    style: AppTypography.caption.copyWith(
                      color: context.settliv.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final exp in entry.value) ...[
                  ExpenseTile(
                    expense: exp,
                    payer: repo.getPerson(exp.paidBy),
                    group: repo.getGroup(exp.groupId),
                    currentUserId: repo.currentUserId,
                    onTap: () {
                      ExpenseDetailSheet.show(
                        context: context,
                        expense: exp,
                        onEdit: () {
                          context.push(
                            '/add',
                            extra: {'initialExpense': exp},
                          );
                        },
                        onDelete: () {
                          final repoNotifier =
                              ref.read(appStateProvider.notifier);
                          repoNotifier.deleteExpense(exp.id);
                          UndoSnackbar.show(
                            context: context,
                            message: 'Deleted ${exp.title}',
                            onUndo: () => repoNotifier.restoreExpense(exp.id),
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            );
          },
          childCount: grouped.length,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Balances Tab
  // ---------------------------------------------------------------------------
  Widget _buildBalancesTab(
    GroupBalanceSummary summary,
    List<Person> members,
    AppRepository repo,
    String currentUserId,
  ) {
    final theme = context.settliv;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // 1. "Who pays whom" section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Who pays whom',
                  style: AppTypography.sectionHeader.copyWith(
                    color: theme.ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 14),
                if (summary.debts.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'All balances are settled in this group!',
                        style:
                            AppTypography.body.copyWith(color: theme.secondary),
                      ),
                    ),
                  ),
                ] else ...[
                  for (final debt in summary.debts) ...[
                    Builder(builder: (context) {
                      final fromPerson = repo.getPerson(debt.fromPersonId);
                      final toPerson = repo.getPerson(debt.toPersonId);
                      final isUserOwing = debt.fromPersonId == currentUserId;
                      final isUserOwed = debt.toPersonId == currentUserId;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            PersonAvatar(person: fromPerson, size: 28),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 16,
                              color: AppColors.teal,
                            ),
                            const SizedBox(width: 6),
                            PersonAvatar(person: toPerson, size: 28),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${fromPerson?.name ?? "Someone"} → ${toPerson?.name ?? "Someone"}',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: theme.ink,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    CurrencyFormatter.formatPaise(
                                      debt.amount,
                                      absolute: true,
                                    ),
                                    style: AppTypography.caption.copyWith(
                                      color: theme.ink,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Trailing action
                            if (isUserOwing) ...[
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.midnightNavy,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  SettleSheet.show(
                                    context: context,
                                    group: repo.getGroup(widget.groupId)!,
                                    preselectedDebt: debt,
                                  );
                                },
                                child: const Text('Settle',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ] else if (isUserOwed) ...[
                              ComingSoonTag(
                                label: 'Nudge',
                                featureDescription:
                                    'Send a friendly payment reminder via SMS or WhatsApp.',
                              ),
                            ] else ...[
                              Text(
                                'Pending',
                                style: AppTypography.caption.copyWith(
                                  color: theme.tertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    if (debt != summary.debts.last)
                      Divider(height: 1, color: theme.hairline),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Per-member balance bars
          BalanceBarsChart(
            netBalances: summary.netBalances,
            people: members,
          ),
          const SizedBox(height: 16),

          // 3. Spend by category donut chart
          CategoryDonutChart(
            categorySpend: summary.categorySpend,
            totalSpend: summary.totalSpend,
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}
