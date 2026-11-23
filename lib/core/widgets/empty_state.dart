import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'web_glass_card.dart';

/// EmptyState displaying Settliv's signature Settle orbit motif in fine lines.
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final effectiveText = subtitle ?? message ?? '';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            WebGlassCard(
              borderRadius: 32,
              padding: const EdgeInsets.all(24),
              enableHover: false,
              child: SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: SettleOrbitMotifPainter(theme: theme),
                  child: icon != null
                      ? Center(
                          child: Icon(
                            icon,
                            size: 24,
                            color: theme.isDark ? theme.ink : theme.navy,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              style: AppTypography.titleLarge.copyWith(
                color: theme.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (effectiveText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                effectiveText,
                style: AppTypography.body.copyWith(
                  color: theme.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 22),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Settle orbit motif in fine lines echoing Settliv balance theme
class SettleOrbitMotifPainter extends CustomPainter {
  final SettlivThemeExtension theme;

  const SettleOrbitMotifPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = theme.accent.withValues(alpha: theme.isDark ? 0.35 : 0.25);

    final guidePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = theme.hairline.withValues(alpha: theme.isDark ? 0.5 : 0.7);

    // Fine concentric rings
    canvas.drawCircle(center, 34, ringPaint);
    canvas.drawCircle(center, 22, guidePaint);

    // Horizontal leveling line with leveling tick marks
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = theme.muted.withValues(alpha: 0.6);
    canvas.drawLine(Offset(center.dx - 42, center.dy), Offset(center.dx + 42, center.dy), linePaint);
    canvas.drawLine(Offset(center.dx - 42, center.dy - 3), Offset(center.dx - 42, center.dy + 3), linePaint);
    canvas.drawLine(Offset(center.dx + 42, center.dy - 3), Offset(center.dx + 42, center.dy + 3), linePaint);

    // Left and right orbit nodes in balance
    final owedPaint = Paint()..color = theme.textEmerald..style = PaintingStyle.fill;
    final owePaint = Paint()..color = theme.textCoral..style = PaintingStyle.fill;
    final centerPaint = Paint()..color = theme.accent..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx - 22, center.dy), 3.2, owedPaint);
    canvas.drawCircle(Offset(center.dx + 22, center.dy), 3.2, owePaint);
    canvas.drawCircle(center, 2.2, centerPaint);
  }

  @override
  bool shouldRepaint(covariant SettleOrbitMotifPainter oldDelegate) => oldDelegate.theme != theme;
}
