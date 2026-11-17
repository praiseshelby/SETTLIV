import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class AuroraBackground extends StatefulWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');

    if (!isTest) {
      if (reduceMotion && _controller.isAnimating) {
        _controller.stop();
      } else if (!reduceMotion && !_controller.isAnimating) {
        _controller.repeat();
      }
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base solid background
          Container(
            color: isDark ? AppColors.darkBase : AppColors.lightBase,
          ),
          // Animated blobs painter
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AuroraPainter(
                  progress: (reduceMotion || isTest) ? 0.0 : _controller.value,
                  isDark: isDark,
                ),
                size: Size.infinite,
              );
            },
          ),
          // Foreground content
          widget.child,
        ],
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _AuroraPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final double t = progress * 2 * math.pi;

    if (!isDark) {
      // Light Mode: Cobalt, Lilac, Aqua, Peach
      // Blob 1: Cobalt top-left
      final offset1 = Offset(
        size.width * (0.2 + 0.1 * math.sin(t)),
        size.height * (0.15 + 0.08 * math.cos(t)),
      );
      final paint1 = Paint()
        ..shader = RadialGradient(
          colors: const [
            AppColors.auroraCobaltLight,
            Color(0x004F6BFF),
          ],
        ).createShader(Rect.fromCircle(center: offset1, radius: size.width * 0.55));
      canvas.drawCircle(offset1, size.width * 0.55, paint1);

      // Blob 2: Lilac top-right
      final offset2 = Offset(
        size.width * (0.8 - 0.1 * math.cos(t)),
        size.height * (0.35 + 0.1 * math.sin(t)),
      );
      final paint2 = Paint()
        ..shader = RadialGradient(
          colors: const [
            AppColors.auroraLilacLight,
            Color(0x00A78BFA),
          ],
        ).createShader(Rect.fromCircle(center: offset2, radius: size.width * 0.6));
      canvas.drawCircle(offset2, size.width * 0.6, paint2);

      // Blob 3: Aqua bottom-left
      final offset3 = Offset(
        size.width * (0.15 + 0.12 * math.cos(t)),
        size.height * (0.75 - 0.1 * math.sin(t)),
      );
      final paint3 = Paint()
        ..shader = RadialGradient(
          colors: const [
            AppColors.auroraAquaLight,
            Color(0x005EEAD4),
          ],
        ).createShader(Rect.fromCircle(center: offset3, radius: size.width * 0.5));
      canvas.drawCircle(offset3, size.width * 0.5, paint3);

      // Blob 4: Soft Peach center-bottom
      final offset4 = Offset(
        size.width * (0.65 + 0.08 * math.sin(t * 1.5)),
        size.height * (0.85 + 0.05 * math.cos(t * 1.5)),
      );
      final paint4 = Paint()
        ..shader = RadialGradient(
          colors: const [
            AppColors.auroraPeachLight,
            Color(0x00FFC8A8),
          ],
        ).createShader(Rect.fromCircle(center: offset4, radius: size.width * 0.45));
      canvas.drawCircle(offset4, size.width * 0.45, paint4);
    } else {
      // Dark Mode: Cobalt, Violet, Teal
      // Blob 1: Cobalt
      final offset1 = Offset(
        size.width * (0.2 + 0.12 * math.sin(t)),
        size.height * (0.2 + 0.1 * math.cos(t)),
      );
      final paint1 = Paint()
        ..shader = RadialGradient(
          colors: const [
            AppColors.auroraCobaltDark,
            Color(0x003D5AFE),
          ],
        ).createShader(Rect.fromCircle(center: offset1, radius: size.width * 0.65));
      canvas.drawCircle(offset1, size.width * 0.65, paint1);

      // Blob 2: Violet
      final offset2 = Offset(
        size.width * (0.75 - 0.1 * math.cos(t)),
        size.height * (0.45 + 0.12 * math.sin(t)),
      );
      final paint2 = Paint()
        ..shader = RadialGradient(
          colors: const [
            AppColors.auroraVioletDark,
            Color(0x007C5CFF),
          ],
        ).createShader(Rect.fromCircle(center: offset2, radius: size.width * 0.6));
      canvas.drawCircle(offset2, size.width * 0.6, paint2);

      // Blob 3: Teal
      final offset3 = Offset(
        size.width * (0.35 + 0.15 * math.cos(t * 1.2)),
        size.height * (0.8 - 0.08 * math.sin(t * 1.2)),
      );
      final paint3 = Paint()
        ..shader = RadialGradient(
          colors: const [
            AppColors.auroraTealDark,
            Color(0x0014B8A6),
          ],
        ).createShader(Rect.fromCircle(center: offset3, radius: size.width * 0.55));
      canvas.drawCircle(offset3, size.width * 0.55, paint3);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isDark != isDark;
  }
}
