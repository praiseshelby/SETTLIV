import 'package:flutter/material.dart';
import '../../data/models/group.dart';

class GroupCoverArt extends StatelessWidget {
  final Group? group;
  final GroupCoverType? coverType;
  final double height;
  final double? width;
  final dynamic borderRadius;
  final String? heroTag;

  const GroupCoverArt({
    super.key,
    this.group,
    this.coverType,
    this.height = 84,
    this.width,
    this.borderRadius,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
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

    final effectiveCoverType =
        coverType ?? group?.coverType ?? GroupCoverType.flatmates;

    Widget content = ClipRRect(
      borderRadius: effectiveRadius,
      child: SizedBox(
        height: height,
        width: width ?? double.infinity,
        child: CustomPaint(
          painter: effectiveCoverType == GroupCoverType.flatmates
              ? _FlatmatesCoverPainter()
              : _GoaTripCoverPainter(),
          size: Size(width ?? double.infinity, height),
        ),
      ),
    );

    if (heroTag != null && heroTag!.isNotEmpty) {
      content = Hero(tag: heroTag!, child: content);
    }

    return content;
  }
}

/// Flatmates: indigo to lilac aurora with fine concentric arcs
class _FlatmatesCoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Calm indigo to lilac aurora gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF283675), // Muted deep indigo
          Color(0xFF4C589E), // Soft indigo
          Color(0xFF887EB8), // Calm lilac
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Fine concentric arcs
    final center = Offset(size.width * 0.85, size.height * 0.5);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.16);

    for (double r = 24; r < size.width * 0.9; r += 22) {
      canvas.drawCircle(center, r, arcPaint);
    }

    // Soft subtle ambient glow circle
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFA78BFA).withValues(alpha: 0.28),
          const Color(0x00A78BFA),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 60));
    canvas.drawCircle(center, 60, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Goa Trip: aqua to mint with a soft peach sun disk and gentle waves (no orange sunsets)
class _GoaTripCoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Calm aqua to mint gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF136878), // Deep calm teal
          Color(0xFF229AA8), // Aqua
          Color(0xFF48C5B0), // Mint
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Soft peach sun disk
    final sunCenter = Offset(size.width * 0.72, size.height * 0.38);
    final sunPaint = Paint()
      ..color = const Color(0xFFFFD1BA).withValues(alpha: 0.85);
    canvas.drawCircle(sunCenter, 22, sunPaint);

    // Sun corona/glow
    final sunGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE0D0).withValues(alpha: 0.45),
          const Color(0x00FFE0D0),
        ],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: 46));
    canvas.drawCircle(sunCenter, 46, sunGlow);

    // Gentle wave shapes
    final wavePaint1 = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.65);
    path1.quadraticBezierTo(
      size.width * 0.28,
      size.height * 0.52,
      size.width * 0.55,
      size.height * 0.66,
    );
    path1.quadraticBezierTo(
      size.width * 0.82,
      size.height * 0.80,
      size.width,
      size.height * 0.68,
    );
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, wavePaint1);

    final wavePaint2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height * 0.82);
    path2.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.72,
      size.width * 0.70,
      size.height * 0.84,
    );
    path2.quadraticBezierTo(
      size.width * 0.88,
      size.height * 0.90,
      size.width,
      size.height * 0.82,
    );
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
