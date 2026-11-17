import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

class QuickAddBar extends StatelessWidget {
  final ValueChanged<String>? onQuickAddTapped;

  const QuickAddBar({super.key, this.onQuickAddTapped});

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: 'Quick add expense bar',
          child: InkWell(
            onTap: () => onQuickAddTapped?.call(''),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.hairline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF382910)
                          : AppColors.saffronTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bolt_rounded,
                        color: AppColors.saffron,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'dinner 800 with Meera and Kabir',
                      style: AppTypography.body.copyWith(
                        color: theme.tertiary,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF263760)
                          : AppColors.midnightNavy,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Suggestion chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildSuggestionChip(
                context: context,
                text: 'Rent 18,000',
                onTap: () => onQuickAddTapped?.call('Rent 18,000'),
              ),
              const SizedBox(width: 8),
              _buildSuggestionChip(
                context: context,
                text: 'Cab 240 with Kabir',
                onTap: () => onQuickAddTapped?.call('Cab 240 with Kabir'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip({
    required BuildContext context,
    required String text,
    required VoidCallback onTap,
  }) {
    final theme = context.settliv;

    return Semantics(
      button: true,
      label: 'Suggestion: $text',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.raised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 14,
                color: theme.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: AppTypography.caption.copyWith(
                  color: theme.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
