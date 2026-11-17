import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/models/group.dart';
import '../theme/app_colors.dart';

class GroupCoverArt extends StatelessWidget {
  final GroupCoverType coverType;
  final double width;
  final double height;
  final double borderRadius;
  final String heroTag;

  const GroupCoverArt({
    super.key,
    required this.coverType,
    this.width = double.infinity,
    this.height = 120.0,
    this.borderRadius = 20.0,
    this.heroTag = '',
  });

  @override
  Widget build(BuildContext context) {
    final artWidget = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          size: Size(width, height),
          painter: coverType == GroupCoverType.flatmates
              ? _FlatmatesCoverPainter()
              : _GoaTripCoverPainter(),
        ),
      ),
    );

    if (heroTag.isNotEmpty) {
      return Hero(
        tag: heroTag,
        child: artWidget,
      );
    }

    return artWidget;
  }
}

class _FlatmatesCoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base navy to deep teal gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0E1A3A),
          Color(0xFF143048),
          Color(0xFF164455),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Soft geometric arcs
    final arcPaint1 = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32.0;

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.85, size.height * 0.2),
        radius: size.height * 0.8,
      ),
      math.pi * 0.4,
      math.pi * 0.8,
      false,
      arcPaint1,
    );

    final arcPaint2 = Paint()
      ..color = AppColors.cobaltGlow.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18.0;

    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.2, size.height * 0.9),
        radius: size.height * 0.65,
      ),
      math.pi * 1.2,
      math.pi * 0.7,
      false,
      arcPaint2,
    );

    final arcPaint3 = Paint()
      ..color = AppColors.emerald.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.15),
      size.height * 0.35,
      arcPaint3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoaTripCoverPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base coral to saffron to warm rose sunset gradient
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFDF4A3C),
          Color(0xFFE66B40),
          Color(0xFFF4A52C),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // Subtle sun disc
    final sunPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.32),
      size.height * 0.4,
      sunPaint,
    );

    // Layered wave shapes
    final wave1 = Path();
    wave1.moveTo(0, size.height * 0.55);
    wave1.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.45,
      size.width * 0.6,
      size.height * 0.62,
    );
    wave1.quadraticBezierTo(
      size.width * 0.85,
      size.height * 0.75,
      size.width,
      size.height * 0.6,
    );
    wave1.lineTo(size.width, size.height);
    wave1.lineTo(0, size.height);
    wave1.close();

    final wavePaint1 = Paint()
      ..color = const Color(0xFFC7364E).withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave1, wavePaint1);

    final wave2 = Path();
    wave2.moveTo(0, size.height * 0.75);
    wave2.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.88,
      size.width * 0.7,
      size.height * 0.72,
    );
    wave2.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.65,
      size.width,
      size.height * 0.82,
    );
    wave2.lineTo(size.width, size.height);
    wave2.lineTo(0, size.height);
    wave2.close();

    final wavePaint2 = Paint()
      ..color = const Color(0xFF8B1D45).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;
    canvas.drawPath(wave2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
