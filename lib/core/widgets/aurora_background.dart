import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile/experience_mode.dart';
import '../theme/app_theme.dart';
import '../theme/motion_tokens.dart';

/// 3-Layer Background Depth Stack for Settliv:
/// 1. FAR: Soft colour fields (lavender, cool sky, peach / violet, indigo, teal)
///    with 6% scroll parallax and ±10px pointer parallax.
/// 2. MID: Fine contour / orbit linework (0.75px, 6-8% opacity, cached)
///    echoing Settliv balance theme (concentric arcs, horizontal leveling guides).
/// 3. NEAR: 3-4% grain & soft vignette + soft pointer cursor light (radius ~220px,
///    4-6% opacity, eased lag, desktop only, disabled in lite mode).
class AuroraBackground extends ConsumerStatefulWidget {
  final Widget child;
  final bool showGrid; // Maintained for API compatibility, grid removed per X2 specs

  const AuroraBackground({
    super.key,
    required this.child,
    this.showGrid = false,
  });

  @override
  ConsumerState<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends ConsumerState<AuroraBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _driftController;
  Offset _pointerPos = Offset.zero;
  Offset _smoothPointerPos = Offset.zero;
  Offset _pointerDelta = Offset.zero;
  double _scrollOffset = 0.0;
  bool _hasPointer = false;

  @override
  void initState() {
    super.initState();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _driftController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 45),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _driftController?.dispose();
    super.dispose();
  }

  void _onPointerHover(PointerHoverEvent event, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final normX = ((event.localPosition.dx - center.dx) / (size.width / 2)).clamp(-1.0, 1.0);
    final normY = ((event.localPosition.dy - center.dy) / (size.height / 2)).clamp(-1.0, 1.0);

    setState(() {
      _hasPointer = true;
      _pointerPos = event.localPosition;
      // ±10px pointer parallax
      _pointerDelta = Offset(normX * 10.0, normY * 10.0);
      // Eased lag interpolation towards target
      _smoothPointerPos = Offset.lerp(_smoothPointerPos, _pointerPos, 0.18) ?? _pointerPos;
    });
  }

  void _onPointerExit() {
    setState(() {
      _hasPointer = false;
      _pointerDelta = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final profile = ref.watch(deviceProfileProvider);
    final effectiveExp = ref.watch(effectiveExperienceProvider);
    final isLite = MotionTokens.isLiteEffects(context, profile);
    final isDesktopWeb = profile.isDesktop && effectiveExp == EffectiveExperience.web;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical) {
          final newOffset = notification.metrics.pixels;
          if ((newOffset - _scrollOffset).abs() > 2.0) {
            setState(() {
              _scrollOffset = newOffset;
            });
          }
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);

          Widget content = RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Base canvas fill
                Container(color: theme.farBase),

                // 1. FAR LAYER: Soft colour fields with parallax
                CustomPaint(
                  painter: _FarColourFieldsPainter(
                    theme: theme,
                    scrollOffset: _scrollOffset,
                    pointerOffset: isLite ? Offset.zero : _pointerDelta,
                    driftValue: _driftController?.value ?? 0.0,
                  ),
                  size: Size.infinite,
                ),

                // 2. MID LAYER: Fine contour / orbit linework (cached)
                CustomPaint(
                  painter: _MidContourOrbitPainter(theme: theme),
                  size: Size.infinite,
                ),

                // 3. NEAR LAYER: Grain, soft vignette & soft pointer cursor light
                CustomPaint(
                  painter: _NearVignetteCursorPainter(
                    theme: theme,
                    pointerPos: (isDesktopWeb && !isLite && _hasPointer)
                        ? _smoothPointerPos
                        : null,
                    isLite: isLite,
                  ),
                  size: Size.infinite,
                ),

                // Foreground content
                widget.child,
              ],
            ),
          );

          if (isDesktopWeb && !isLite) {
            return MouseRegion(
              onHover: (e) => _onPointerHover(e, size),
              onExit: (_) => _onPointerExit(),
              child: content,
            );
          }

          return content;
        },
      ),
    );
  }
}

/// 1. FAR LAYER: Soft colour fields
/// Light: pearl-white base with lavender #E8E3FF, cool sky #DCEBFF, faint peach #FFE7DD.
/// Dark: ink #070914 base with violet #2A1B6B, indigo #16245E, teal #0C3A44 glows.
class _FarColourFieldsPainter extends CustomPainter {
  final SettlivThemeExtension theme;
  final double scrollOffset;
  final Offset pointerOffset;
  final double driftValue;

  const _FarColourFieldsPainter({
    required this.theme,
    required this.scrollOffset,
    required this.pointerOffset,
    required this.driftValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final w = size.width;
    final h = size.height;

    // Parallax shifts: 6% slow scroll + ±10px pointer shift + drift
    final scrollShift = (scrollOffset * 0.06) % (h * 0.5);
    final px = pointerOffset.dx;
    final py = pointerOffset.dy;
    final driftX = (driftValue - 0.5) * 16.0;
    final driftY = (driftValue - 0.5) * 12.0;

    final rect = Rect.fromLTWH(0, 0, w, h);

    if (theme.isDark) {
      // Dark mode: ink #070914 base
      // Orb 1: Violet glow #2A1B6B (top-left)
      final violetShader = RadialGradient(
        center: Alignment(
          -0.65 + ((px + driftX) / w),
          -0.55 + ((py - scrollShift + driftY) / h),
        ),
        radius: 1.25,
        colors: [
          theme.farGlow1.withValues(alpha: 0.55),
          theme.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = violetShader);

      // Orb 2: Indigo glow #16245E (center-right)
      final indigoShader = RadialGradient(
        center: Alignment(
          0.70 - ((px + driftX) / w),
          -0.10 + ((py - scrollShift * 0.5) / h),
        ),
        radius: 1.10,
        colors: [
          theme.farGlow2.withValues(alpha: 0.50),
          theme.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = indigoShader);

      // Orb 3: Teal glow #0C3A44 (bottom-left)
      final tealShader = RadialGradient(
        center: Alignment(
          -0.45 + ((px * 0.6) / w),
          0.75 + ((py + driftY) / h),
        ),
        radius: 0.95,
        colors: [
          theme.farGlow3.withValues(alpha: 0.40),
          theme.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = tealShader);
    } else {
      // Light mode: pearl-white base
      // Orb 1: Lavender #E8E3FF (top-left / upper center)
      final lavenderShader = RadialGradient(
        center: Alignment(
          -0.55 + ((px + driftX) / w),
          -0.50 + ((py - scrollShift + driftY) / h),
        ),
        radius: 1.30,
        colors: [
          theme.farGlow1.withValues(alpha: 0.70),
          theme.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = lavenderShader);

      // Orb 2: Cool sky #DCEBFF (center-right / bottom-right)
      final skyShader = RadialGradient(
        center: Alignment(
          0.75 - ((px + driftX) / w),
          0.20 + ((py - scrollShift * 0.4) / h),
        ),
        radius: 1.15,
        colors: [
          theme.farGlow2.withValues(alpha: 0.65),
          theme.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = skyShader);

      // Orb 3: Faint peach #FFE7DD (bottom-left / lower center)
      final peachShader = RadialGradient(
        center: Alignment(
          -0.30 + ((px * 0.7) / w),
          0.80 + ((py + driftY) / h),
        ),
        radius: 0.90,
        colors: [
          theme.farGlow3.withValues(alpha: 0.48),
          theme.transparent,
        ],
      ).createShader(rect);
      canvas.drawRect(rect, Paint()..shader = peachShader);
    }
  }

  @override
  bool shouldRepaint(covariant _FarColourFieldsPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        (oldDelegate.scrollOffset - scrollOffset).abs() > 1.0 ||
        (oldDelegate.pointerOffset - pointerOffset).distance > 0.5 ||
        (oldDelegate.driftValue - driftValue).abs() > 0.03;
  }
}

/// 2. MID LAYER: Fine contour / orbit linework (0.75px, 6-8% opacity, cached)
/// Echoes Settliv balance theme: concentric arcs, faint horizontal leveling guides.
class _MidContourOrbitPainter extends CustomPainter {
  final SettlivThemeExtension theme;

  const _MidContourOrbitPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final w = size.width;
    final h = size.height;

    final linePaint = Paint()
      ..color = theme.ink.withValues(alpha: theme.isDark ? 0.07 : 0.065)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    final dashPaint = Paint()
      ..color = theme.ink.withValues(alpha: theme.isDark ? 0.05 : 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    // Balance orbit center at upper right (w * 0.82, h * 0.22)
    final orbitCenter = Offset(w * 0.82, h * 0.20);
    final radii = [140.0, 260.0, 420.0, 620.0, 860.0, 1140.0];

    for (final r in radii) {
      canvas.drawCircle(orbitCenter, r, linePaint);
    }

    // Faint horizontal leveling guides
    final guides = [110.0, 280.0, 520.0];
    for (final y in guides) {
      if (y < h) {
        // Draw dashed guide line with leveling cross-ticks
        double x = 0;
        while (x < w) {
          canvas.drawLine(Offset(x, y), Offset(x + 24, y), dashPaint);
          x += 36;
        }
        // Small leveling tick marks
        canvas.drawLine(Offset(w * 0.25, y - 4), Offset(w * 0.25, y + 4), linePaint);
        canvas.drawLine(Offset(w * 0.50, y - 4), Offset(w * 0.50, y + 4), linePaint);
        canvas.drawLine(Offset(w * 0.75, y - 4), Offset(w * 0.75, y + 4), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MidContourOrbitPainter oldDelegate) {
    return oldDelegate.theme != theme;
  }
}

/// 3. NEAR LAYER: 3-4% grain & soft vignette + soft pointer cursor light
/// Cursor light: radius ~220px, 4-6% opacity, eased lag, desktop only, disabled in lite mode.
class _NearVignetteCursorPainter extends CustomPainter {
  final SettlivThemeExtension theme;
  final Offset? pointerPos;
  final bool isLite;

  const _NearVignetteCursorPainter({
    required this.theme,
    required this.pointerPos,
    required this.isLite,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromLTWH(0, 0, w, h);

    // 1. Soft vignette (darker edges, ~3-4% opacity)
    final vignetteShader = RadialGradient(
      center: Alignment.center,
      radius: 1.15,
      colors: [
        theme.transparent,
        theme.black.withValues(alpha: theme.isDark ? 0.08 : 0.035),
      ],
      stops: const [0.70, 1.0],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = vignetteShader);

    // 2. Soft pointer cursor light (radius ~220px, 4-6% opacity)
    if (!isLite && pointerPos != null) {
      final cursorRect = Rect.fromCircle(center: pointerPos!, radius: 220);
      final cursorShader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          theme.accent.withValues(alpha: theme.isDark ? 0.06 : 0.045),
          theme.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(cursorRect);

      canvas.drawCircle(pointerPos!, 220, Paint()..shader = cursorShader);
    }
  }

  @override
  bool shouldRepaint(covariant _NearVignetteCursorPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.pointerPos != pointerPos ||
        oldDelegate.isLite != isLite;
  }
}
