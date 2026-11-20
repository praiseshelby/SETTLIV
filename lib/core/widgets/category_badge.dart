import 'package:flutter/material.dart';
import '../../data/models/expense.dart';
import '../theme/app_theme.dart';

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

    final Color tintColor;
    final Color iconColor;
    final IconData iconData;

    switch (category) {
      case ExpenseCategory.food:
        tintColor = theme.saffron;
        iconColor = theme.saffron;
        iconData = Icons.restaurant_rounded;
        break;
      case ExpenseCategory.rent:
        tintColor = theme.navy;
        iconColor = isDark ? theme.ink : theme.navy;
        iconData = Icons.roofing_rounded;
        break;
      case ExpenseCategory.travel:
        tintColor = theme.teal;
        iconColor = theme.teal;
        iconData = Icons.directions_car_filled_rounded;
        break;
      case ExpenseCategory.stay:
        tintColor = theme.orchid;
        iconColor = theme.orchid;
        iconData = Icons.hotel_rounded;
        break;
      case ExpenseCategory.groceries:
        tintColor = theme.emerald;
        iconColor = theme.textEmerald;
        iconData = Icons.shopping_basket_rounded;
        break;
      case ExpenseCategory.bills:
        tintColor = theme.coral;
        iconColor = theme.textCoral;
        iconData = Icons.receipt_long_rounded;
        break;
      case ExpenseCategory.fun:
        tintColor = theme.orchid;
        iconColor = theme.orchid;
        iconData = Icons.celebration_rounded;
        break;
      case ExpenseCategory.other:
        tintColor = theme.muted;
        iconColor = theme.muted;
        iconData = Icons.category_rounded;
        break;
    }

    final Color bgColor = tintColor.withValues(alpha: isDark ? 0.22 : 0.14);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: tintColor.withValues(alpha: isDark ? 0.28 : 0.2),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: iconSize,
          color: iconColor,
        ),
      ),
    );
  }
}
