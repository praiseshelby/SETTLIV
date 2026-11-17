import 'package:flutter/material.dart';

abstract class AppColors {
  // Light Palette ("Pearl Glass")
  static const Color lightBase = Color(0xFFF4F6FB);
  static const Color lightInk = Color(0xFF0F1633);
  static const Color lightSecondary = Color(0xFF5B6485);
  static const Color lightTertiary = Color(0xFF8B93B0);
  static const Color lightHairline = Color(0x1F0F1633); // ~12% ink
  static const Color lightGlassBorder = Color(0x99FFFFFF); // 60% white

  // Dark Palette ("Midnight Glass")
  static const Color darkBase = Color(0xFF080B1A);
  static const Color darkInk = Color(0xFFF5F7FF);
  static const Color darkSecondary = Color(0xFF8E98B8);
  static const Color darkTertiary = Color(0xFF5C6688);
  static const Color darkHairline = Color(0x26FFFFFF); // ~15% white
  static const Color darkGlassBorder = Color(0x2EFFFFFF); // ~18% white

  // Aurora Bloom Colors - Light
  static const Color auroraCobaltLight = Color(0x384F6BFF); // 22%
  static const Color auroraLilacLight = Color(0x2EA78BFA);  // 18%
  static const Color auroraAquaLight = Color(0x295EEAD4);   // 16%
  static const Color auroraPeachLight = Color(0x1FFFC8A8);  // 12%

  // Aurora Bloom Colors - Dark
  static const Color auroraCobaltDark = Color(0x593D5AFE); // 35%
  static const Color auroraVioletDark = Color(0x477C5CFF); // 28%
  static const Color auroraTealDark = Color(0x2E14B8A6);   // 18%

  // Premium Blue / Sapphire Anchor
  static const Color sapphire = Color(0xFF2744E8);
  static const Color sapphireStart = Color(0xFF2F4BFF);
  static const Color sapphireEnd = Color(0xFF1B2FBF);
  static const LinearGradient sapphireGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sapphireStart, sapphireEnd],
  );

  // Money Meaning (Emerald & Coral - calm, never neon)
  static const Color emerald = Color(0xFF12B48A);
  static const Color emeraldTint = Color(0x2412B48A); // 14% tint
  static const Color emeraldSoftBg = Color(0xFFE4F7F2);

  static const Color coral = Color(0xFFF0614F);
  static const Color coralTint = Color(0x24F0614F); // 14% tint
  static const Color coralSoftBg = Color(0xFFFDECE9);

  // Accents (Category tiles, charts, badges - low saturation, 14% tint)
  static const Color lilac = Color(0xFF8B7CFF);
  static const Color lilacTint = Color(0x248B7CFF);

  static const Color aqua = Color(0xFF22C3D6);
  static const Color aquaTint = Color(0x2422C3D6);

  static const Color amber = Color(0xFFF5B544);
  static const Color amberTint = Color(0x24F5B544);

  // Backward compatibility / convenience aliases for old references
  static const Color lightCanvas = lightBase;
  static const Color lightSurface = Colors.white;
  static const Color lightRaised = Color(0xFFF8FAFC);
  static const Color darkCanvas = darkBase;
  static const Color darkSurface = Color(0xFF10162A);
  static const Color darkRaised = Color(0xFF171F38);
  static const Color midnightNavy = sapphire;
  static const Color cobaltGlow = sapphire;
  static const Color saffron = amber;
  static const Color saffronTint = amberTint;
  static const Color saffronBright = amber;
  static const Color teal = aqua;
  static const Color tealTint = aquaTint;
  static const Color tealBright = aqua;
  static const Color orchid = lilac;
  static const Color orchidTint = lilacTint;
  static const Color orchidBright = lilac;
  static const Color emeraldBright = emerald;
  static const Color coralBright = coral;

  // 8 Curated Duotone Avatar Pair Gradients
  static const List<List<Color>> avatarGradients = [
    [Color(0xFF2F4BFF), Color(0xFF8B7CFF)], // Sapphire / Lilac
    [Color(0xFF12B48A), Color(0xFF22C3D6)], // Emerald / Aqua
    [Color(0xFFF0614F), Color(0xFFF5B544)], // Coral / Amber
    [Color(0xFF8B7CFF), Color(0xFF2F4BFF)], // Lilac / Sapphire
    [Color(0xFF22C3D6), Color(0xFF12B48A)], // Aqua / Emerald
    [Color(0xFFF5B544), Color(0xFFF0614F)], // Amber / Coral
    [Color(0xFF2744E8), Color(0xFF12B48A)], // Sapphire / Emerald
    [Color(0xFFD946EF), Color(0xFF8B7CFF)], // Rose / Lilac
  ];
}
