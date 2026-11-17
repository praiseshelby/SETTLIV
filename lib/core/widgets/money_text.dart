import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';

enum MoneyColorRole {
  emerald,
  coral,
  ink,
  white,
  secondary,
  auto, // positive = emerald, negative = coral, 0 = secondary
}

class MoneyText extends StatelessWidget {
  final int paise;
  final TextStyle? style;
  final MoneyColorRole colorRole;
  final bool showSign;
  final bool absolute;
  final bool includeDecimalsIfPresent;

  const MoneyText({
    super.key,
    required this.paise,
    this.style,
    this.colorRole = MoneyColorRole.ink,
    this.showSign = false,
    this.absolute = false,
    this.includeDecimalsIfPresent = true,
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle = style ?? AppTypography.bodyMedium;
    final isDark = context.isDarkMode;

    Color color;
    switch (colorRole) {
      case MoneyColorRole.emerald:
        color = isDark ? AppColors.emeraldBright : AppColors.emerald;
        break;
      case MoneyColorRole.coral:
        color = isDark ? AppColors.coralBright : AppColors.coral;
        break;
      case MoneyColorRole.ink:
        color = isDark ? AppColors.darkInk : AppColors.lightInk;
        break;
      case MoneyColorRole.white:
        color = Colors.white;
        break;
      case MoneyColorRole.secondary:
        color = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
        break;
      case MoneyColorRole.auto:
        if (paise > 0) {
          color = isDark ? AppColors.emeraldBright : AppColors.emerald;
        } else if (paise < 0) {
          color = isDark ? AppColors.coralBright : AppColors.coral;
        } else {
          color = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
        }
        break;
    }

    final formattedText = CurrencyFormatter.formatPaise(
      paise,
      showSign: showSign,
      absolute: absolute,
      includeDecimalsIfPresent: includeDecimalsIfPresent,
    );

    return Text(
      formattedText,
      style: defaultStyle.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
