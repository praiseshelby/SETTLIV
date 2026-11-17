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
  final Color heroCardBg;
  final List<Color> heroGradient;

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
    required this.heroCardBg,
    required this.heroGradient,
  });

  static const light = SettlivThemeExtension(
    canvas: AppColors.lightCanvas,
    surface: AppColors.lightSurface,
    raised: AppColors.lightRaised,
    hairline: AppColors.lightHairline,
    ink: AppColors.lightInk,
    secondary: AppColors.lightSecondary,
    tertiary: AppColors.lightTertiary,
    emerald: AppColors.emerald,
    emeraldTint: AppColors.emeraldTint,
    coral: AppColors.coral,
    coralTint: AppColors.coralTint,
    saffron: AppColors.saffron,
    saffronTint: AppColors.saffronTint,
    teal: AppColors.teal,
    tealTint: AppColors.tealTint,
    orchid: AppColors.orchid,
    orchidTint: AppColors.orchidTint,
    heroCardBg: AppColors.midnightNavy,
    heroGradient: AppColors.heroGradientLight,
  );

  static const dark = SettlivThemeExtension(
    canvas: AppColors.darkCanvas,
    surface: AppColors.darkSurface,
    raised: AppColors.darkRaised,
    hairline: AppColors.darkHairline,
    ink: AppColors.darkInk,
    secondary: AppColors.darkSecondary,
    tertiary: AppColors.darkTertiary,
    emerald: AppColors.emeraldBright,
    emeraldTint: Color(0xFF132F26),
    coral: AppColors.coralBright,
    coralTint: Color(0xFF381B19),
    saffron: AppColors.saffronBright,
    saffronTint: Color(0xFF382912),
    teal: AppColors.tealBright,
    tealTint: Color(0xFF132D33),
    orchid: AppColors.orchidBright,
    orchidTint: Color(0xFF271C3D),
    heroCardBg: Color(0xFF142144),
    heroGradient: AppColors.heroGradientDark,
  );

  @override
  ThemeExtension<SettlivThemeExtension> copyWith({
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
    Color? heroCardBg,
    List<Color>? heroGradient,
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
      heroCardBg: heroCardBg ?? this.heroCardBg,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  ThemeExtension<SettlivThemeExtension> lerp(
    covariant ThemeExtension<SettlivThemeExtension>? other,
    double t,
  ) {
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
      heroCardBg: Color.lerp(heroCardBg, other.heroCardBg, t)!,
      heroGradient: List.generate(
        heroGradient.length,
        (i) => Color.lerp(heroGradient[i], other.heroGradient[i], t)!,
      ),
    );
  }
}

extension BuildContextThemeExt on BuildContext {
  SettlivThemeExtension get settliv =>
      Theme.of(this).extension<SettlivThemeExtension>() ??
      SettlivThemeExtension.light;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}

abstract class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightCanvas,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      colorScheme: const ColorScheme.light(
        surface: AppColors.lightSurface,
        primary: AppColors.midnightNavy,
        secondary: AppColors.teal,
        error: AppColors.coral,
        onSurface: AppColors.lightInk,
        onPrimary: Colors.white,
      ),
      extensions: const [SettlivThemeExtension.light],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkCanvas,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.darkSurface,
        primary: AppColors.midnightNavy,
        secondary: AppColors.tealBright,
        error: AppColors.coralBright,
        onSurface: AppColors.darkInk,
        onPrimary: Colors.white,
      ),
      extensions: const [SettlivThemeExtension.dark],
    );
  }
}
