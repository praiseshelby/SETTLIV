import 'package:flutter/material.dart';
import '../../data/models/expense.dart';
import '../../data/models/person.dart';
import '../../data/models/group.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';
import 'category_badge.dart';

class ExpenseTile extends StatefulWidget {
  final Expense expense;
  final Person? payer;
  final Group? group;
  final String currentUserId;
  final VoidCallback onTap;
  final bool isHighlighted;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.payer,
    this.group,
    required this.currentUserId,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  State<ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<ExpenseTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    final payerName = widget.payer?.name ?? 'Someone';
    final groupName = widget.group?.name ?? '';
    final subtitle = groupName.isNotEmpty
        ? 'Paid by $payerName · $groupName'
        : 'Paid by $payerName';

    // Calculate Arjun's personal share in this expense
    final bool isPayer = widget.expense.paidBy == widget.currentUserId;
    final int userShare = widget.expense.shares[widget.currentUserId] ?? 0;

    final String shareLabel;
    final Color shareColor;

    if (isPayer) {
      final int lentAmount = widget.expense.amount - userShare;
      if (lentAmount > 0) {
        final formatted =
            CurrencyFormatter.formatPaise(lentAmount, absolute: true);
        shareLabel = 'you lent $formatted';
        shareColor = isDark ? AppColors.emeraldBright : AppColors.emerald;
      } else {
        shareLabel = 'you paid for yourself';
        shareColor = theme.secondary;
      }
    } else if (userShare > 0) {
      final formatted =
          CurrencyFormatter.formatPaise(userShare, absolute: true);
      shareLabel = 'you owe $formatted';
      shareColor = isDark ? AppColors.coralBright : AppColors.coral;
    } else {
      shareLabel = 'not involved';
      shareColor = theme.tertiary;
    }

    return Semantics(
      button: true,
      label: '${widget.expense.title}, $subtitle',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isHighlighted
                  ? (isDark
                      ? AppColors.emerald.withValues(alpha: 0.18)
                      : AppColors.emeraldTint)
                  : theme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isHighlighted
                    ? AppColors.emerald
                    : theme.hairline,
                width: widget.isHighlighted ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                CategoryBadge(
                  category: widget.expense.category,
                  size: 44,
                  iconSize: 22,
                  borderRadius: 12,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.expense.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: theme.secondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      CurrencyFormatter.formatPaise(widget.expense.amount,
                          absolute: true),
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      shareLabel,
                      style: AppTypography.caption.copyWith(
                        color: shareColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
