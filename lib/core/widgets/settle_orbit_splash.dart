import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Static pass-through gate so there is no second Dart Ticker or minimum-time
/// delay after flutter-first-frame; the HTML/CSS splash in web/index.html is
/// the single source of the intro.
class SettleOrbitSplashGate extends StatelessWidget {
  final Widget child;
  final bool skipInTests;

  const SettleOrbitSplashGate({
    super.key,
    required this.child,
    this.skipInTests = true,
  });

  @override
  Widget build(BuildContext context) => child;
}

/// Static composed first-frame fallback matching web/index.html's #070914
/// midnight palette, without any Ticker or animated CustomPainter.
class SettleOrbitSplash extends StatelessWidget {
  final bool exiting;

  const SettleOrbitSplash({
    super.key,
    this.exiting = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wordmarkSize = (size.width * 0.05).clamp(30.0, 48.0);
    final tracking = wordmarkSize * 0.28;
    final hairlineWidth = (size.width * 0.22).clamp(120.0, 190.0);

    return ColoredBox(
      color: AppColors.farDarkInkBase,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: tracking),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final ch in const ['S', 'E', 'T', 'T', 'L', 'I', 'V'])
                    Text(
                      ch,
                      style: TextStyle(
                        fontFamily: AppTypography.fontBrand,
                        fontFamilyFallback: AppTypography.brandFallback,
                        fontSize: wordmarkSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: tracking,
                        height: 1.0,
                        color: AppColors.darkInk,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: hairlineWidth,
              height: 1.5,
              child: ColoredBox(
                color: AppColors.darkInk.withValues(alpha: 0.22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
