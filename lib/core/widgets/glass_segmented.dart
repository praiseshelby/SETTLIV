import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class GlassSegmented<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final double height;

  const GlassSegmented({
    super.key,
    required this.values,
    required this.labels,
    required this.selectedValue,
    required this.onValueChanged,
    this.height = 44,
  }) : assert(values.length == labels.length);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final theme = context.settliv;
    final selectedIndex = values.indexOf(selectedValue);

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1FFFFFFF) : const Color(0x66E7ECF5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x4DFFFFFF),
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = (constraints.maxWidth) / values.length;

          return Stack(
            children: [
              // Sliding thumb
              AnimatedPositioned(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                left: selectedIndex >= 0 ? selectedIndex * segmentWidth : 0,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF232D4B) : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? const Color(0x38FFFFFF)
                          : const Color(0x80FFFFFF),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.35 : 0.08,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              // Segment labels
              Row(
                children: List.generate(values.length, (index) {
                  final isSelected = index == selectedIndex;
                  return Expanded(
                    child: InkWell(
                      onTap: () => onValueChanged(values[index]),
                      borderRadius: BorderRadius.circular(999),
                      mouseCursor: SystemMouseCursors.click,
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 180),
                          style: AppTypography.bodyMedium.copyWith(
                            color: isSelected ? theme.ink : theme.secondary,
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          child: Text(
                            labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
