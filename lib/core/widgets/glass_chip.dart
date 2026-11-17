import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class GlassChip extends StatefulWidget {
  final String label;
  final Widget? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.isSelected = false,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  });

  @override
  State<GlassChip> createState() => _GlassChipState();
}

class _GlassChipState extends State<GlassChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    final Color bgColor = widget.isSelected
        ? (isDark ? AppColors.sapphire : AppColors.sapphire)
        : (isDark
            ? (_isHovered ? const Color(0x33FFFFFF) : const Color(0x1AFFFFFF))
            : (_isHovered ? const Color(0xE6FFFFFF) : const Color(0xB3FFFFFF)));

    final Color textColor = widget.isSelected
        ? Colors.white
        : theme.ink;

    final Color borderColor = widget.isSelected
        ? AppColors.sapphireStart.withValues(alpha: 0.6)
        : (isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.6));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: widget.isSelected ? 0.18 : (isDark ? 0.2 : 0.04),
                ),
                blurRadius: widget.isSelected ? 10 : 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: AppTypography.chip.copyWith(
                  color: textColor,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
