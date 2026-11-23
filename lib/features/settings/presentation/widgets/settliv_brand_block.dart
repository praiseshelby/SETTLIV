import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/settliv_logomark.dart';
import '../../../../core/widgets/settliv_wordmark.dart';

class SettlivBrandBlock extends StatelessWidget {
  const SettlivBrandBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Column(
      children: [
        const SizedBox(height: 12),
        SettlivLogomark(size: 40, color: theme.ink.withValues(alpha: 0.7)),
        const SizedBox(height: 10),
        const SettlivWordmark(fontSize: 26),
        const SizedBox(height: 8),
        Text(
          AppConfig.versionString,
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Built with Flutter · Local-first preview',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 16),
        // Large hairline outline watermark cropped at the bottom
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 0.5,
            child: Text(
              'SETTLIV',
              style: TextStyle(
                fontFamily: AppTypography.fontBrand,
                fontFamilyFallback: AppTypography.brandFallback,
                fontSize: 64,
                fontWeight: FontWeight.w800,
                letterSpacing: 64 * 0.18,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.0
                  ..color = theme.ink.withValues(alpha: 0.08),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
