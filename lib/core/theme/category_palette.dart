import 'package:flutter/material.dart';
import '../../data/models/expense.dart';

class CategoryColors {
  final Color base;
  final Color tile;
  final Color icon;

  const CategoryColors({
    required this.base,
    required this.tile,
    required this.icon,
  });
}

class CategoryPalette {
  const CategoryPalette._();

  static CategoryColors getColors(ExpenseCategory category, {required bool isDark}) {
    switch (category) {
      case ExpenseCategory.food:
        // Saffron
        const baseLight = Color(0xFFD97706);
        const baseDark = Color(0xFFFBBF24);
        return CategoryColors(
          base: isDark ? baseDark : baseLight,
          tile: (isDark ? baseDark : baseLight).withOpacity(isDark ? 0.22 : 0.16),
          icon: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
        );

      case ExpenseCategory.rent:
        // Indigo / Periwinkle (NOT dark navy)
        // High contrast against dark surface (#12142A) and light surface (#FFFFFF)
        const baseLight = Color(0xFF4338CA);
        const baseDark = Color(0xFF818CF8);
        return CategoryColors(
          base: isDark ? baseDark : baseLight,
          tile: (isDark ? baseDark : baseLight).withOpacity(isDark ? 0.24 : 0.16),
          icon: isDark ? const Color(0xFFC7D2FE) : baseLight,
        );

      case ExpenseCategory.travel:
        // Teal
        const baseLight = Color(0xFF0F766E);
        const baseDark = Color(0xFF2DD4BF);
        return CategoryColors(
          base: isDark ? baseDark : baseLight,
          tile: (isDark ? baseDark : baseLight).withOpacity(isDark ? 0.22 : 0.16),
          icon: isDark ? const Color(0xFF99F6E4) : baseLight,
        );

      case ExpenseCategory.stay:
        // Violet
        const baseLight = Color(0xFF6D28D9);
        const baseDark = Color(0xFFA78BFA);
        return CategoryColors(
          base: isDark ? baseDark : baseLight,
          tile: (isDark ? baseDark : baseLight).withOpacity(isDark ? 0.22 : 0.16),
          icon: isDark ? const Color(0xFFDDD6FE) : baseLight,
        );

      case ExpenseCategory.groceries:
        // Emerald
        const baseLight = Color(0xFF047857);
        const baseDark = Color(0xFF34D399);
        return CategoryColors(
          base: isDark ? baseDark : baseLight,
          tile: (isDark ? baseDark : baseLight).withOpacity(isDark ? 0.22 : 0.16),
          icon: isDark ? const Color(0xFFA7F3D0) : baseLight,
        );

      case ExpenseCategory.bills:
        // Coral / Rose
        const baseLight = Color(0xFFBE123C);
        const baseDark = Color(0xFFFB7185);
        return CategoryColors(
          base: isDark ? baseDark : baseLight,
          tile: (isDark ? baseDark : baseLight).withOpacity(isDark ? 0.22 : 0.16),
          icon: isDark ? const Color(0xFFFECDD3) : baseLight,
        );

      case ExpenseCategory.fun:
        // Orchid / Purple
        const baseLight = Color(0xFF7E22CE);
        const baseDark = Color(0xFFC084FC);
        return CategoryColors(
          base: isDark ? baseDark : baseLight,
          tile: (isDark ? baseDark : baseLight).withOpacity(isDark ? 0.22 : 0.16),
          icon: isDark ? const Color(0xFFE9D5FF) : baseLight,
        );

      case ExpenseCategory.other:
        // Slate / Muted
        const baseLight = Color(0xFF475569);
        const baseDark = Color(0xFF94A3B8);
        return CategoryColors(
          base: isDark ? baseDark : baseLight,
          tile: (isDark ? baseDark : baseLight).withOpacity(isDark ? 0.22 : 0.16),
          icon: isDark ? const Color(0xFFCBD5E1) : baseLight,
        );
    }
  }

  static IconData getIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return Icons.restaurant_rounded;
      case ExpenseCategory.rent:
        return Icons.roofing_rounded;
      case ExpenseCategory.travel:
        return Icons.directions_car_filled_rounded;
      case ExpenseCategory.stay:
        return Icons.hotel_rounded;
      case ExpenseCategory.groceries:
        return Icons.shopping_basket_rounded;
      case ExpenseCategory.bills:
        return Icons.receipt_long_rounded;
      case ExpenseCategory.fun:
        return Icons.celebration_rounded;
      case ExpenseCategory.other:
        return Icons.category_rounded;
    }
  }
}
