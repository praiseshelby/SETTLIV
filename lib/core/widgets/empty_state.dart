import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.raised,
                shape: BoxShape.circle,
                border: Border.all(color: theme.hairline, width: 1.5),
              ),
              child: const Center(
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 36,
                  color: AppColors.teal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                color: theme.ink,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.body.copyWith(
                color: theme.secondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
