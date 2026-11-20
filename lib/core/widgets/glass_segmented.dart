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
    final theme = context.settliv;
    final selectedIndex = values.indexOf(selectedValue);

    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.raised,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.hairline,
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
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.hairline,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadow.withValues(
                          alpha: theme.isDark ? 0.35 : 0.08,
                        ),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                          style: AppTypography.body.copyWith(
                            color: isSelected ? theme.ink : theme.muted,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          child: Text(labels[index]),
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
