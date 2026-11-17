import 'package:flutter/material.dart';
import '../../data/models/expense.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

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
    final isDark = context.isDarkMode;

    final Color tintColor;
    final Color iconColor;
    final IconData iconData;

    switch (category) {
      case ExpenseCategory.food:
        tintColor = AppColors.amber;
        iconColor = isDark ? const Color(0xFFFFC566) : const Color(0xFFD98A11);
        iconData = Icons.restaurant_rounded;
        break;
      case ExpenseCategory.rent:
        tintColor = AppColors.sapphire;
        iconColor = isDark ? const Color(0xFF7A93FF) : AppColors.sapphire;
        iconData = Icons.roofing_rounded;
        break;
      case ExpenseCategory.travel:
        tintColor = AppColors.aqua;
        iconColor = isDark ? const Color(0xFF5CE0ED) : const Color(0xFF0F94A6);
        iconData = Icons.directions_car_filled_rounded;
        break;
      case ExpenseCategory.stay:
        tintColor = AppColors.lilac;
        iconColor = isDark ? const Color(0xFFB4A6FF) : const Color(0xFF6B56E8);
        iconData = Icons.hotel_rounded;
        break;
      case ExpenseCategory.groceries:
        tintColor = AppColors.emerald;
        iconColor = isDark ? const Color(0xFF38E2B2) : const Color(0xFF0C9470);
        iconData = Icons.shopping_basket_rounded;
        break;
      case ExpenseCategory.bills:
        tintColor = AppColors.coral;
        iconColor = isDark ? const Color(0xFFFF8273) : const Color(0xFFD64431);
        iconData = Icons.receipt_long_rounded;
        break;
      case ExpenseCategory.fun:
        tintColor = AppColors.lilac;
        iconColor = isDark ? const Color(0xFFE29BFF) : const Color(0xFF9E38DE);
        iconData = Icons.celebration_rounded;
        break;
      case ExpenseCategory.other:
        tintColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
        iconColor = isDark ? Colors.white70 : const Color(0xFF4B5565);
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
          color: iconColor,
          size: iconSize,
        ),
      ),
    );
  }
}

typedef CategoryTile = CategoryBadge;
