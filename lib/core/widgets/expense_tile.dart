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
  final bool showDivider;

  const ExpenseTile({
    super.key,
    required this.expense,
    this.payer,
    this.group,
    required this.currentUserId,
    required this.onTap,
    this.isHighlighted = false,
    this.showDivider = false,
  });

  @override
  State<ExpenseTile> createState() => _ExpenseTileState();
}

class _ExpenseTileState extends State<ExpenseTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

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
        shareLabel = 'You lent $formatted';
        shareColor = AppColors.emerald;
      } else {
        shareLabel = 'Paid for self';
        shareColor = theme.secondary;
      }
    } else if (userShare > 0) {
      final formatted =
          CurrencyFormatter.formatPaise(userShare, absolute: true);
      shareLabel = 'You owe $formatted';
      shareColor = AppColors.coral;
    } else {
      shareLabel = 'Not involved';
      shareColor = theme.tertiary;
    }

    return Semantics(
      button: true,
      label: '${widget.expense.title}, $subtitle',
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isPressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              color: widget.isHighlighted
                  ? AppColors.sapphire.withValues(alpha: 0.12)
                  : (_isHovered
                      ? (context.isDarkMode
                          ? const Color(0x1AFFFFFF)
                          : const Color(0x0F0F1633))
                      : Colors.transparent),
              child: Column(
                children: [
                  SizedBox(
                    height: 64,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                        // 1. CategoryTile
                        CategoryTile(
                          category: widget.expense.category,
                          size: 40,
                          iconSize: 20,
                        ),
                        const SizedBox(width: 14),

                        // 2. Title and Payer/Group subtitle
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.expense.title,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: AppTypography.caption.copyWith(
                                  color: theme.secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 3. Tabular total amount & Coloured share label
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaise(
                                widget.expense.amount,
                                absolute: true,
                              ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: theme.ink,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              shareLabel,
                              style: AppTypography.caption.copyWith(
                                color: shareColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.showDivider)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 68,
                    endIndent: 16,
                    color: theme.hairline,
                  ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
