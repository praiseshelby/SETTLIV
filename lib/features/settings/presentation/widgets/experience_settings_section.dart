import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/layout/adaptive_layout.dart';
import '../../../../core/profile/experience_mode.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_segmented.dart';
import '../../../../core/widgets/glass_surface.dart';

class ExperienceSettingsSection extends ConsumerWidget {
  const ExperienceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final effective = ref.watch(effectiveExperienceProvider);
    final isCompact = AdaptiveLayout.isCompact(context);

    // Active layout category among the 3 shipped targets:
    // 0 = PC website (Web on medium/expanded)
    // 1 = Mobile website (Web on compact)
    // 2 = Mobile app (App experience)
    final int activeLayoutIndex;
    if (effective == EffectiveExperience.app) {
      activeLayoutIndex = 2;
    } else if (isCompact) {
      activeLayoutIndex = 1;
    } else {
      activeLayoutIndex = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Eyebrow
        Text(
          'COMPATIBILITY PREVIEW',
          style: AppTypography.eyebrow.copyWith(
            color: theme.muted,
            letterSpacing: 0.8,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),

        GlassSurface(
          level: GlassLevel.level1,
          borderRadius: 20,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. Segmented control App | Web
              Text(
                'Preview layout switch',
                style: AppTypography.bodySemiBold.copyWith(
                  color: theme.ink,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Switch the live experience to verify compatibility and responsiveness.',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),

              GlassSegmented<String>(
                values: const ['app', 'web'],
                labels: const ['App', 'Web'],
                selectedValue: effective == EffectiveExperience.app ? 'app' : 'web',
                onValueChanged: (val) {
                  final newMode = val == 'web' ? ExperienceMode.web : ExperienceMode.app;
                  ref.read(experienceModeProvider.notifier).setMode(newMode);

                  // Route mapping when switching:
                  // /budgets (Web) <-> /insights/budgets (App)
                  try {
                    final currentPath = GoRouterState.of(context).matchedLocation;
                    if (newMode == ExperienceMode.app && currentPath == '/budgets') {
                      context.go('/insights/budgets');
                    } else if (newMode == ExperienceMode.web && currentPath == '/insights/budgets') {
                      context.go('/budgets');
                    }
                  } catch (_) {}
                },
              ),

              const SizedBox(height: 20),
              Divider(height: 1, color: theme.hairline),
              const SizedBox(height: 16),

              // 3. Row of three drawn schematic thumbnails
              Text(
                'SHIPPED TARGETS',
                style: AppTypography.eyebrow.copyWith(
                  color: theme.muted,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target 0: PC website
                  Expanded(
                    child: _buildTargetCard(
                      title: 'PC website',
                      caption: 'Shipped to: PC users',
                      isActive: activeLayoutIndex == 0,
                      painter: PcWebsiteThumbnailPainter(color: theme.accent),
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Target 1: Mobile website
                  Expanded(
                    child: _buildTargetCard(
                      title: 'Mobile web',
                      caption: 'Phone users, in the browser',
                      isActive: activeLayoutIndex == 1,
                      painter: MobileWebThumbnailPainter(color: theme.accent),
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Target 2: Mobile app
                  Expanded(
                    child: _buildTargetCard(
                      title: 'Mobile app',
                      caption: 'Phone users, installed',
                      isActive: activeLayoutIndex == 2,
                      painter: MobileAppThumbnailPainter(color: theme.accent),
                      theme: theme,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Divider(height: 1, color: theme.hairline),
              const SizedBox(height: 14),

              // 4. Required professional compatibility text
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: theme.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Settliv is optimised for three layouts: a website for PC, a mobile website and a mobile app. In the shipped product each person gets only the layout made for their device, with no switching. This switch exists in this preview only, to demonstrate that compatibility from a single link.',
                      style: AppTypography.caption.copyWith(
                        color: theme.muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTargetCard({
    required String title,
    required String caption,
    required bool isActive,
    required CustomPainter painter,
    required SettlivThemeExtension theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isActive
            ? theme.accent.withValues(alpha: 0.08)
            : theme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? theme.accent : theme.hairline,
          width: isActive ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CustomPaint(
                painter: painter,
                size: const Size(28, 22),
              ),
              if (isActive)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'ACTIVE',
                      style: TextStyle(
                        fontFamily: AppTypography.fontBody,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: theme.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.bodySemiBold.copyWith(
              color: isActive ? theme.accent : theme.ink,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 10.5,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
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

    // Outer browser window
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 1, size.width, size.height - 2),
      const Radius.circular(3),
    );
    canvas.drawRRect(windowRect, strokePaint);

    // Sidebar strip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 3, 6, size.height - 6),
        const Radius.circular(1.5),
      ),
      fillPaint,
    );

    // Content cards (2 mini cards)
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

    // Outer phone
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 0, size.width - 12, size.height),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(phoneRect, strokePaint);

    // Top header bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 2, size.width - 16, 4),
        const Radius.circular(1),
      ),
      fillPaint,
    );

    // Stacked content cards
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

    // Outer phone
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 0, size.width - 12, size.height),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(phoneRect, strokePaint);

    // Main body card
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 4, size.width - 16, 8),
        const Radius.circular(1),
      ),
      fillPaint,
    );

    // Bottom docked pill bar
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
