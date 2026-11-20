import 'dart:math' as math;
import 'package:flutter/material.dart';
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
      duration: const Duration(seconds: 24),
    );

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
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
    final theme = context.settliv;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');

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
          // Base solid canvas
          Container(
            color: theme.canvas,
          ),
          // Subtle ambient glow
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AuroraPainter(
                  progress: (reduceMotion || isTest) ? 0.0 : _controller.value,
                  canvasColor: theme.canvas,
                  accentColor: theme.isDark ? theme.raised : theme.surface,
                  glowColor: theme.heroMeshAccent,
                  isDark: theme.isDark,
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
  final Color canvasColor;
  final Color accentColor;
  final Color glowColor;
  final bool isDark;

  const _AuroraPainter({
    required this.progress,
    required this.canvasColor,
    required this.accentColor,
    required this.glowColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final double t = progress * 2 * math.pi;

    // Subtle soft glow 1
    final offset1 = Offset(
      size.width * (0.2 + 0.08 * math.sin(t)),
      size.height * (0.15 + 0.06 * math.cos(t)),
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [
          glowColor.withValues(alpha: isDark ? 0.12 : 0.05),
          canvasColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: offset1, radius: size.width * 0.5));
    canvas.drawCircle(offset1, size.width * 0.5, paint1);

    // Subtle soft glow 2
    final offset2 = Offset(
      size.width * (0.8 - 0.08 * math.cos(t)),
      size.height * (0.35 + 0.08 * math.sin(t)),
    );
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [
          accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
          canvasColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: offset2, radius: size.width * 0.55));
    canvas.drawCircle(offset2, size.width * 0.55, paint2);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.canvasColor != canvasColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.isDark != isDark;
  }
}
