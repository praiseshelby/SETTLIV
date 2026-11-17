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

    final Color bgColor;
    final Color textColor;
    final String label;

    if (paise > 0) {
      bgColor = isDark ? const Color(0xFF102E24) : AppColors.emeraldTint;
      textColor = isDark ? AppColors.emeraldBright : AppColors.emerald;
      final amountStr = CurrencyFormatter.formatPaise(paise, absolute: true);
      label = compact ? '+$amountStr' : 'You are owed $amountStr';
    } else if (paise < 0) {
      bgColor = isDark ? const Color(0xFF351A18) : AppColors.coralTint;
      textColor = isDark ? AppColors.coralBright : AppColors.coral;
      final amountStr = CurrencyFormatter.formatPaise(paise, absolute: true);
      label = compact ? '-$amountStr' : 'You owe $amountStr';
    } else {
      bgColor = isDark ? const Color(0xFF1E283A) : const Color(0xFFECEAE3);
      textColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
      label = 'All settled';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
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
    );
  }
}
