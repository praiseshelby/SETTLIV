import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

enum MoneyStyle {
  hero,    // 42 / 800
  display, // 32 / 700
  title,   // 20 / 700
  body,    // 15 / 600
  caption, // 13 / 600
}

enum MoneyColorRole {
  auto,    // Positive = textEmerald, negative = textCoral, zero = muted
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
          textColor = theme.textEmerald;
        } else if (paise < 0) {
          textColor = theme.textCoral;
        } else {
          textColor = theme.muted;
        }
        break;
      case MoneyColorRole.ink:
        textColor = theme.ink;
        break;
      case MoneyColorRole.emerald:
        textColor = theme.textEmerald;
        break;
      case MoneyColorRole.coral:
        textColor = theme.textCoral;
        break;
      case MoneyColorRole.white:
        textColor = theme.white;
        break;
    }

    final TextStyle baseStyle;
    switch (style) {
      case MoneyStyle.hero:
        baseStyle = AppTypography.moneyHero;
        break;
      case MoneyStyle.display:
        baseStyle = AppTypography.moneyLarge;
        break;
      case MoneyStyle.title:
        baseStyle = AppTypography.moneyMedium;
        break;
      case MoneyStyle.body:
        baseStyle = AppTypography.moneyRegular;
        break;
      case MoneyStyle.caption:
        baseStyle = AppTypography.caption;
        break;
    }

    // Money text must NEVER be truncated or clipped anywhere!
    return Text(
      formattedText,
      softWrap: false,
      style: baseStyle.copyWith(
        color: textColor,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
