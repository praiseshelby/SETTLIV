import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/motion_tokens.dart';

/// Web Glass Card:
/// - 1px gradient hairline (brighter top-left, dissolving bottom-right)
/// - Inner top highlight (0.5px white 12% in light, 6% in dark)
/// - Violet ambient shadow:
///   * Light: 0 12px 32px rgba(108,71,255,0.06)
///   * Dark: 0 16px 40px rgba(0,0,0,0.55), plus 0 0 24px rgba(124,92,255,0.12) on hover
/// - Desktop hover: lifts 2px and subtly brightens border gradient near pointer
class WebGlassCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? customFill;
  final bool enableHover;
  final bool enableBlur;

  const WebGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.onTap,
    this.customFill,
    this.enableHover = true,
    this.enableBlur = false,
  });

  @override
  State<WebGlassCard> createState() => _WebGlassCardState();
}

class _WebGlassCardState extends State<WebGlassCard> {
  bool _isHovered = false;
  final ValueNotifier<Offset?> _localPointer = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    _localPointer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 720;
    final isLite = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final canHover = widget.enableHover && isDesktop && !isLite;

    final radius = widget.borderRadius;
    final fillColor = widget.customFill ?? theme.surface;

    // Ambient Shadows
    final List<BoxShadow> shadows = [
      if (theme.isDark)
        BoxShadow(
          color: theme.cardAmbientShadow,
          blurRadius: 40,
          offset: const Offset(0, 16),
        )
      else
        BoxShadow(
          color: theme.cardAmbientShadow,
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      if (theme.isDark && _isHovered && canHover)
        BoxShadow(
          color: theme.cardHoverGlow,
          blurRadius: 24,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
    ];

    Widget body = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        children: [
          // Background fill
          Container(
            color: fillColor,
            padding: widget.padding ?? const EdgeInsets.all(20.0),
            child: widget.child,
          ),

          // 0.5px Inner top highlight
          Positioned(
            top: 0,
            left: radius * 0.5,
            right: radius * 0.5,
            height: 0.5,
            child: Container(
              color: theme.white.withValues(
                alpha: theme.isDark ? 0.06 : 0.12,
              ),
            ),
          ),

          // Localized pointer border highlight
          if (canHover)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<Offset?>(
                  valueListenable: _localPointer,
                  builder: (context, pointer, _) {
                    return CustomPaint(
                      painter: _GradientBorderPainter(
                        theme: theme,
                        borderRadius: radius,
                        pointerOffset: pointer,
                        isHovered: _isHovered,
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GradientBorderPainter(
                    theme: theme,
                    borderRadius: radius,
                    pointerOffset: null,
                    isHovered: false,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.onTap != null) {
      body = Material(
        color: theme.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(radius),
          mouseCursor: SystemMouseCursors.click,
          child: body,
        ),
      );
    }

    final animatedBox = AnimatedContainer(
      duration: MotionTokens.durationFast,
      curve: MotionTokens.curveStandard,
      margin: widget.margin,
      transform: Matrix4.translationValues(
        0,
        (canHover && _isHovered) ? -2.0 : 0.0,
        0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: body,
    );

    if (canHover) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) {
          setState(() => _isHovered = false);
          _localPointer.value = null;
        },
        onHover: (e) {
          _localPointer.value = e.localPosition;
        },
        child: animatedBox,
      );
    }

    return animatedBox;
  }
}

/// 1px gradient hairline: brighter top-left, dissolving bottom-right
/// Subtly brightens along pointer position on hover
class _GradientBorderPainter extends CustomPainter {
  final SettlivThemeExtension theme;
  final double borderRadius;
  final Offset? pointerOffset;
  final bool isHovered;

  const _GradientBorderPainter({
    required this.theme,
    required this.borderRadius,
    required this.pointerOffset,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final rect = Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // Base gradient: brighter top-left, dissolving bottom-right
    final startAlpha = theme.isDark ? 0.45 : 0.65;
    final endAlpha = theme.isDark ? 0.08 : 0.15;

    final baseShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        theme.hairline.withValues(alpha: startAlpha),
        theme.hairline.withValues(alpha: endAlpha),
      ],
      stops: const [0.0, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = baseShader;

    canvas.drawRRect(rrect, paint);

    // Localized pointer highlight
    if (isHovered && pointerOffset != null) {
      final glowRect = Rect.fromCircle(center: pointerOffset!, radius: 100);
      final highlightShader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          theme.accent.withValues(alpha: theme.isDark ? 0.35 : 0.25),
          theme.transparent,
        ],
      ).createShader(glowRect);

      final highlightPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = highlightShader;

      canvas.drawRRect(rrect, highlightPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.isHovered != isHovered ||
        oldDelegate.pointerOffset != pointerOffset;
  }
}
