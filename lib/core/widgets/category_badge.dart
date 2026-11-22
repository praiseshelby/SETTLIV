import 'package:flutter/material.dart';
import '../../data/models/expense.dart';
import '../theme/app_theme.dart';
import '../theme/category_palette.dart';

typedef CategoryTile = CategoryBadge;

class CategoryBadge extends StatelessWidget {
  final ExpenseCategory category;
  final double size;
  final double iconSize;
  final double borderRadius;

  const CategoryBadge({
    super.key,
    required this.category,
    this.size = 40.0,
    this.iconSize = 20.0,
    this.borderRadius = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final isDark = theme.isDark;

    final palette = CategoryPalette.getColors(category, isDark: isDark);
    final iconData = CategoryPalette.getIcon(category);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.tile,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: palette.base.withOpacity(isDark ? 0.32 : 0.22),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: iconSize,
          color: palette.icon,
        ),
      ),
    );
  }
}
