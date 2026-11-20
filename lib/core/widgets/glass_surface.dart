import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum GlassLevel {
  level1, // Sub-cards, inner input containers, chips
  level2, // Standard cards, group cards, composer
  level3, // Hero card, sheets
}

class GlassSurface extends StatelessWidget {
  final Widget child;
  final GlassLevel level;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool enableBlur;
  final Color? customFill;
  final Border? customBorder;

  const GlassSurface({
    super.key,
    required this.child,
    this.level = GlassLevel.level2,
    this.borderRadius,
    this.padding,
    this.margin,
    this.onTap,
    this.enableBlur = false,
    this.customFill,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final radius = borderRadius ?? (level == GlassLevel.level1 ? 16.0 : 24.0);

    final Color fillColor = customFill ??
        (level == GlassLevel.level1 ? theme.raised : theme.surface);

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );

    content = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: content,
    );

    Widget box = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: customBorder ?? Border.all(color: theme.hairline, width: 1.0),
      ),
      child: content,
    );

    if (onTap != null) {
      box = Material(
        color: theme.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          mouseCursor: SystemMouseCursors.click,
          child: box,
        ),
      );
    }

    return RepaintBoundary(child: box);
  }
}
