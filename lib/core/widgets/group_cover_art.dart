import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../data/models/group.dart';
import '../theme/app_theme.dart';

class GroupCoverArt extends StatelessWidget {
  final Group? group;
  final int? coverThemeIndex;
  final GroupCoverType? coverType;
  final double height;
  final double? width;
  final dynamic borderRadius;
  final String? heroTag;

  const GroupCoverArt({
    super.key,
    this.group,
    this.coverThemeIndex,
    this.coverType,
    this.height = 84,
    this.width,
    this.borderRadius,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;

    final BorderRadius effectiveRadius;
    if (borderRadius is BorderRadius) {
      effectiveRadius = borderRadius as BorderRadius;
    } else if (borderRadius is double) {
      effectiveRadius = BorderRadius.circular(borderRadius as double);
    } else if (borderRadius is int) {
      effectiveRadius = BorderRadius.circular((borderRadius as int).toDouble());
    } else {
      effectiveRadius = BorderRadius.circular(20);
    }

    int themeIdx = 0;
    if (coverThemeIndex != null) {
      themeIdx = coverThemeIndex! % 6;
    } else if (group != null) {
      themeIdx = group!.coverThemeIndex % 6;
    } else if (coverType != null) {
      themeIdx = coverType == GroupCoverType.goaTrip ? 1 : 0;
    }

    final palette = theme.coverThemePalettes[themeIdx];

    Widget content = RepaintBoundary(
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: SizedBox(
          height: height,
          width: width ?? double.infinity,
          child: CustomPaint(
            painter: _GroupCoverPainter(
              themeIndex: themeIdx,
              palette: palette,
              isDark: theme.isDark,
              hairlineColor: theme.hairline,
              accentColor: theme.white,
            ),
            size: Size(width ?? double.infinity, height),
          ),
        ),
      ),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      content = Hero(tag: heroTag!, child: content);
    }

    return content;
  }
}

class _GroupCoverPainter extends CustomPainter {
  final int themeIndex;
  final List<Color> palette;
  final bool isDark;
  final Color hairlineColor;
  final Color accentColor;

  const _GroupCoverPainter({
    required this.themeIndex,
    required this.palette,
    required this.isDark,
    required this.hairlineColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final primary = palette[0];
    final secondary = palette.length > 1 ? palette[1] : primary;
    final tertiary = palette.length > 2 ? palette[2] : secondary;

    // 1. Base gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary, tertiary],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Pattern based on themeIndex (0: arcs, 1: waves, 2: contours, 3: orbits, 4: diagonals, 5: rings)
    switch (themeIndex % 6) {
      case 0:
        // Arcs (Flatmates / Navy-Indigo style)
        final center = Offset(size.width * 0.85, size.height * 0.5);
        final arcPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = accentColor.withValues(alpha: isDark ? 0.22 : 0.28);
        for (double r = 20; r < size.width * 0.9; r += 20) {
          canvas.drawCircle(center, r, arcPaint);
        }
        break;

      case 1:
        // Waves (Goa Trip / Teal-Mint style)
        final sunCenter = Offset(size.width * 0.72, size.height * 0.38);
        final sunPaint = Paint()..color = accentColor.withValues(alpha: isDark ? 0.35 : 0.55);
        canvas.drawCircle(sunCenter, 18, sunPaint);

        final wavePaint = Paint()
          ..color = accentColor.withValues(alpha: isDark ? 0.16 : 0.24)
          ..style = PaintingStyle.fill;

        final path = Path()
          ..moveTo(0, size.height * 0.65)
          ..quadraticBezierTo(size.width * 0.28, size.height * 0.52, size.width * 0.55, size.height * 0.66)
          ..quadraticBezierTo(size.width * 0.82, size.height * 0.80, size.width, size.height * 0.68)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close();
        canvas.drawPath(path, wavePaint);
        break;

      case 2:
        // Contours (Topographic curves)
        final contourPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = accentColor.withValues(alpha: isDark ? 0.20 : 0.25);
        for (int i = 0; i < 4; i++) {
          final cPath = Path()
            ..moveTo(0, size.height * (0.3 + (i * 0.18)))
            ..cubicTo(
              size.width * 0.3,
              size.height * (0.1 + (i * 0.15)),
              size.width * 0.7,
              size.height * (0.5 + (i * 0.15)),
              size.width,
              size.height * (0.2 + (i * 0.18)),
            );
          canvas.drawPath(cPath, contourPaint);
        }
        break;

      case 3:
        // Orbits (Ellipses)
        final orbitPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = accentColor.withValues(alpha: isDark ? 0.22 : 0.28);
        final oCenter = Offset(size.width * 0.5, size.height * 0.5);
        canvas.drawOval(
          Rect.fromCenter(center: oCenter, width: size.width * 0.75, height: size.height * 0.5),
          orbitPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: oCenter, width: size.width * 0.5, height: size.height * 0.8),
          orbitPaint,
        );
        break;

      case 4:
        // Diagonals (Fine parallel slashes)
        final diagPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = accentColor.withValues(alpha: isDark ? 0.18 : 0.22);
        for (double d = -size.height; d < size.width + size.height; d += 24) {
          canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), diagPaint);
        }
        break;

      case 5:
      default:
        // Rings (Concentric bullseye)
        final rCenter = Offset(size.width * 0.2, size.height * 0.5);
        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = accentColor.withValues(alpha: isDark ? 0.20 : 0.26);
        for (double r = 16; r < size.width * 0.8; r += 24) {
          canvas.drawCircle(rCenter, r, ringPaint);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _GroupCoverPainter oldDelegate) {
    return themeIndex != oldDelegate.themeIndex ||
        isDark != oldDelegate.isDark ||
        hairlineColor != oldDelegate.hairlineColor ||
        accentColor != oldDelegate.accentColor ||
        !listEquals(palette, oldDelegate.palette);
  }
}
