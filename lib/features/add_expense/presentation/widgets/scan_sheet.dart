import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../core/widgets/glass_surface.dart';

class ScanSheet extends StatelessWidget {
  final VoidCallback? onPasteSms;
  final VoidCallback? onTypeInstead;

  const ScanSheet({
    super.key,
    this.onPasteSms,
    this.onTypeInstead,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onPasteSms,
    VoidCallback? onTypeInstead,
  }) {
    return AdaptivePresenter.show<void>(
      context: context,
      title: 'Scan receipt',
      type: PresentationType.formOrConfirmation,
      child: ScanSheet(
        onPasteSms: onPasteSms,
        onTypeInstead: onTypeInstead,
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
          // Viewfinder container
          Center(
            child: SizedBox(
              width: 220,
              height: 160,
              child: CustomPaint(
                painter: _ViewfinderPainter(
                  bracketColor: theme.accent,
                  fillColor: theme.surface.withValues(alpha: 0.3),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.document_scanner_rounded,
                        size: 44,
                        color: theme.accent.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'Coming with the Android app',
                          style: AppTypography.caption.copyWith(
                            color: theme.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title & Honest explanation
          Text(
            'Smart receipt scanning is on the way',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.fontBrand,
              fontFamilyFallback: AppTypography.brandFallback,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.ink,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Camera scanning and automated OCR will be available in the upcoming native Android build.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: theme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Action 1: Paste bank SMS
          Semantics(
            button: true,
            label: 'Paste bank SMS',
            child: InkWell(
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                if (onPasteSms != null) {
                  onPasteSms!();
                } else {
                  context.push('/add');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.primaryButtonBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sms_outlined,
                      size: 18,
                      color: theme.primaryButtonText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Paste bank SMS',
                      style: AppTypography.button.copyWith(
                        color: theme.primaryButtonText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Action 2: Type it instead
          Semantics(
            button: true,
            label: 'Type it instead',
            child: InkWell(
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                if (onTypeInstead != null) {
                  onTypeInstead!();
                } else {
                  context.push('/add');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: GlassSurface(
                level: GlassLevel.level1,
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: theme.ink,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Type it instead',
                      style: AppTypography.bodySemiBold.copyWith(
                        color: theme.ink,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  final Color bracketColor;
  final Color fillColor;

  const _ViewfinderPainter({
    required this.bracketColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // Fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    // Corner brackets
    final bracketPaint = Paint()
      ..color = bracketColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const cornerLen = 22.0;
    const pad = 8.0;

    // Top-Left
    canvas.drawLine(
      const Offset(pad, pad + cornerLen),
      const Offset(pad, pad + 6),
      bracketPaint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(pad, pad, 12, 12),
      3.14159,
      1.5708,
      false,
      bracketPaint,
    );
    canvas.drawLine(
      const Offset(pad + 6, pad),
      const Offset(pad + cornerLen, pad),
      bracketPaint,
    );

    // Top-Right
    canvas.drawLine(
      Offset(size.width - pad - cornerLen, pad),
      Offset(size.width - pad - 6, pad),
      bracketPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width - pad - 12, pad, 12, 12),
      -1.5708,
      1.5708,
      false,
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - pad, pad + 6),
      Offset(size.width - pad, pad + cornerLen),
      bracketPaint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(pad, size.height - pad - cornerLen),
      Offset(pad, size.height - pad - 6),
      bracketPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(pad, size.height - pad - 12, 12, 12),
      1.5708,
      1.5708,
      false,
      bracketPaint,
    );
    canvas.drawLine(
      Offset(pad + 6, size.height - pad),
      Offset(pad + cornerLen, size.height - pad),
      bracketPaint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width - pad - cornerLen, size.height - pad),
      Offset(size.width - pad - 6, size.height - pad),
      bracketPaint,
    );
    canvas.drawArc(
      Rect.fromLTWH(size.width - pad - 12, size.height - pad - 12, 12, 12),
      0,
      1.5708,
      false,
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width - pad, size.height - pad - 6),
      Offset(size.width - pad, size.height - pad - cornerLen),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.bracketColor != bracketColor || oldDelegate.fillColor != fillColor;
}
