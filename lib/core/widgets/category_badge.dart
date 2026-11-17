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
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    final Color bgColor;
    final Color iconColor;
    final IconData iconData;

    switch (category) {
      case ExpenseCategory.food:
        bgColor = isDark ? const Color(0xFF322310) : AppColors.saffronTint;
        iconColor = isDark ? AppColors.saffronBright : AppColors.saffron;
        iconData = Icons.restaurant_rounded;
        break;
      case ExpenseCategory.rent:
        bgColor = isDark ? const Color(0xFF162544) : const Color(0xFFE8EEF9);
        iconColor = isDark ? const Color(0xFF88A9FF) : AppColors.midnightNavy;
        iconData = Icons.roofing_rounded;
        break;
      case ExpenseCategory.travel:
        bgColor = isDark ? const Color(0xFF102E34) : AppColors.tealTint;
        iconColor = isDark ? AppColors.tealBright : AppColors.teal;
        iconData = Icons.directions_car_filled_rounded;
        break;
      case ExpenseCategory.stay:
        bgColor = isDark ? const Color(0xFF281C3D) : AppColors.orchidTint;
        iconColor = isDark ? AppColors.orchidBright : AppColors.orchid;
        iconData = Icons.hotel_rounded;
        break;
      case ExpenseCategory.groceries:
        bgColor = isDark ? const Color(0xFF103126) : AppColors.emeraldTint;
        iconColor = isDark ? AppColors.emeraldBright : AppColors.emerald;
        iconData = Icons.shopping_basket_rounded;
        break;
      case ExpenseCategory.bills:
        bgColor = isDark ? const Color(0xFF381F15) : AppColors.coralTint;
        iconColor = isDark ? AppColors.coralBright : AppColors.coral;
        iconData = Icons.receipt_long_rounded;
        break;
      case ExpenseCategory.fun:
        bgColor = isDark ? const Color(0xFF311736) : const Color(0xFFFBE4F2);
        iconColor = isDark ? const Color(0xFFF67BC4) : const Color(0xFFD63384);
        iconData = Icons.celebration_rounded;
        break;
      case ExpenseCategory.other:
        bgColor = isDark ? const Color(0xFF1F2736) : const Color(0xFFEDEFF2);
        iconColor = isDark ? AppColors.darkSecondary : AppColors.lightSecondary;
        iconData = Icons.category_rounded;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
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
