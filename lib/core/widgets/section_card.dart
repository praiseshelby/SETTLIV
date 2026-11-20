import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class SectionCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;

  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(18.0),
    this.onTap,
    this.borderRadius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    Widget content = Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: theme.hairline,
          width: 1.0,
        ),
      ),
      child: Stack(
        children: [
          // 1px inner top highlight (translucent solid white, NOT blur)
          Positioned(
            top: 0,
            left: borderRadius / 2,
            right: borderRadius / 2,
            height: 1.0,
            child: Container(
              color: theme.innerHighlight,
            ),
          ),
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null || trailing != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (title != null)
                        Expanded(
                          child: Text(
                            title!,
                            style: AppTypography.sectionTitle.copyWith(
                              color: theme.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (trailing != null) ...[
                        const SizedBox(width: 8),
                        trailing!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 14.0),
                ],
                child,
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: theme.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: content,
        ),
      );
    }

    return content;
  }
}
