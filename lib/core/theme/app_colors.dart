import 'package:flutter/material.dart';

abstract class AppColors {
  // Light Palette ("Pearl Glass" with subtle violet wash)
  static const Color lightCanvas = Color(0xFFF6F7FC);
  static const Color lightSurface = Color(0xCCFFFFFF); // White at ~80%
  static const Color lightSurfaceSolid = Color(0xFFFFFFFF);
  static const Color lightRaised = Color(0xFFFFFFFF);
  static const Color lightHairline = Color(0xFFE3E5F1);
  static const Color lightInk = Color(0xFF12132B);
  static const Color lightMuted = Color(0xFF5A5F7A); // AA safe > 5.5:1 on light canvas/surface
  static const Color lightTertiary = Color(0xFF888DA8);
  static const Color lightAuroraViolet = Color(0xFFE9E5FF);
  static const Color lightAuroraBlue = Color(0xFFE4EEFF);

  // Dark Palette ("Midnight Glass" designed dark)
  static const Color darkCanvas = Color(0xFF0A0C1C);
  static const Color darkCanvasWash = Color(0xFF1A1640);
  static const Color darkSurface = Color(0xCC12142A); // #12142A at ~80%
  static const Color darkSurfaceSolid = Color(0xFF12142A);
  static const Color darkRaised = Color(0xFF191C3A);
  static const Color darkHairline = Color(0xFF272B4A);
  static const Color darkInk = Color(0xFFECEBF5);
  static const Color darkMuted = Color(0xFFA5A8C0); // AA safe > 5.8:1 on dark canvas/surface
  static const Color darkTertiary = Color(0xFF6B7190);

  // Anchor & Accent
  static const Color anchorIndigo = Color(0xFF16193F); // Deep Indigo-Navy
  static const Color accentViolet = Color(0xFF5B4BDB); // Focus rings, selected states, small links
  static const Color offWhite = Color(0xFFECEBF5);

  // Semantic Money & State
  static const Color emerald = Color(0xFF0FA37F);
  static const Color textEmeraldLight = Color(0xFF0A6E55); // High contrast on light
  static const Color textEmeraldDark = Color(0xFF4FE3B8);  // On-dark emerald
  static const Color emeraldTintLight = Color(0x1F0FA37F);
  static const Color emeraldTintDark = Color(0x2E0FA37F);

  static const Color coral = Color(0xFFEF5B48);
  static const Color textCoralLight = Color(0xFFBD3222);   // High contrast on light
  static const Color textCoralDark = Color(0xFFFF8D7C);    // On-dark coral
  static const Color coralTintLight = Color(0x1FEF5B48);
  static const Color coralTintDark = Color(0x2EEF5B48);

  // Category Accents (Used ONLY in category tiles and charts)
  static const Color saffron = Color(0xFFF4A52C);
  static const Color saffronTint = Color(0x24F4A52C);
  static const Color teal = Color(0xFF1AA6B7);
  static const Color tealTint = Color(0x241AA6B7);
  static const Color orchid = Color(0xFF8E6BEA);
  static const Color orchidTint = Color(0x248E6BEA);

  // 8 Curated Avatar Pair Gradients
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF16193F), Color(0xFF3F4685)], // Indigo / Slate
    [Color(0xFF0A6E55), Color(0xFF1AA6B7)], // Forest / Teal
    [Color(0xFFBD3222), Color(0xFFF4A52C)], // Crimson / Saffron
    [Color(0xFF5B4BDB), Color(0xFF8E6BEA)], // Accent / Orchid
    [Color(0xFF144D53), Color(0xFF0FA37F)], // Deep Teal / Emerald
    [Color(0xFF8C3E14), Color(0xFFEF5B48)], // Burnt Amber / Coral
    [Color(0xFF16193F), Color(0xFF1AA6B7)], // Deep Indigo / Teal
    [Color(0xFF4A154B), Color(0xFF8E6BEA)], // Plum / Orchid
  ];

  // 6 Themes for Group Covers: Arcs, Waves, Contours, Orbits, Flatmates, GoaTrip
  static const List<List<Color>> coverThemes = [
    // 0: Arcs (Indigo / Teal)
    [Color(0xFF16193F), Color(0xFF1AA6B7), Color(0xFF3F4685)],
    // 1: Waves (Forest / Emerald)
    [Color(0xFF0A3326), Color(0xFF0FA37F), Color(0xFF266650)],
    // 2: Contours (Deep Slate / Saffron)
    [Color(0xFF181F33), Color(0xFFF4A52C), Color(0xFF3B486B)],
    // 3: Orbits (Plum / Orchid)
    [Color(0xFF24153E), Color(0xFF8E6BEA), Color(0xFF4C307B)],
    // 4: Flatmates (Classic Indigo / Lilac)
    [Color(0xFF16193F), Color(0xFF8E6BEA), Color(0xFF2A2E63)],
    // 5: GoaTrip (Ocean Teal / Sun Coral)
    [Color(0xFF0C3843), Color(0xFF1AA6B7), Color(0xFFEF5B48)],
  ];
}

extension ColorValuesCompat on Color {
  Color withValues({double? alpha, double? red, double? green, double? blue}) {
    final int a = alpha != null ? (alpha * 255).round().clamp(0, 255) : this.alpha;
    final int r = red != null ? (red * 255).round().clamp(0, 255) : this.red;
    final int g = green != null ? (green * 255).round().clamp(0, 255) : this.green;
    final int b = blue != null ? (blue * 255).round().clamp(0, 255) : this.blue;
    return Color.fromARGB(a, r, g, b);
  }
}
