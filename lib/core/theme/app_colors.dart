import 'package:flutter/material.dart';

abstract class AppColors {
  // Light Palette ("Quiet Fintech" / Linear / Revolut style)
  static const Color lightCanvas = Color(0xFFF5F3EE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightRaised = Color(0xFFECE7DE);
  static const Color lightHairline = Color(0xFFE7E3DA);
  static const Color lightInk = Color(0xFF121826);
  static const Color lightMuted = Color(0xFF5B6272); // AA safe > 5.5:1
  static const Color lightTertiary = Color(0xFF8C93A3);

  // Dark Palette (Designed, not inverted)
  static const Color darkCanvas = Color(0xFF0B1020);
  static const Color darkSurface = Color(0xFF131A2E);
  static const Color darkRaised = Color(0xFF1A2340);
  static const Color darkHairline = Color(0xFF26304D);
  static const Color darkInk = Color(0xFFECEAE4);
  static const Color darkMuted = Color(0xFFA3A9BA); // AA safe > 5.7:1
  static const Color darkTertiary = Color(0xFF6B758E);

  // Anchor Navy
  static const Color navy = Color(0xFF0E1A3A);
  static const Color navyLighter = Color(0xFF17254D);
  static const Color offWhite = Color(0xFFECEAE4);

  // Semantic Money & State
  static const Color emerald = Color(0xFF0FA37F);
  static const Color textEmeraldLight = Color(0xFF086A51); // AA safe on light > 5.8:1
  static const Color textEmeraldDark = Color(0xFF34D399);  // AA safe on dark > 7:1
  static const Color emeraldTintLight = Color(0x1F0FA37F);
  static const Color emeraldTintDark = Color(0x2E0FA37F);

  static const Color coral = Color(0xFFEF5B48);
  static const Color textCoralLight = Color(0xFFB52617);   // AA safe on light > 5.8:1
  static const Color textCoralDark = Color(0xFFF87171);    // AA safe on dark > 4.8:1
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
    [Color(0xFF0E1A3A), Color(0xFF3A558F)], // Navy / Slate
    [Color(0xFF086A51), Color(0xFF1AA6B7)], // Forest / Teal
    [Color(0xFFB52617), Color(0xFFF4A52C)], // Crimson / Saffron
    [Color(0xFF5B3E96), Color(0xFF8E6BEA)], // Plum / Orchid
    [Color(0xFF144D53), Color(0xFF0FA37F)], // Deep Teal / Emerald
    [Color(0xFF8C3E14), Color(0xFFEF5B48)], // Burnt Amber / Coral
    [Color(0xFF1B2F5B), Color(0xFF1AA6B7)], // Midnight / Teal
    [Color(0xFF5E2B68), Color(0xFF8E6BEA)], // Wine / Orchid
  ];

  // 6 Themes for Group Covers: Arcs, Waves, Contours, Orbits, Flatmates, GoaTrip
  static const List<List<Color>> coverThemes = [
    // 0: Arcs (Navy / Teal)
    [Color(0xFF0E1A3A), Color(0xFF1AA6B7), Color(0xFF3A558F)],
    // 1: Waves (Forest / Emerald)
    [Color(0xFF0A3326), Color(0xFF0FA37F), Color(0xFF266650)],
    // 2: Contours (Deep Slate / Saffron)
    [Color(0xFF181F33), Color(0xFFF4A52C), Color(0xFF3B486B)],
    // 3: Orbits (Plum / Orchid)
    [Color(0xFF24153E), Color(0xFF8E6BEA), Color(0xFF4C307B)],
    // 4: Flatmates (Classic Navy / Lilac)
    [Color(0xFF0E1A3A), Color(0xFF8E6BEA), Color(0xFF25345C)],
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
