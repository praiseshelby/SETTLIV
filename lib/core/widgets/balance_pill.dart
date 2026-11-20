import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

class BalancePill extends StatelessWidget {
  final int paise; // in paise
  final bool compact;

  const BalancePill({
    super.key,
    required this.paise,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    final Color dotColor;
    final Color bgColor;
    final Color textColor;
    final String label;

    if (paise > 0) {
      dotColor = theme.emerald;
      bgColor = theme.emeraldTint;
      textColor = theme.textEmerald;
      final amountStr = CurrencyFormatter.formatPaise(paise, absolute: true);
      label = compact ? '+$amountStr' : 'Owed $amountStr';
    } else if (paise < 0) {
      dotColor = theme.coral;
      bgColor = theme.coralTint;
      textColor = theme.textCoral;
      final amountStr = CurrencyFormatter.formatPaise(paise, absolute: true);
      label = compact ? '-$amountStr' : 'You owe $amountStr';
    } else {
      dotColor = theme.muted;
      bgColor = theme.raised;
      textColor = theme.muted;
      label = 'All settled';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dotColor.withValues(alpha: theme.isDark ? 0.35 : 0.20),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          // Never ellipsize or truncate money!
          Text(
            label,
            softWrap: false,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
