import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'adaptive_presenter.dart';
import 'gradient_primary_button.dart';

/// Reusable, calm "Coming later" sheet/dialog for features that are not
/// available in the web prototype (e.g. Screen lock, Google Drive backup,
/// real SMS auto-track).
class FeatureComingSheet extends StatelessWidget {
  final String featureName;
  final String valueLine;
  final String availabilityLine;
  final String? whatItWillDo;
  final IconData? icon;

  const FeatureComingSheet({
    super.key,
    required this.featureName,
    required this.valueLine,
    this.availabilityLine = 'Arrives with the Android app',
    this.whatItWillDo,
    this.icon,
  });

  static Future<void> show(
    BuildContext context, {
    required String featureName,
    required String valueLine,
    String availabilityLine = 'Arrives with the Android app',
    String? whatItWillDo,
    IconData? icon,
  }) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: featureName,
      maxWidth: 440,
      type: PresentationType.formOrConfirmation,
      child: FeatureComingSheet(
        featureName: featureName,
        valueLine: valueLine,
        availabilityLine: availabilityLine,
        whatItWillDo: whatItWillDo,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: RepaintBoundary(
              child: SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _SettleOrbitGlyphPainter(
                    ringColor: theme.hairline,
                    accentColor: theme.accent,
                    emeraldColor: theme.emerald,
                    coralColor: theme.coral,
                  ),
                  child: Center(
                    child: Icon(
                      icon ?? Icons.auto_awesome_rounded,
                      size: 28,
                      color: theme.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                availabilityLine,
                style: AppTypography.caption.copyWith(
                  color: theme.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            valueLine,
            textAlign: TextAlign.center,
            style: AppTypography.bodySemiBold.copyWith(
              color: theme.ink,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          if (whatItWillDo != null) ...[
            const SizedBox(height: 8),
            Text(
              whatItWillDo!,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(
                color: theme.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: GradientPrimaryButton(
              height: 48,
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettleOrbitGlyphPainter extends CustomPainter {
  final Color ringColor;
  final Color accentColor;
  final Color emeraldColor;
  final Color coralColor;

  const _SettleOrbitGlyphPainter({
    required this.ringColor,
    required this.accentColor,
    required this.emeraldColor,
    required this.coralColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width * 0.44;
    final innerR = size.width * 0.30;

    final outerPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final innerPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawCircle(center, outerR, outerPaint);
    canvas.drawCircle(center, innerR, innerPaint);

    // Emerald & coral orbit nodes
    final emeraldAngle = -math.pi / 4;
    final coralAngle = (3 * math.pi) / 4;

    canvas.drawCircle(
      Offset(
        center.dx + outerR * math.cos(emeraldAngle),
        center.dy + outerR * math.sin(emeraldAngle),
      ),
      4.5,
      Paint()..color = emeraldColor,
    );

    canvas.drawCircle(
      Offset(
        center.dx + innerR * math.cos(coralAngle),
        center.dy + innerR * math.sin(coralAngle),
      ),
      4.5,
      Paint()..color = coralColor,
    );
  }

  @override
  bool shouldRepaint(covariant _SettleOrbitGlyphPainter oldDelegate) =>
      oldDelegate.ringColor != ringColor ||
      oldDelegate.accentColor != accentColor;
}
