import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'glass_surface.dart';

class ScreenHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const ScreenHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.leading,
    this.actions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eyebrow if present
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: AppTypography.eyebrow.copyWith(
                color: theme.muted,
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Title row with optional leading & actions
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ] else if (onBack != null) ...[
                Semantics(
                  button: true,
                  label: 'Back',
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(999),
                    child: GlassSurface(
                      level: GlassLevel.level1,
                      borderRadius: 999,
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: theme.ink,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.screenTitle.copyWith(
                    color: theme.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            subtitle!,
          ],
        ],
      ),
    );
  }
}
