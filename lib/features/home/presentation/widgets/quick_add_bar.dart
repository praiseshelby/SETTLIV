import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/glass_chip.dart';
import '../../../../core/widgets/glass_surface.dart';

class QuickAddBar extends StatefulWidget {
  final ValueChanged<String>? onQuickAddTapped;

  const QuickAddBar({super.key, this.onQuickAddTapped});

  @override
  State<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends State<QuickAddBar> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;

    final double scale = _isPressed ? 0.98 : 1.0;
    final double translateY = (_isHovered && !_isPressed) ? -2.0 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Quick-add button
        Semantics(
          button: true,
          label: 'Add an expense button',
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              onTap: () => widget.onQuickAddTapped?.call(''),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..scale(scale)
                  ..translate(0.0, translateY),
                child: GlassSurface(
                  level: GlassLevel.level2,
                  borderRadius: 22,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      // Gradient icon tile
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: AppColors.sapphireGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.sapphireEnd
                                  .withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.bolt_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add an expense',
                              style: AppTypography.titleMedium.copyWith(
                                color: theme.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Try: dinner 800 with Meera and Kabir',
                              style: AppTypography.caption.copyWith(
                                color: theme.secondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Trailing arrow chip
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0x2EFFFFFF)
                              : const Color(0x1F0F1633),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: theme.ink,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3 Glass example chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              GlassChip(
                label: 'Rent 18,000',
                icon: const Icon(Icons.add_rounded, size: 14),
                onTap: () => widget.onQuickAddTapped?.call('Rent 18,000'),
              ),
              const SizedBox(width: 8),
              GlassChip(
                label: 'Cab 240 with Kabir',
                icon: const Icon(Icons.add_rounded, size: 14),
                onTap: () => widget.onQuickAddTapped?.call('Cab 240 with Kabir'),
              ),
              const SizedBox(width: 8),
              GlassChip(
                label: 'Groceries 1,250',
                icon: const Icon(Icons.add_rounded, size: 14),
                onTap: () => widget.onQuickAddTapped?.call('Groceries 1,250'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
