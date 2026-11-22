import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/profile/experience_mode.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_surface.dart';

class ExperienceSettingsSection extends ConsumerWidget {
  const ExperienceSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final profile = ref.watch(deviceProfileProvider);
    final effective = ref.watch(effectiveExperienceProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXPERIENCE',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        GlassSurface(
          level: GlassLevel.level1,
          borderRadius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (profile.isTouch) ...[
                // Touch devices: rectangular segmented control App | Web
                Text(
                  'Interface layout',
                  style: AppTypography.bodySemiBold.copyWith(
                    color: theme.ink,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // App option
                    Expanded(
                      child: _buildExperienceOption(
                        context: context,
                        title: 'App',
                        subtitle: 'Mobile app layout with bottom navigation',
                        isSelected: effective == EffectiveExperience.app,
                        painter: PhoneThumbnailPainter(color: theme.accent),
                        theme: theme,
                        onTap: () {
                          ref.read(experienceModeProvider.notifier).setMode(ExperienceMode.app);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Web option
                    Expanded(
                      child: _buildExperienceOption(
                        context: context,
                        title: 'Web',
                        subtitle: 'Responsive website layout with top navigation',
                        isSelected: effective == EffectiveExperience.web,
                        painter: BrowserThumbnailPainter(color: theme.accent),
                        theme: theme,
                        onTap: () {
                          ref.read(experienceModeProvider.notifier).setMode(ExperienceMode.web);
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Desktop: informative card (no toggle)
                Row(
                  children: [
                    CustomPaint(
                      painter: BrowserThumbnailPainter(color: theme.accent),
                      size: const Size(40, 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Responsive Website',
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: theme.ink,
                                  fontSize: 15,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'ACTIVE',
                                  style: AppTypography.caption.copyWith(
                                    color: theme.accent,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Optimized for desktop with sidebar, keyboard shortcuts, and responsive layouts. Touch and mobile devices can also toggle between app and website views.',
                            style: AppTypography.caption.copyWith(
                              color: theme.muted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.hairline),
              const SizedBox(height: 14),

              // Professional architectural note in both
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
                      'One codebase, two experiences. Settliv is built with Flutter, so the same product can ship as a mobile app (for Play Store-style distribution) and as a responsive website for desktop and mobile browsers.',
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

  Widget _buildExperienceOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isSelected,
    required CustomPainter painter,
    required SettlivThemeExtension theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accent.withValues(alpha: 0.08)
              : theme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? theme.accent : theme.hairline,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySemiBold.copyWith(
                    color: isSelected ? theme.accent : theme.ink,
                    fontSize: 14,
                  ),
                ),
                CustomPaint(
                  painter: painter,
                  size: const Size(24, 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontSize: 11,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class PhoneThumbnailPainter extends CustomPainter {
  final Color color;
  const PhoneThumbnailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Outer phone rect
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(2, 0, size.width - 4, size.height),
      const Radius.circular(4),
    );
    canvas.drawRRect(phoneRect, strokePaint);

    // Top status line
    canvas.drawLine(
      Offset(size.width * 0.35, 3),
      Offset(size.width * 0.65, 3),
      strokePaint..strokeWidth = 1.0,
    );

    // Middle body block
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 6, size.width - 10, 6),
        const Radius.circular(1.5),
      ),
      fillPaint,
    );

    // Bottom docked bar line
    canvas.drawLine(
      Offset(4, size.height - 3),
      Offset(size.width - 4, size.height - 3),
      strokePaint..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrowserThumbnailPainter extends CustomPainter {
  final Color color;
  const BrowserThumbnailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Outer browser window
    final windowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 1, size.width, size.height - 2),
      const Radius.circular(3),
    );
    canvas.drawRRect(windowRect, strokePaint);

    // Top window bar line
    canvas.drawLine(
      const Offset(0, 5),
      Offset(size.width, 5),
      strokePaint..strokeWidth = 0.8,
    );

    // Left sidebar strip
    canvas.drawRect(
      Rect.fromLTWH(1, 5, 6, size.height - 8),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
