import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/category_badge.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../core/widgets/text_action_button.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class ExpenseDetailSheet extends ConsumerWidget {
  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ExpenseDetailSheet({
    super.key,
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  static void show({
    required BuildContext context,
    required Expense expense,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    SheetScaffold.show(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ExpenseDetailSheet(
        expense: expense,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;
    final repo = ref.watch(appRepositoryProvider);
    final payer = repo.getPerson(expense.paidBy);
    final group = repo.getGroup(expense.groupId);
    final currentUserId = repo.currentUserId;

    final userShare = expense.shares[currentUserId] ?? 0;
    final isPayer = expense.paidBy == currentUserId;

    final String userShareSummary;
    final Color userShareColor;

    if (isPayer) {
      final lent = expense.amount - userShare;
      if (lent > 0) {
        userShareSummary =
            'You paid ${CurrencyFormatter.formatPaise(expense.amount, absolute: true)} and lent ${CurrencyFormatter.formatPaise(lent, absolute: true)}';
        userShareColor = isDark ? AppColors.emeraldBright : AppColors.emerald;
      } else {
        userShareSummary = 'You paid for yourself entirely';
        userShareColor = theme.secondary;
      }
    } else if (userShare > 0) {
      userShareSummary =
          'Your share is ${CurrencyFormatter.formatPaise(userShare, absolute: true)} (you owe ${payer?.name ?? 'payer'})';
      userShareColor = isDark ? AppColors.coralBright : AppColors.coral;
    } else {
      userShareSummary = 'You are not involved in this expense';
      userShareColor = theme.secondary;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryBadge(
                category: expense.category,
                size: 52,
                iconSize: 26,
                borderRadius: 16,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.title,
                      style: AppTypography.titleLarge.copyWith(color: theme.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group?.name ?? 'Group'} · ${DateFormatter.formatFull(expense.date)}',
                      style: AppTypography.caption.copyWith(color: theme.secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Giant amount display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: theme.raised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.hairline),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total amount',
                  style: AppTypography.body.copyWith(color: theme.secondary),
                ),
                Text(
                  CurrencyFormatter.formatPaise(expense.amount, absolute: true),
                  style: AppTypography.displayMoney.copyWith(
                    fontSize: 28,
                    color: theme.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Paid by info card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.hairline),
            ),
            child: Row(
              children: [
                PersonAvatar(
                  person: payer,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paid by ${payer?.name ?? 'Someone'}',
                        style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                      ),
                      Text(
                        isPayer ? 'You paid this upfront' : 'Paid for the group',
                        style: AppTypography.caption.copyWith(color: theme.secondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.raised,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    expense.splitMode.label,
                    style: AppTypography.caption.copyWith(
                      color: theme.secondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Member share list
          Text(
            'Split breakdown',
            style: AppTypography.sectionHeader.copyWith(
              color: theme.ink,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.hairline),
            ),
            child: Column(
              children: [
                for (final entry in expense.shares.entries) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        PersonAvatar(
                          person: repo.getPerson(entry.key),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            entry.key == currentUserId
                                ? 'You (${repo.getPerson(entry.key)?.name ?? ''})'
                                : repo.getPerson(entry.key)?.name ?? 'Member',
                            style: AppTypography.body.copyWith(
                              color: theme.ink,
                              fontWeight: entry.key == currentUserId
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(entry.value, absolute: true),
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.key != expense.shares.keys.last)
                    Divider(height: 1, color: theme.hairline, indent: 52),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          // "Your share" summary line
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: userShareColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: userShareColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userShareSummary,
                    style: AppTypography.caption.copyWith(
                      color: userShareColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Actions: Delete & Edit
          Row(
            children: [
              Expanded(
                child: TextActionButton(
                  label: 'Delete expense',
                  variant: TextActionButtonVariant.destructive,
                  leading: const Icon(Icons.delete_outline_rounded, size: 18),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDelete();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Edit details',
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
