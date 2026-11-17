import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class SettlivThemeExtension extends ThemeExtension<SettlivThemeExtension> {
  final Color canvas;
  final Color surface;
  final Color raised;
  final Color hairline;
  final Color ink;
  final Color secondary;
  final Color tertiary;
  final Color emerald;
  final Color emeraldTint;
  final Color coral;
  final Color coralTint;
  final Color saffron;
  final Color saffronTint;
  final Color teal;
  final Color tealTint;
  final Color orchid;
  final Color orchidTint;
  final Color sapphire;
  final Color glassFillLevel1;
  final Color glassFillLevel2;
  final Color glassFillLevel3;
  final Color glassBorder;
  final bool isDark;

  const SettlivThemeExtension({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.hairline,
    required this.ink,
    required this.secondary,
    required this.tertiary,
    required this.emerald,
    required this.emeraldTint,
    required this.coral,
    required this.coralTint,
    required this.saffron,
    required this.saffronTint,
    required this.teal,
    required this.tealTint,
    required this.orchid,
    required this.orchidTint,
    required this.sapphire,
    required this.glassFillLevel1,
    required this.glassFillLevel2,
    required this.glassFillLevel3,
    required this.glassBorder,
    required this.isDark,
  });

  static const light = SettlivThemeExtension(
    canvas: AppColors.lightBase,
    surface: Colors.white,
    raised: Color(0xFFF8FAFD),
    hairline: Color(0x1A0F1633),
    ink: AppColors.lightInk,
    secondary: AppColors.lightSecondary,
    tertiary: AppColors.lightTertiary,
    emerald: AppColors.emerald,
    emeraldTint: AppColors.emeraldTint,
    coral: AppColors.coral,
    coralTint: AppColors.coralTint,
    saffron: AppColors.amber,
    saffronTint: AppColors.amberTint,
    teal: AppColors.aqua,
    tealTint: AppColors.aquaTint,
    orchid: AppColors.lilac,
    orchidTint: AppColors.lilacTint,
    sapphire: AppColors.sapphire,
    glassFillLevel1: Color(0x73FFFFFF), // 45%
    glassFillLevel2: Color(0xA6FFFFFF), // 65%
    glassFillLevel3: Color(0xCCFFFFFF), // 80%
    glassBorder: Color(0x99FFFFFF),     // 60% white
    isDark: false,
  );

  static const dark = SettlivThemeExtension(
    canvas: AppColors.darkBase,
    surface: Color(0xFF10162A),
    raised: Color(0xFF172038),
    hairline: Color(0x2EFFFFFF),
    ink: AppColors.darkInk,
    secondary: AppColors.darkSecondary,
    tertiary: AppColors.darkTertiary,
    emerald: AppColors.emerald,
    emeraldTint: Color(0x3312B48A),
    coral: AppColors.coral,
    coralTint: Color(0x33F0614F),
    saffron: AppColors.amber,
    saffronTint: Color(0x33F5B544),
    teal: AppColors.aqua,
    tealTint: Color(0x3322C3D6),
    orchid: AppColors.lilac,
    orchidTint: Color(0x338B7CFF),
    sapphire: AppColors.sapphire,
    glassFillLevel1: Color(0x14FFFFFF), // 8%
    glassFillLevel2: Color(0x1FFFFFFF), // 12%
    glassFillLevel3: Color(0x29FFFFFF), // 16%
    glassBorder: Color(0x38FFFFFF),     // 22% white
    isDark: true,
  );

  @override
  SettlivThemeExtension copyWith({
    Color? canvas,
    Color? surface,
    Color? raised,
    Color? hairline,
    Color? ink,
    Color? secondary,
    Color? tertiary,
    Color? emerald,
    Color? emeraldTint,
    Color? coral,
    Color? coralTint,
    Color? saffron,
    Color? saffronTint,
    Color? teal,
    Color? tealTint,
    Color? orchid,
    Color? orchidTint,
    Color? sapphire,
    Color? glassFillLevel1,
    Color? glassFillLevel2,
    Color? glassFillLevel3,
    Color? glassBorder,
    bool? isDark,
  }) {
    return SettlivThemeExtension(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      raised: raised ?? this.raised,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      secondary: secondary ?? this.secondary,
      tertiary: tertiary ?? this.tertiary,
      emerald: emerald ?? this.emerald,
      emeraldTint: emeraldTint ?? this.emeraldTint,
      coral: coral ?? this.coral,
      coralTint: coralTint ?? this.coralTint,
      saffron: saffron ?? this.saffron,
      saffronTint: saffronTint ?? this.saffronTint,
      teal: teal ?? this.teal,
      tealTint: tealTint ?? this.tealTint,
      orchid: orchid ?? this.orchid,
      orchidTint: orchidTint ?? this.orchidTint,
      sapphire: sapphire ?? this.sapphire,
      glassFillLevel1: glassFillLevel1 ?? this.glassFillLevel1,
      glassFillLevel2: glassFillLevel2 ?? this.glassFillLevel2,
      glassFillLevel3: glassFillLevel3 ?? this.glassFillLevel3,
      glassBorder: glassBorder ?? this.glassBorder,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  SettlivThemeExtension lerp(
      ThemeExtension<SettlivThemeExtension>? other, double t) {
    if (other is! SettlivThemeExtension) return this;
    return SettlivThemeExtension(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      emeraldTint: Color.lerp(emeraldTint, other.emeraldTint, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralTint: Color.lerp(coralTint, other.coralTint, t)!,
      saffron: Color.lerp(saffron, other.saffron, t)!,
      saffronTint: Color.lerp(saffronTint, other.saffronTint, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealTint: Color.lerp(tealTint, other.tealTint, t)!,
      orchid: Color.lerp(orchid, other.orchid, t)!,
      orchidTint: Color.lerp(orchidTint, other.orchidTint, t)!,
      sapphire: Color.lerp(sapphire, other.sapphire, t)!,
      glassFillLevel1:
          Color.lerp(glassFillLevel1, other.glassFillLevel1, t)!,
      glassFillLevel2:
          Color.lerp(glassFillLevel2, other.glassFillLevel2, t)!,
      glassFillLevel3:
          Color.lerp(glassFillLevel3, other.glassFillLevel3, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBase,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      colorScheme: const ColorScheme.light(
        primary: AppColors.sapphire,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.lightInk,
        error: AppColors.coral,
        onError: Colors.white,
      ),
      extensions: const [SettlivThemeExtension.light],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBase,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.sapphire,
        onPrimary: Colors.white,
        surface: Color(0xFF10162A),
        onSurface: AppColors.darkInk,
        error: AppColors.coral,
        onError: Colors.white,
      ),
      extensions: const [SettlivThemeExtension.dark],
    );
  }
}

extension BuildContextThemeX on BuildContext {
  SettlivThemeExtension get settliv =>
      Theme.of(this).extension<SettlivThemeExtension>() ??
      SettlivThemeExtension.light;

  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
