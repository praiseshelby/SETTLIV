import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../layout/adaptive_layout.dart';
import '../navigation/back_navigation.dart';
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
    final isCompact = AdaptiveLayout.isCompact(context);

    String? currentPath;
    try {
      currentPath = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      currentPath = null;
    }

    final hasParent = currentPath != null && BackNavigation.getParentRoute(currentPath) != null;
    final shouldShowBack = onBack != null || hasParent;
    final parentLabel = currentPath != null ? BackNavigation.getParentLabel(currentPath) : 'Back';

    Widget? backWidget;
    if (shouldShowBack) {
      void backAction() => BackNavigation.handleBack(
            context,
            currentPath: currentPath,
            customOnBack: onBack,
          );

      if (!isCompact) {
        // Desktop / Expanded / Medium: arrow + parent label (e.g. "‹ Groups")
        backWidget = Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Semantics(
            button: true,
            label: 'Back to $parentLabel',
            child: InkWell(
              onTap: backAction,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.hairline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      color: theme.ink,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      parentLabel,
                      style: AppTypography.caption.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        // Compact / Mobile: circular glass back button
        backWidget = Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Semantics(
            button: true,
            label: 'Back to $parentLabel',
            child: InkWell(
              onTap: backAction,
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
        );
      }
    }

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
          // Title row with optional leading, back button, & actions
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ] else if (backWidget != null) ...[
                backWidget,
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
