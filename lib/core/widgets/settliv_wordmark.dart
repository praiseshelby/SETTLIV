import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// The official brand wordmark for Settliv.
///
/// Strict Brand Rule: Wordmark ONLY (no logomark/logo icon).
/// Bricolage Grotesque ExtraBold, ALL CAPS, wide tracking (~0.18em), solid ink color.
class SettlivWordmark extends StatelessWidget {
  final double fontSize;
  final Color? color;
  final bool rotated; // Rotated 90 deg vertical, reading bottom-to-top
  final double trackingFactor;
  final bool opticallyCenter;

  const SettlivWordmark({
    super.key,
    this.fontSize = 18,
    this.color,
    this.rotated = false,
    this.trackingFactor = 0.28,
    this.opticallyCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final tracking = fontSize * trackingFactor;

    final text = Text(
      'SETTLIV',
      style: TextStyle(
        fontFamily: AppTypography.fontBrand,
        fontFamilyFallback: AppTypography.brandFallback,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: tracking,
        height: 1.0,
        color: color ?? theme.ink,
      ),
    );

    if (rotated) {
      // 90 degrees vertical, reading bottom-to-top
      final child = opticallyCenter
          ? Padding(padding: EdgeInsets.only(top: tracking), child: text)
          : text;
      return RotatedBox(
        quarterTurns: 3,
        child: child,
      );
    }

    if (opticallyCenter) {
      return Padding(
        padding: EdgeInsets.only(left: tracking),
        child: text,
      );
    }

    return text;
  }
}
