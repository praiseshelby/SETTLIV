import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class FloatingAddButton extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingAddButton({
    super.key,
    required this.onTap,
  });

  @override
  State<FloatingAddButton> createState() => _FloatingAddButtonState();
}

class _FloatingAddButtonState extends State<FloatingAddButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: 'Add expense',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF223565) : AppColors.midnightNavy,
              border: Border.all(
                color: isDark ? AppColors.emeraldBright : AppColors.emerald,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
