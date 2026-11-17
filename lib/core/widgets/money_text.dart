import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

enum MoneyStyle {
  hero,    // 52 / 700
  display, // 40 / 700
  title,   // 20 / 700
  body,    // 15 / 600
  caption, // 13 / 600
}

enum MoneyColorRole {
  auto,    // Positive = emerald, negative = coral, zero = secondary
  ink,     // High contrast ink
  emerald, // Forced positive / owed
  coral,   // Forced negative / owe
  white,   // Clean white
}

class MoneyText extends StatelessWidget {
  final int paise;
  final MoneyStyle style;
  final MoneyColorRole colorRole;
  final bool showSign;
  final bool absolute;

  const MoneyText({
    super.key,
    required this.paise,
    this.style = MoneyStyle.display,
    this.colorRole = MoneyColorRole.auto,
    this.showSign = false,
    this.absolute = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    final String formattedText = CurrencyFormatter.formatPaise(
      paise,
      showSign: showSign,
      absolute: absolute,
    );

    final Color textColor;
    switch (colorRole) {
      case MoneyColorRole.auto:
        if (paise > 0) {
          textColor = AppColors.emerald;
        } else if (paise < 0) {
          textColor = AppColors.coral;
        } else {
          textColor = theme.secondary;
        }
        break;
      case MoneyColorRole.ink:
        textColor = theme.ink;
        break;
      case MoneyColorRole.emerald:
        textColor = AppColors.emerald;
        break;
      case MoneyColorRole.coral:
        textColor = AppColors.coral;
        break;
      case MoneyColorRole.white:
        textColor = Colors.white;
        break;
    }

    final TextStyle baseStyle;
    switch (style) {
      case MoneyStyle.hero:
        baseStyle = AppTypography.heroMoney;
        break;
      case MoneyStyle.display:
        baseStyle = AppTypography.displayMoney;
        break;
      case MoneyStyle.title:
        baseStyle = AppTypography.titleMedium;
        break;
      case MoneyStyle.body:
        baseStyle = AppTypography.bodyMedium;
        break;
      case MoneyStyle.caption:
        baseStyle = AppTypography.caption;
        break;
    }

    return Text(
      formattedText,
      style: baseStyle.copyWith(
        color: textColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
