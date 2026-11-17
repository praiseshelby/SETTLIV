import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum TextActionButtonVariant {
  cobalt,
  destructive,
  secondary,
}

class TextActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final TextActionButtonVariant variant;
  final Widget? leading;

  const TextActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = TextActionButtonVariant.cobalt,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    final Color color;
    switch (variant) {
      case TextActionButtonVariant.cobalt:
        color = isDark ? const Color(0xFF7E9DFF) : AppColors.cobaltGlow;
        break;
      case TextActionButtonVariant.destructive:
        color = isDark ? AppColors.coralBright : AppColors.coral;
        break;
      case TextActionButtonVariant.secondary:
        color = theme.secondary;
        break;
    }

    return Semantics(
      button: true,
      label: label,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: AppTypography.button.copyWith(
                  color: color,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
