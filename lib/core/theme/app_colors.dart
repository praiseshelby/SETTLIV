import 'package:flutter/material.dart';

abstract class AppColors {
  // Light Palette
  static const Color lightCanvas = Color(0xFFF5F3EE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightRaised = Color(0xFFFAF8F4);
  static const Color lightHairline = Color(0xFFE7E3DA);

  static const Color lightInk = Color(0xFF121826);
  static const Color lightSecondary = Color(0xFF667085);
  static const Color lightTertiary = Color(0xFF98A2B3);

  // Midnight Navy & Accents
  static const Color midnightNavy = Color(0xFF0E1A3A);
  static const Color navy600 = Color(0xFF1B2C5E);
  static const Color navy700 = Color(0xFF132044);
  static const Color cobaltGlow = Color(0xFF3B5BDB);

  // Liv Emerald (Owed / Positive)
  static const Color emerald = Color(0xFF0FA37F);
  static const Color emeraldTint = Color(0xFFDDF5EC);
  static const Color emeraldBright = Color(0xFF34D399);

  // Coral (You owe / Destructive)
  static const Color coral = Color(0xFFEF5B48);
  static const Color coralTint = Color(0xFFFDE7E3);
  static const Color coralBright = Color(0xFFFF7A66);

  // Saffron (Warmth, Trip energy)
  static const Color saffron = Color(0xFFF4A52C);
  static const Color saffronTint = Color(0xFFFDF0D5);
  static const Color saffronBright = Color(0xFFFFBE55);

  // Teal Lagoon
  static const Color teal = Color(0xFF1AA6B7);
  static const Color tealTint = Color(0xFFDAF1F4);
  static const Color tealBright = Color(0xFF36C5D6);

  // Orchid
  static const Color orchid = Color(0xFF8E6BEA);
  static const Color orchidTint = Color(0xFFEBE4FB);
  static const Color orchidBright = Color(0xFFA58CF5);

  // Dark Palette
  static const Color darkCanvas = Color(0xFF0B0F1A);
  static const Color darkSurface = Color(0xFF131A2B);
  static const Color darkRaised = Color(0xFF1A2338);
  static const Color darkHairline = Color(0xFF243049);

  static const Color darkInk = Color(0xFFF2F4F8);
  static const Color darkSecondary = Color(0xFF9AA5BA);
  static const Color darkTertiary = Color(0xFF606D85);

  // Hero Card Gradient Colors
  static const List<Color> heroGradientLight = [
    Color(0xFF0E1A3A),
    Color(0xFF1B2C5E),
    Color(0xFF132044),
  ];

  static const List<Color> heroGradientDark = [
    Color(0xFF172346),
    Color(0xFF1E2E5C),
    Color(0xFF121B35),
  ];

  // 8 Duotone Avatar Pair Gradients
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF0E1A3A), Color(0xFF3B5BDB)], // Navy / Cobalt
    [Color(0xFF0FA37F), Color(0xFF1AA6B7)], // Emerald / Teal
    [Color(0xFFEF5B48), Color(0xFFF4A52C)], // Coral / Saffron
    [Color(0xFF8E6BEA), Color(0xFF3B5BDB)], // Orchid / Cobalt
    [Color(0xFF1AA6B7), Color(0xFF0FA37F)], // Teal / Emerald
    [Color(0xFFF4A52C), Color(0xFFEF5B48)], // Saffron / Coral
    [Color(0xFF0E1A3A), Color(0xFF8E6BEA)], // Navy / Orchid
    [Color(0xFFE04870), Color(0xFFEF5B48)], // Rose / Coral
  ];
}
