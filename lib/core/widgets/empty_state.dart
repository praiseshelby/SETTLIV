import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'glass_surface.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    this.icon = Icons.receipt_long_rounded,
    required this.title,
    this.subtitle,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final effectiveText = subtitle ?? message ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassSurface(
              level: GlassLevel.level2,
              borderRadius: 28,
              padding: const EdgeInsets.all(22),
              child: Icon(
                icon,
                size: 36,
                color: theme.isDark ? theme.ink : theme.navy,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                color: theme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (effectiveText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                effectiveText,
                style: AppTypography.body.copyWith(
                  color: theme.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 22),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
