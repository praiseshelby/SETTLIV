import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
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
    final isDark = context.isDarkMode;

    final Color dotColor;
    final Color bgColor;
    final Color textColor;
    final String label;

    if (paise > 0) {
      dotColor = AppColors.emerald;
      bgColor = isDark ? const Color(0x2E12B48A) : AppColors.emeraldTint;
      textColor = AppColors.emerald;
      final amountStr = CurrencyFormatter.formatPaise(paise, absolute: true);
      label = compact ? '+$amountStr' : 'You are owed $amountStr';
    } else if (paise < 0) {
      dotColor = AppColors.coral;
      bgColor = isDark ? const Color(0x2EF0614F) : AppColors.coralTint;
      textColor = AppColors.coral;
      final amountStr = CurrencyFormatter.formatPaise(paise, absolute: true);
      label = compact ? '-$amountStr' : 'You owe $amountStr';
    } else {
      dotColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
      bgColor = isDark ? const Color(0x1FFFFFFF) : const Color(0x140F1633);
      textColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
      label = 'All settled';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dotColor.withValues(alpha: isDark ? 0.35 : 0.22),
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
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.chip.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
