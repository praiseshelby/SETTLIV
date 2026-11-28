import 'widgets/group_detail_web_view.dart';
import '../../../core/profile/experience_mode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/avatar_stack.dart';
import '../../../core/widgets/balance_pill.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/glass_segmented.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/group_cover_art.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/engine/balance_engine.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../sheets/expense_detail_sheet.dart';
import '../sheets/settle_sheet.dart';
import '../sheets/mark_received_sheet.dart';
import '../sheets/nudge_sheet.dart';
import '../sheets/edit_group_sheet.dart';
import '../sheets/group_sharing_sheet.dart';
import '../../onboarding/domain/tour_scope.dart';
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
      return AuroraBackground(
        child: Scaffold(
          backgroundColor: theme.transparent,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 56,
                    color: theme.textCoral,
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
        ),
      );
    }

    final summary = repo.getGroupSummary(group.id);
    final expenses = repo.getExpensesForGroup(group.id);
    final currentUserId = repo.currentUserId;
    final userNetPaise = summary.netBalances[currentUserId] ?? 0;
    final groupMembers =
        allPeople.where((p) => group.memberIds.contains(p.id)).toList();

    final effective = ref.watch(effectiveExperienceProvider);
    if (effective == EffectiveExperience.web) {
      final tripProgress = _calculateTripProgress(group);
      return AuroraBackground(
        child: Scaffold(
          backgroundColor: theme.transparent,
          body: GroupDetailWebView(
            group: group,
            expenses: expenses,
            summary: summary,
            groupMembers: groupMembers,
            currentUserId: currentUserId,
            tripProgress: tripProgress,
          ),
        ),
      );
    }

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: theme.transparent,
        body: Stack(
          children: [
            RefreshIndicator.adaptive(
              onRefresh: () => ref
                  .read(appStateProvider.notifier)
                  .refreshFromRemoteIfSupported(),
              child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Collapsing SliverAppBar
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: theme.canvas.withValues(alpha: 0.85),
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: 'Back to Home',
                        child: InkWell(
                          onTap: () => context.pop(),
                          borderRadius: BorderRadius.circular(999),
                          child: GlassSurface(
                            level: GlassLevel.level1,
                            borderRadius: 999,
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: theme.ink,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _isCollapsed ? 1.0 : 0.0,
                    child: Text(
                      group.name,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  actions: [
                    if (!group.isPersonal) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: 'Members and sharing',
                            child: InkWell(
                              onTap: () => GroupSharingSheet.show(
                                context: context,
                                group: group,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              child: GlassSurface(
                                level: GlassLevel.level1,
                                borderRadius: 999,
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.group_add_rounded,
                                  color: theme.ink,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: Semantics(
                            button: true,
                            label: 'Edit Group',
                            child: InkWell(
                              onTap: () => EditGroupSheet.show(
                                context: context,
                                group: group,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              child: GlassSurface(
                                level: GlassLevel.level1,
                                borderRadius: 999,
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: theme.ink,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        GroupCoverArt(
                          group: group,
                          coverType: group.coverType,
                          borderRadius: 0,
                          heroTag: 'group-cover-${group.id}',
                          height: 200,
                        ),
                        // Gradient scrim overlay
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.transparent,
                                theme.scrim,
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
                                      color: theme.white.withValues(alpha: 0.22),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      group.type == GroupType.home
                                          ? 'Home group'
                                          : 'Trip',
                                      style: AppTypography.caption.copyWith(
                                        color: theme.white,
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
                                        color: theme.white,
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
                        // Glass Summary Card
                        GlassSurface(
                          key: TourScope.maybeOf(context)?.groupBalancesKey,
                          level: GlassLevel.level2,
                          borderRadius: 22,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BalancePill(
                                key: TourScope.maybeOf(context)?.groupSettleKey,
                                paise: userNetPaise,
                              ),
                              // Trip Progress Bar (Trip groups only)
                              if (group.type == GroupType.trip) ...[
                                const SizedBox(height: 14),
                                Builder(builder: (context) {
                                  final progress = _calculateTripProgress(group);
                                  final double ratio = progress.totalDays > 0
                                      ? progress.currentDay / progress.totalDays
                                      : 1.0;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Day ${progress.currentDay} of ${progress.totalDays}',
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: theme.ink,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                          Text(
                                            '${(ratio * 100).round()}%',
                                            style: AppTypography.caption.copyWith(
                                              color: theme.saffron,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(999),
                                        child: SizedBox(
                                          height: 5,
                                          child: LinearProgressIndicator(
                                            value: ratio,
                                            backgroundColor:
                                                theme.raised.withValues(alpha: 0.6),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              theme.saffron,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                              const SizedBox(height: 14),
                              // Clean row of two text+icon actions: Nudge (functional) and Settle up (functional)
                              Row(
                                children: [
                                  Expanded(
                                    child: Semantics(
                                      button: true,
                                      label: 'Send nudge reminder',
                                      child: InkWell(
                                        onTap: () {
                                          final debt = summary.debts
                                              .cast<SimplifiedDebt?>()
                                              .firstWhere(
                                                (d) =>
                                                    d?.toPersonId ==
                                                    currentUserId,
                                                orElse: () => null,
                                              );
                                          final debtor = debt != null
                                              ? repo.getPerson(debt.fromPersonId)
                                              : null;
                                          NudgeSheet.show(
                                            context: context,
                                            group: group,
                                            debt: debt,
                                            debtor: debtor,
                                            amountPaise: debt?.amount,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: theme.surface
                                                .withValues(alpha: 0.7),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: theme.hairline),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.notifications_none_rounded,
                                                size: 16,
                                                color: theme.navy,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Nudge',
                                                  style: AppTypography.button
                                                      .copyWith(
                                                    color: theme.ink,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Semantics(
                                      button: true,
                                      label: 'Settle up',
                                      child: InkWell(
                                        onTap: () {
                                          SettleSheet.show(
                                            context: context,
                                            group: group,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: theme.surface
                                                .withValues(alpha: 0.7),
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                                color: theme.hairline),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.flash_on_rounded,
                                                size: 16,
                                                color: theme.navy,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  'Settle up',
                                                  style: AppTypography.button
                                                      .copyWith(
                                                    color: theme.ink,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),
                        // GlassSegmented: Expenses / Balances
                        GlassSegmented<int>(
                          values: const [0, 1],
                          labels: const ['Expenses', 'Balances'],
                          selectedValue: _selectedTabIndex,
                          onValueChanged: (idx) =>
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

                // Bottom padding for sticky bottom actions
                const SliverToBoxAdapter(
                  child: SizedBox(height: 120),
                ),
              ],
            ),
            ),

            // Sticky Bottom Actions: Floating Add Button & Settle up CTA
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: GlassSurface(
                level: GlassLevel.level3,
                borderRadius: 28,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Frosted circular add button
                    Semantics(
                      button: true,
                      label: 'Add expense to group',
                      child: InkWell(
                        onTap: () {
                          context.push(
                            '/add',
                            extra: {'preselectedGroupId': widget.groupId},
                          );
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.surface.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.hairline),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: theme.ink,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Settle up Primary Button
                    Expanded(
                      child: PrimaryButton(
                        label: userNetPaise < 0
                            ? 'Settle up · ${CurrencyFormatter.formatPaise(userNetPaise.abs(), absolute: true)}'
                            : 'Settle up',
                        leading: Icon(Icons.flash_on_rounded,
                            color: theme.primaryButtonText, size: 20),
                        onPressed: () {
                          SettleSheet.show(
                            context: context,
                            group: group,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Expenses List
  // ---------------------------------------------------------------------------
  Widget _buildExpensesTab(List<Expense> expenses, AppRepository repo) {
    final theme = context.settliv;
    if (expenses.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: EmptyState(
            title: 'No expenses in this group',
            subtitle: 'Add the first bill, grocery run or ticket to split.',
            action: PrimaryButton(
              label: 'Add group expense',
              leading: Icon(Icons.add_rounded, color: theme.primaryButtonText, size: 20),
              onPressed: () {
                context.push(
                  '/add',
                  extra: {'preselectedGroupId': widget.groupId},
                );
              },
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
            final dayExpenses = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: AppTypography.sectionHeader.copyWith(
                      color: context.settliv.secondary,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                GlassSurface(
                  level: GlassLevel.level2,
                  borderRadius: 24,
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < dayExpenses.length; i++) ...[
                        ExpenseTile(
                          expense: dayExpenses[i],
                          payer: repo.getPerson(dayExpenses[i].paidBy),
                          group: repo.getGroup(dayExpenses[i].groupId),
                          currentUserId: repo.currentUserId,
                          showGroupName: false,
                          onTap: () {
                            ExpenseDetailSheet.show(
                              context: context,
                              expense: dayExpenses[i],
                              onEdit: () {
                                context.push(
                                  '/add',
                                  extra: {'initialExpense': dayExpenses[i]},
                                );
                              },
                              onDelete: () {
                                final repoNotifier =
                                    ref.read(appStateProvider.notifier);
                                repoNotifier.deleteExpense(dayExpenses[i].id);
                                UndoSnackbar.show(
                                  context: context,
                                  message: 'Deleted ${dayExpenses[i].title}',
                                  onUndo: () => repoNotifier
                                      .restoreExpense(dayExpenses[i].id),
                                );
                              },
                            );
                          },
                        ),
                        if (i < dayExpenses.length - 1)
                          Padding(
                            padding: const EdgeInsets.only(left: 68, right: 16),
                            child: Divider(
                              height: 1,
                              thickness: 0.5,
                              color: context.settliv.hairline,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
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
          GlassSurface(
            level: GlassLevel.level2,
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Who pays whom',
                  style: AppTypography.sectionHeader.copyWith(
                    color: theme.ink,
                    fontSize: 14,
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
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: theme.navy,
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
                                      fontWeight: FontWeight.w600,
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
                              Semantics(
                                button: true,
                                label: 'Settle debt',
                                child: InkWell(
                                  onTap: () {
                                    SettleSheet.show(
                                      context: context,
                                      group: repo.getGroup(widget.groupId)!,
                                      preselectedDebt: debt,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.primaryButtonBg,
                                      borderRadius: const BorderRadius.all(Radius.circular(999)),
                                    ),
                                    child: Text(
                                      'Settle',
                                      style: TextStyle(
                                        color: theme.primaryButtonText,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ] else if (isUserOwed) ...[
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Semantics(
                                    button: true,
                                    label: 'Send nudge reminder to ${fromPerson?.name ?? "debtor"}',
                                    child: InkWell(
                                      onTap: () {
                                        final currentGroup =
                                            repo.getGroup(widget.groupId);
                                        if (currentGroup != null) {
                                          NudgeSheet.show(
                                            context: context,
                                            group: currentGroup,
                                            debt: debt,
                                            debtor: fromPerson,
                                            amountPaise: debt.amount,
                                          );
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(999),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: theme.surface.withValues(alpha: 0.8),
                                          borderRadius: const BorderRadius.all(
                                              Radius.circular(999)),
                                          border: Border.all(color: theme.hairline),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.notifications_none_rounded,
                                              size: 13,
                                              color: theme.ink,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Nudge',
                                              style: TextStyle(
                                                color: theme.ink,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (fromPerson != null)
                                    Semantics(
                                      button: true,
                                      label: 'Mark received from ${fromPerson.name}',
                                      child: InkWell(
                                        onTap: () {
                                          final currentGroup =
                                              repo.getGroup(widget.groupId);
                                          if (currentGroup != null) {
                                            MarkReceivedSheet.show(
                                              context: context,
                                              payer: fromPerson,
                                              group: currentGroup,
                                              maxAmountPaise: debt.amount,
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(999),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: theme.emerald,
                                            borderRadius: const BorderRadius.all(
                                                Radius.circular(999)),
                                          ),
                                          child: Text(
                                            'Mark received',
                                            style: TextStyle(
                                              color: theme.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
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
