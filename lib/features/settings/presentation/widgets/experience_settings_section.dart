import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/profile/experience_mode.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/experience_transition_overlay.dart';

class ExperienceSettingsSection extends ConsumerStatefulWidget {
  final bool isHighlighted;

  const ExperienceSettingsSection({
    super.key,
    this.isHighlighted = false,
  });

  @override
  ConsumerState<ExperienceSettingsSection> createState() =>
      _ExperienceSettingsSectionState();
}

class _ExperienceSettingsSectionState extends ConsumerState<ExperienceSettingsSection>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _orbitController;
  final GlobalKey _webTileKey = GlobalKey();
  final GlobalKey _appTileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 60),
    ]).animate(_pulseController);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    if (widget.isHighlighted) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant ExperienceSettingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final effective = ref.watch(effectiveExperienceProvider);
    final profile = ref.watch(deviceProfileProvider);
    final isDesktop = profile.isDesktop;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final pulseVal = _pulseAnimation.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: pulseVal > 0.01
                ? [
                    BoxShadow(
                      color: theme.accent.withValues(alpha: 0.35 * pulseVal),
                      blurRadius: 18 * pulseVal,
                      spreadRadius: 2 * pulseVal,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Eyebrow with small accent bar
          Row(
            children: [
              Container(
                width: 3.5,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'COMPATIBILITY PREVIEW',
                style: AppTypography.eyebrow.copyWith(
                  color: theme.muted,
                  letterSpacing: 0.8,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Three Layout Tiles
          _buildLayoutTiles(context, theme, effective, isDesktop),
          const SizedBox(height: 16),

          // 3. Compact Preview Notice Strip (~96px tall)
          _buildPreviewNoticeStrip(theme),
        ],
      ),
    );
  }

  Widget _buildLayoutTiles(
    BuildContext context,
    SettlivThemeExtension theme,
    EffectiveExperience effective,
    bool isDesktop,
  ) {
    final isWebActive = effective == EffectiveExperience.web;
    final isAppActive = effective == EffectiveExperience.app;

    if (isDesktop) {
      // On PC: Selectable = "PC website" (Web) & "Mobile app" (App)
      // Reference = "Mobile web" (muted, ~70% width, dashed border, caption "Phones only")
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 10,
            child: Container(
              key: _webTileKey,
              child: _buildSelectableTile(
                title: 'PC website',
                subtitle: 'Shipped to: PC users',
                isSelected: isWebActive,
                painter: PcWebsiteThumbnailPainter(color: isWebActive ? theme.accent : theme.muted),
                theme: theme,
                onTap: () => _switchMode(
                  ExperienceMode.web,
                  tileKey: _webTileKey,
                  targetLabel: 'PC website',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 7,
            child: _buildReferenceTile(
              title: 'Mobile web',
              caption: 'Phones only',
              painter: MobileWebThumbnailPainter(color: theme.muted.withValues(alpha: 0.5)),
              theme: theme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 10,
            child: Container(
              key: _appTileKey,
              child: _buildSelectableTile(
                title: 'Mobile app',
                subtitle: 'Compatibility preview',
                isSelected: isAppActive,
                painter: MobileAppThumbnailPainter(color: isAppActive ? theme.accent : theme.muted),
                theme: theme,
                onTap: () => _switchMode(
                  ExperienceMode.app,
                  tileKey: _appTileKey,
                  targetLabel: 'Mobile app',
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // On Phone/Tablet: Selectable = "Mobile web" (Web) & "Mobile app" (App)
      // Reference = "PC website" (muted, ~70% width, dashed border, caption "PCs only")
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: _buildReferenceTile(
              title: 'PC website',
              caption: 'PCs only',
              painter: PcWebsiteThumbnailPainter(color: theme.muted.withValues(alpha: 0.5)),
              theme: theme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 10,
            child: Container(
              key: _webTileKey,
              child: _buildSelectableTile(
                title: 'Mobile web',
                subtitle: 'In the browser',
                isSelected: isWebActive,
                painter: MobileWebThumbnailPainter(color: isWebActive ? theme.accent : theme.muted),
                theme: theme,
                onTap: () => _switchMode(
                  ExperienceMode.web,
                  tileKey: _webTileKey,
                  targetLabel: 'Mobile web',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 10,
            child: Container(
              key: _appTileKey,
              child: _buildSelectableTile(
                title: 'Mobile app',
                subtitle: 'Installed app',
                isSelected: isAppActive,
                painter: MobileAppThumbnailPainter(color: isAppActive ? theme.accent : theme.muted),
                theme: theme,
                onTap: () => _switchMode(
                  ExperienceMode.app,
                  tileKey: _appTileKey,
                  targetLabel: 'Mobile app',
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSelectableTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required CustomPainter painter,
    required SettlivThemeExtension theme,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$title layout tile',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.accent.withValues(alpha: 0.08)
                : theme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? theme.accent : theme.hairline,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 38,
                    height: 26,
                    child: CustomPaint(painter: painter),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: theme.accent,
                    )
                  else
                    const SizedBox(width: 16, height: 16),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: AppTypography.bodySemiBold.copyWith(
                  color: isSelected ? theme.accent : theme.ink,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontSize: 10.5,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReferenceTile({
    required String title,
    required String caption,
    required CustomPainter painter,
    required SettlivThemeExtension theme,
  }) {
    return CustomPaint(
      painter: DashedBorderPainter(
        color: theme.hairline,
        strokeWidth: 1.0,
        radius: 16,
        dashPattern: const [4, 3],
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.transparent,
        ),
        child: Opacity(
          opacity: 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 38,
                    height: 26,
                    child: CustomPaint(painter: painter),
                  ),
                  const SizedBox(width: 16, height: 16),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: AppTypography.bodySemiBold.copyWith(
                  color: theme.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontSize: 10,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewNoticeStrip(SettlivThemeExtension theme) {
    return Container(
      constraints: const BoxConstraints(minHeight: 96),
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 3px Gradient accent edge on the left
            Container(
              width: 3.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.accent,
                    theme.accent.withValues(alpha: 0.4),
                  ],
                ),
              ),
            ),
            // Left: Drawn convergence orbit diagram
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 58,
                  height: 58,
                  child: AnimatedBuilder(
                    animation: _orbitController,
                    builder: (context, _) => CustomPaint(
                      painter: DeviceConvergencePainter(
                        color: theme.accent,
                        hairlineColor: theme.hairline,
                        progress: _orbitController.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Right: Headline + Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'A preview, not a feature.',
                      style: TextStyle(
                        fontFamily: AppTypography.fontBrand,
                        fontFamilyFallback: AppTypography.brandFallback,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: theme.ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'In the shipped product each person gets only the layout made for their device — PC website, mobile website or mobile app — with no switching. This switch lets you see all three from one link.',
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: theme.muted,
                        height: 1.35,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _switchMode(
    ExperienceMode mode, {
    GlobalKey? tileKey,
    required String targetLabel,
  }) {
    final currentEffective = ref.read(effectiveExperienceProvider);
    final profile = ref.read(deviceProfileProvider);
    final nextEffective = resolveEffectiveExperience(profile: profile, mode: mode);
    if (currentEffective != nextEffective) {
      Offset origin = MediaQuery.sizeOf(context).center(Offset.zero);
      final box = tileKey?.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        origin = box.localToGlobal(box.size.center(Offset.zero));
      }
      ref.read(experienceTransitionProvider.notifier).trigger(
            origin: origin,
            targetLabel: targetLabel,
          );
    }

    ref.read(experienceModeProvider.notifier).setMode(mode);

    // Route mapping when switching:
    // /budgets (Web) <-> /insights/budgets (App)
    try {
      final currentPath = GoRouterState.of(context).matchedLocation;
      if (mode == ExperienceMode.app && currentPath == '/budgets') {
        context.go('/insights/budgets');
      } else if (mode == ExperienceMode.web && currentPath == '/insights/budgets') {
        context.go('/budgets');
      }
    } catch (_) {}
  }
}

/// Dashed border painter for reference layout cards
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final List<double> dashPattern;

  const DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
    required this.dashPattern,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0),
        Radius.circular(radius),
      ));

    final dashTotal = dashPattern[0] + dashPattern[1];
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = math.min(dashPattern[0], metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dashTotal;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Drawn convergence diagram: 3 device glyphs joined by thin dotted lines to one central node
class DeviceConvergencePainter extends CustomPainter {
  final Color color;
  final Color hairlineColor;
  final double progress;

  const DeviceConvergencePainter({
    required this.color,
    required this.hairlineColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dotPaint = Paint()
      ..color = hairlineColor
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // 3 device node positions
    final pcNode = Offset(center.dx, 10);
    final phoneLeftNode = Offset(10, size.height - 12);
    final phoneRightNode = Offset(size.width - 10, size.height - 12);

    // Draw dotted lines from nodes to center
    _drawDottedLine(canvas, pcNode, center, dotPaint);
    _drawDottedLine(canvas, phoneLeftNode, center, dotPaint);
    _drawDottedLine(canvas, phoneRightNode, center, dotPaint);

    // Outer device node circles
    final nodePaint = Paint()
      ..color = hairlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(pcNode, 4.0, nodePaint);
    canvas.drawCircle(phoneLeftNode, 3.5, nodePaint);
    canvas.drawCircle(phoneRightNode, 3.5, nodePaint);

    // Central node (orbit motif)
    final centerFill = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final centerRing = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, 7.0, centerFill);
    canvas.drawCircle(center, 7.0, centerRing);
    canvas.drawCircle(center, 2.5, Paint()..color = color);

    // Single travelling dot animating once into place along the top line to center
    final travelX = pcNode.dx + (center.dx - pcNode.dx) * progress;
    final travelY = pcNode.dy + (center.dy - pcNode.dy) * progress;
    final travelPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(travelX, travelY), 2.2, travelPaint);
  }

  void _drawDottedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    const step = 4.5;
    final count = (distance / step).floor();

    for (int i = 1; i < count; i++) {
      final t = i / count;
      final x = p1.dx + dx * t;
      final y = p1.dy + dy * t;
      canvas.drawCircle(Offset(x, y), 0.75, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DeviceConvergencePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.hairlineColor != hairlineColor ||
      oldDelegate.progress != progress;
}

/// Thumbnail painter for PC Website (browser window with sidebar + grid)
class PcWebsiteThumbnailPainter extends CustomPainter {
  final Color color;
  const PcWebsiteThumbnailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 1, size.width, size.height - 2),
      const Radius.circular(3),
    );
    canvas.drawRRect(windowRect, strokePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 3, 6, size.height - 6),
        const Radius.circular(1.5),
      ),
      fillPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 4, size.width - 12, 5),
        const Radius.circular(1),
      ),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 11, size.width - 12, 6),
        const Radius.circular(1),
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant PcWebsiteThumbnailPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Thumbnail painter for Mobile Website (phone frame with top header)
class MobileWebThumbnailPainter extends CustomPainter {
  final Color color;
  const MobileWebThumbnailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 0, size.width - 12, size.height),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(phoneRect, strokePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 2, size.width - 16, 4),
        const Radius.circular(1),
      ),
      fillPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 8, size.width - 16, 5),
        const Radius.circular(1),
      ),
      fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 15, size.width - 16, 4),
        const Radius.circular(1),
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MobileWebThumbnailPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Thumbnail painter for Mobile App (phone frame with bottom docked bar)
class MobileAppThumbnailPainter extends CustomPainter {
  final Color color;
  const MobileAppThumbnailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 0, size.width - 12, size.height),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(phoneRect, strokePaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 4, size.width - 16, 8),
        const Radius.circular(1),
      ),
      fillPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(9, size.height - 5, size.width - 18, 3),
        const Radius.circular(1.5),
      ),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MobileAppThumbnailPainter oldDelegate) =>
      oldDelegate.color != color;
}
