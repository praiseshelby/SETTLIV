import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/layout/adaptive_layout.dart';
import '../../../../core/navigation/back_navigation.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/avatar_stack.dart';
import '../../../../core/widgets/web_balance_badge.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/group_cover_art.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../../data/engine/balance_engine.dart';
import '../../../../data/models/expense.dart';
import '../../../../data/models/group.dart';
import '../../../../data/models/person.dart';
import '../../sheets/edit_group_sheet.dart';
import '../../sheets/expense_detail_sheet.dart';
import '../../sheets/nudge_sheet.dart';
import '../../sheets/settle_sheet.dart';
import 'category_donut_chart.dart';

class GroupDetailWebView extends ConsumerWidget {
  final Group group;
  final List<Expense> expenses;
  final GroupBalanceSummary summary;
  final List<Person> groupMembers;
  final String currentUserId;
  final ({int currentDay, int totalDays}) tripProgress;

  const GroupDetailWebView({
    super.key,
    required this.group,
    required this.expenses,
    required this.summary,
    required this.groupMembers,
    required this.currentUserId,
    required this.tripProgress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final layout = AdaptiveLayout.of(context);
    final isCompact = layout == LayoutClass.compact;
    final userNetPaise = summary.netBalances[currentUserId] ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Full-bleed cover banner with glass title block and back control
          _buildCoverBanner(context, theme, userNetPaise),

          // 2. Main content area (Two-pane or stacked)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 32,
              vertical: 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: isCompact
                    ? _buildCompactContent(context, theme)
                    : _buildExpandedTwoPane(context, theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverBanner(
    BuildContext context,
    SettlivThemeExtension theme,
    int userNetPaise,
  ) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          // Background cover art
          Positioned.fill(
            child: GroupCoverArt(
              group: group,
              height: 220,
              borderRadius: BorderRadius.zero,
            ),
          ),
          // Subtle gradient overlay for readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.canvas.withValues(alpha: 0.3),
                    theme.canvas.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          // Top Bar with Back Control & Edit Group
          Positioned(
            top: 16,
            left: 24,
            right: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back control: ‹ Groups on desktop
                InkWell(
                  onTap: () => BackNavigation.handleBack(
                    context,
                    currentPath: '/group/${group.id}',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.surface.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.hairline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chevron_left_rounded, size: 20, color: theme.ink),
                            const SizedBox(width: 4),
                            Text(
                              'Groups',
                              style: AppTypography.bodySemiBold.copyWith(
                                color: theme.ink,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Edit group button
                if (!group.isPersonal)
                  InkWell(
                    onTap: () => EditGroupSheet.show(context: context, group: group),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.surface.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.hairline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.settings_outlined, size: 16, color: theme.ink),
                              const SizedBox(width: 6),
                              Text(
                                'Edit',
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: theme.ink,
                                  fontSize: 13,
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
          ),
          // Bottom Title Block
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(
                          fontFamily: AppTypography.fontBrand,
                          fontFamilyFallback: AppTypography.brandFallback,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: theme.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          AvatarStack(
                            people: groupMembers,
                            avatarSize: 22,
                            overlap: 6,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            group.type == GroupType.trip
                                ? 'Trip · Day ${tripProgress.currentDay} of ${tripProgress.totalDays}'
                                : '${groupMembers.length} members',
                            style: AppTypography.caption.copyWith(
                              color: theme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                WebBalanceBadge(paise: userNetPaise),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedTwoPane(BuildContext context, SettlivThemeExtension theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (flex 7): Expenses Table
        Expanded(
          flex: 7,
          child: _buildExpensesTableCard(context, theme),
        ),
        const SizedBox(width: 24),
        // Right Column (flex 5): Balances & Category Donut Chart
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBalancesAndSettlementCard(context, theme),
              const SizedBox(height: 20),
              if (expenses.isNotEmpty)
                CategoryDonutChart(
                  categorySpend: summary.categorySpend,
                  totalSpend: summary.totalSpend,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactContent(BuildContext context, SettlivThemeExtension theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBalancesAndSettlementCard(context, theme),
        const SizedBox(height: 20),
        _buildExpensesTableCard(context, theme),
        const SizedBox(height: 20),
        if (expenses.isNotEmpty)
          CategoryDonutChart(
            categorySpend: summary.categorySpend,
            totalSpend: summary.totalSpend,
          ),
      ],
    );
  }

  Widget _buildExpensesTableCard(BuildContext context, SettlivThemeExtension theme) {
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
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'EXPENSES (${expenses.length})',
                style: AppTypography.eyebrow.copyWith(color: theme.muted),
              ),
              ElevatedButton.icon(
                onPressed: () => context.push('/add'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add expense'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryButtonBg,
                  foregroundColor: theme.primaryButtonText,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (expenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EmptyState(
                title: 'No expenses yet',
                subtitle: 'Add the first expense in this group.',
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FlexColumnWidth(4), // Description
                1: FlexColumnWidth(2.5), // Paid by
                2: FlexColumnWidth(2), // Date
                3: FlexColumnWidth(2.5), // Amount
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.hairline)),
                  ),
                  children: [
                    _buildTableHeaderCell('Description', theme),
                    _buildTableHeaderCell('Paid by', theme),
                    _buildTableHeaderCell('Date', theme),
                    _buildTableHeaderCell('Total', theme, alignRight: true),
                  ],
                ),
                ...expenses.map((exp) {
                  final colors = CategoryPalette.getColors(exp.category, isDark: theme.isDark);

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => ExpenseDetailSheet.show(
                            context: context,
                            expense: exp,
                            onEdit: () {},
                            onDelete: () {},
                          ),
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
                                  style: AppTypography.bodySemiBold.copyWith(
                                    color: theme.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          exp.paidBy == currentUserId ? 'You' : (groupMembers.firstWhere((p) => p.id == exp.paidBy, orElse: () => const Person(id: '', name: 'Someone')).name),
                          style: AppTypography.body.copyWith(color: theme.ink),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          DateFormat('d MMM').format(exp.date),
                          style: AppTypography.caption.copyWith(color: theme.muted),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          CurrencyFormatter.formatPaise(exp.totalPaise),
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
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBalancesAndSettlementCard(BuildContext context, SettlivThemeExtension theme) {
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
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'GROUP BALANCES',
                style: AppTypography.eyebrow.copyWith(color: theme.muted),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => NudgeSheet.show(context: context, group: group),
                    icon: Icon(Icons.notifications_none_rounded, size: 16, color: theme.accent),
                    label: Text('Nudge', style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => SettleSheet.show(context: context, group: group),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: theme.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Settle up', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (summary.debts.isEmpty)
            Text(
              'All settled up in this group!',
              style: AppTypography.body.copyWith(color: theme.emerald),
            )
          else
            ...summary.debts.map((debt) {
              final fromPerson = groupMembers.firstWhere((p) => p.id == debt.fromPersonId, orElse: () => const Person(id: '', name: 'Someone'));
              final toPerson = groupMembers.firstWhere((p) => p.id == debt.toPersonId, orElse: () => const Person(id: '', name: 'Someone'));
              final isCurrentUserDebtor = debt.fromPersonId == currentUserId;
              final isCurrentUserCreditor = debt.toPersonId == currentUserId;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.hairline),
                  ),
                  child: Row(
                    children: [
                      PersonAvatar(person: fromPerson, size: 28),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: theme.muted),
                      const SizedBox(width: 8),
                      PersonAvatar(person: toPerson, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${isCurrentUserDebtor ? 'You owe' : '${fromPerson.name} owes'} ${isCurrentUserCreditor ? 'you' : toPerson.name}',
                          style: AppTypography.caption.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatPaise(debt.amount),
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontWeight: FontWeight.w700,
                          color: isCurrentUserCreditor ? theme.emerald : (isCurrentUserDebtor ? theme.coral : theme.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
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
}
