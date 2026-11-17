import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum GlassLevel {
  level1, // Sub-cards, inner input containers, chips (sigma 16, lighter fill)
  level2, // Standard cards, group cards, composer (sigma 22)
  level3, // Hero card, bottom sheets, sticky bars (sigma 26, specular highlight, soft shadow)
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
    this.enableBlur = true,
    this.customFill,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final radius = borderRadius ?? (level == GlassLevel.level1 ? 18.0 : 28.0);

    final double blurSigma;
    final Color fillColor;
    final List<BoxShadow> shadows;

    switch (level) {
      case GlassLevel.level1:
        blurSigma = 16.0;
        fillColor = customFill ??
            (isDark ? const Color(0x1AFFFFFF) : const Color(0x99FFFFFF)); // ~60%
        shadows = [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ];
        break;
      case GlassLevel.level2:
        blurSigma = 22.0;
        fillColor = customFill ??
            (isDark ? const Color(0x24FFFFFF) : const Color(0xB8FFFFFF)); // ~72%
        shadows = [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF0E1A3A))
                .withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 28,
            offset: const Offset(0, 10),
            spreadRadius: -4,
          ),
        ];
        break;
      case GlassLevel.level3:
        blurSigma = 26.0;
        fillColor = customFill ??
            (isDark ? const Color(0x30FFFFFF) : const Color(0xD9FFFFFF)); // ~85%
        shadows = [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF0E1A3A))
                .withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 40,
            offset: const Offset(0, 18),
            spreadRadius: -10,
          ),
        ];
        break;
    }

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );

    if (enableBlur) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: content,
        ),
      );
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    Widget glassBox = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: customBorder ??
            Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.65),
              width: 1.0,
            ),
        boxShadow: shadows,
      ),
      child: content,
    );

    if (onTap != null) {
      glassBox = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          mouseCursor: SystemMouseCursors.click,
          child: glassBox,
        ),
      );
    }

    return RepaintBoundary(child: glassBox);
  }
}
