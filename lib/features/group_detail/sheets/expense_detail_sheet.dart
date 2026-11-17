import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/category_badge.dart';
import '../../../core/widgets/glass_sheet_scaffold.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/gradient_primary_button.dart';
import '../../../core/widgets/person_avatar.dart';
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
    GlassSheetScaffold.show(
      context: context,
      title: 'Expense Details',
      child: ExpenseDetailSheet(
        expense: expense,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
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
        userShareColor = AppColors.emerald;
      } else {
        userShareSummary = 'You paid for yourself entirely';
        userShareColor = theme.secondary;
      }
    } else if (userShare > 0) {
      userShareSummary =
          'Your share is ${CurrencyFormatter.formatPaise(userShare, absolute: true)} (you owe ${payer?.name ?? 'payer'})';
      userShareColor = AppColors.coral;
    } else {
      userShareSummary = 'You are not involved in this expense';
      userShareColor = theme.secondary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category + Title + Date
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryTile(
              category: expense.category,
              size: 48,
              iconSize: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: AppTypography.titleLarge.copyWith(
                      color: theme.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group?.name ?? 'Group'} · ${DateFormatter.formatFull(expense.date)}',
                    style: AppTypography.caption.copyWith(
                      color: theme.secondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Giant Amount Card (Glass Level 1)
        GlassSurface(
          level: GlassLevel.level1,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          borderRadius: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total amount',
                style: AppTypography.body.copyWith(
                  color: theme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                CurrencyFormatter.formatPaise(expense.amount, absolute: true),
                style: AppTypography.displayMoney.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: theme.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Paid by row
        GlassSurface(
          level: GlassLevel.level1,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 18,
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
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      isPayer ? 'You paid this upfront' : 'Paid for the group',
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.hairline,
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

        // Per-person share list
        Text(
          'SPLIT BREAKDOWN',
          style: AppTypography.sectionLabel.copyWith(
            color: theme.secondary,
            letterSpacing: 0.8,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        GlassSurface(
          level: GlassLevel.level1,
          padding: EdgeInsets.zero,
          borderRadius: 20,
          child: Column(
            children: [
              for (final entry in expense.shares.entries) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatPaise(entry.value,
                            absolute: true),
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.key != expense.shares.keys.last)
                  Divider(
                    height: 1,
                    color: theme.hairline,
                    indent: 54,
                    endIndent: 16,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // User share summary line
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: userShareColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: userShareColor.withValues(alpha: 0.22),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
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
        const SizedBox(height: 22),

        // Actions: Delete & Edit
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.coral,
                  side: BorderSide(
                    color: AppColors.coral.withValues(alpha: 0.35),
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text(
                  'Delete',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientPrimaryButton(
                label: 'Edit details',
                height: 48,
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
