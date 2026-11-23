import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/currency_formatter.dart';

/// Web-specific plain right-aligned tabular balance amount with small caption.
/// Follows rule: no filled pill/capsule badges anywhere on Web.
class WebBalanceBadge extends StatelessWidget {
  final int paise;
  final CrossAxisAlignment alignment;

  const WebBalanceBadge({
    super.key,
    required this.paise,
    this.alignment = CrossAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final Color textColor;
    final String caption;

    if (paise > 0) {
      textColor = theme.emerald;
      caption = 'owed to you';
    } else if (paise < 0) {
      textColor = theme.coral;
      caption = 'you owe';
    } else {
      textColor = theme.muted;
      caption = 'settled';
    }

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          CurrencyFormatter.formatPaise(paise.abs(), showSign: false),
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: textColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
