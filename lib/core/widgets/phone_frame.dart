import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'aurora_background.dart';
import 'glass_surface.dart';

class PhoneFrame extends StatelessWidget {
  final Widget child;

  const PhoneFrame({super.key, required this.child});

  static const double targetWidth = 390.0;
  static const double targetHeight = 844.0;
  static const double bezelWidth = 8.0;
  static const double cornerRadius = 44.0;

  static const String prototypeNote =
      'This is a v0 prototype. Settliv has more screens and features planned (people, search, backup, reminders and more), but only the 3 core screens are built here because this assignment requires 3.';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isDesktop = screenWidth > 600;

    if (!isDesktop) {
      return child;
    }

    final double totalFrameHeight = targetHeight + (bezelWidth * 2);
    final double totalFrameWidth = targetWidth + (bezelWidth * 2);
    final isDark = context.isDarkMode;
    final isWideDesktop = screenWidth >= 900;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBase : AppColors.lightBase,
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // Centred small SETTLIV wordmark above the frame
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'SETTLIV',
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4.2, // ~0.32em
                      color: isDark
                          ? AppColors.darkSecondary
                          : AppColors.lightSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Main frame area (with side note if width >= 900)
                Expanded(
                  child: isWideDesktop
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left spacer to balance side note
                            const SizedBox(width: 260),
                            const SizedBox(width: 24),
                            // Centered phone frame
                            Flexible(
                              child: Center(
                                child: _buildFrame(
                                  context: context,
                                  media: media,
                                  totalFrameWidth: totalFrameWidth,
                                  totalFrameHeight: totalFrameHeight,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            // Right side glass note card
                            SizedBox(
                              width: 260,
                              child: GlassSurface(
                                level: GlassLevel.level2,
                                padding: const EdgeInsets.all(18),
                                borderRadius: 20,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.sapphire,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'PROTOTYPE NOTE',
                                          style: AppTypography.sectionLabel.copyWith(
                                            color: isDark
                                                ? AppColors.darkSecondary
                                                : AppColors.lightSecondary,
                                            fontSize: 11,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      prototypeNote,
                                      style: AppTypography.caption.copyWith(
                                        color: isDark
                                            ? AppColors.darkSecondary
                                            : AppColors.lightSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: _buildFrame(
                            context: context,
                            media: media,
                            totalFrameWidth: totalFrameWidth,
                            totalFrameHeight: totalFrameHeight,
                            isDark: isDark,
                          ),
                        ),
                ),

                // Note below frame if 600 <= width < 900
                if (!isWideDesktop) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      prototypeNote,
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkSecondary.withValues(alpha: 0.8)
                            : AppColors.lightSecondary.withValues(alpha: 0.8),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFrame({
    required BuildContext context,
    required MediaQueryData media,
    required double totalFrameWidth,
    required double totalFrameHeight,
    required bool isDark,
  }) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        width: totalFrameWidth,
        height: totalFrameHeight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2230) : const Color(0xFF262C3A), // Graphite bezel
          borderRadius: BorderRadius.circular(cornerRadius + bezelWidth),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.22),
              blurRadius: 44,
              offset: const Offset(0, 20),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: AppColors.sapphire.withValues(alpha: isDark ? 0.25 : 0.12),
              blurRadius: 70,
              offset: const Offset(0, 28),
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(bezelWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(cornerRadius),
          child: SizedBox(
            width: targetWidth,
            height: targetHeight,
            child: MediaQuery(
              data: media.copyWith(
                size: const Size(targetWidth, targetHeight),
                padding: const EdgeInsets.only(top: 44, bottom: 24),
                viewInsets: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
