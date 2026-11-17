import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class PhoneFrame extends StatelessWidget {
  final Widget child;

  const PhoneFrame({super.key, required this.child});

  static const double targetWidth = 390.0;
  static const double targetHeight = 844.0;
  static const double bezelWidth = 10.0;
  static const double cornerRadius = 44.0;

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

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070B14) : const Color(0xFFECE8E0),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: isDark
                ? [
                    const Color(0xFF10172B),
                    const Color(0xFF080C16),
                  ]
                : [
                    const Color(0xFFFAF7F0),
                    const Color(0xFFE5E0D5),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Container(
                        width: totalFrameWidth,
                        height: totalFrameHeight,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1B2338) : const Color(0xFF1E2430),
                          borderRadius: BorderRadius.circular(cornerRadius + bezelWidth),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2C3955) : const Color(0xFF384252),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.28),
                              blurRadius: 40,
                              offset: const Offset(0, 18),
                              spreadRadius: -4,
                            ),
                            BoxShadow(
                              color: AppColors.midnightNavy.withValues(alpha: 0.15),
                              blurRadius: 80,
                              offset: const Offset(0, 28),
                              spreadRadius: 8,
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
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Settliv wordmark and tagline
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settliv',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkInk : AppColors.midnightNavy,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      '  ·  Split fair. Settle fast.',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkSecondary : AppColors.lightSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
