import 'package:flutter/material.dart';
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

    final Color bgColor = widget.isSelected
        ? theme.navy
        : (_isHovered ? theme.raised : theme.surface);

    final Color textColor = widget.isSelected ? theme.onNavy : theme.ink;

    final Color borderColor = widget.isSelected ? theme.navy : theme.hairline;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
                color: theme.shadow.withValues(
                  alpha: widget.isSelected ? 0.18 : (theme.isDark ? 0.2 : 0.04),
                ),
                blurRadius: widget.isSelected ? 8 : 4,
                offset: const Offset(0, 2),
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
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w600,
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
