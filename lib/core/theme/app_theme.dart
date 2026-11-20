import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
export 'app_colors.dart';

class SettlivThemeExtension extends ThemeExtension<SettlivThemeExtension> {
  // Surfaces
  final Color canvas;
  final Color surface;
  final Color surfaceSolid;
  final Color raised;
  final Color hairline;
  final Color innerHighlight;

  // Text / Inks
  final Color ink;
  final Color muted;
  final Color tertiary;

  // Anchor & Primary Buttons & Accent
  final Color navy;
  final Color accent;
  final Color onNavy;
  final Color primaryButtonBg;
  final Color primaryButtonText;

  // Semantic Money & State
  final Color emerald;
  final Color textEmerald;
  final Color emeraldTint;
  final Color coral;
  final Color textCoral;
  final Color coralTint;

  // Accents (Categories & Charts ONLY)
  final Color saffron;
  final Color saffronTint;
  final Color teal;
  final Color tealTint;
  final Color orchid;
  final Color orchidTint;

  // Overlays, Bars, Shadows & Scrims
  final Color scrim;
  final Color transparent;
  final Color white;
  final Color black;
  final Color shadow;
  final Color barSurface;

  // Aurora & Mesh
  final Color auroraViolet;
  final Color auroraBlue;
  final Color canvasWash;
  final Color heroMeshStart;
  final Color heroMeshEnd;
  final Color heroMeshAccent;
  final List<List<Color>> avatarGradients;
  final List<List<Color>> coverThemePalettes;

  final bool isDark;

  const SettlivThemeExtension({
    required this.canvas,
    required this.surface,
    required this.surfaceSolid,
    required this.raised,
    required this.hairline,
    required this.innerHighlight,
    required this.ink,
    required this.muted,
    required this.tertiary,
    required this.navy,
    required this.accent,
    required this.onNavy,
    required this.primaryButtonBg,
    required this.primaryButtonText,
    required this.emerald,
    required this.textEmerald,
    required this.emeraldTint,
    required this.coral,
    required this.textCoral,
    required this.coralTint,
    required this.saffron,
    required this.saffronTint,
    required this.teal,
    required this.tealTint,
    required this.orchid,
    required this.orchidTint,
    required this.scrim,
    required this.transparent,
    required this.white,
    required this.black,
    required this.shadow,
    required this.barSurface,
    required this.auroraViolet,
    required this.auroraBlue,
    required this.canvasWash,
    required this.heroMeshStart,
    required this.heroMeshEnd,
    required this.heroMeshAccent,
    required this.avatarGradients,
    required this.coverThemePalettes,
    required this.isDark,
  });

  // Convenience alias for existing secondary uses
  Color get secondary => muted;

  static const light = SettlivThemeExtension(
    canvas: AppColors.lightCanvas,
    surface: AppColors.lightSurface,
    surfaceSolid: AppColors.lightSurfaceSolid,
    raised: AppColors.lightRaised,
    hairline: AppColors.lightHairline,
    innerHighlight: Color(0xFFFFFFFF),
    ink: AppColors.lightInk,
    muted: AppColors.lightMuted,
    tertiary: AppColors.lightTertiary,
    navy: AppColors.anchorIndigo,
    accent: AppColors.accentViolet,
    onNavy: Color(0xFFFFFFFF),
    primaryButtonBg: AppColors.anchorIndigo,
    primaryButtonText: Color(0xFFFFFFFF),
    emerald: AppColors.emerald,
    textEmerald: AppColors.textEmeraldLight,
    emeraldTint: AppColors.emeraldTintLight,
    coral: AppColors.coral,
    textCoral: AppColors.textCoralLight,
    coralTint: AppColors.coralTintLight,
    saffron: AppColors.saffron,
    saffronTint: AppColors.saffronTint,
    teal: AppColors.teal,
    tealTint: AppColors.tealTint,
    orchid: AppColors.orchid,
    orchidTint: AppColors.orchidTint,
    scrim: Color(0x66000000),
    transparent: Color(0x00000000),
    white: Color(0xFFFFFFFF),
    black: Color(0xFF000000),
    shadow: Color(0xFF16193F),
    barSurface: Color(0xE0FFFFFF), // ~88% opacity
    auroraViolet: AppColors.lightAuroraViolet,
    auroraBlue: AppColors.lightAuroraBlue,
    canvasWash: Color(0x00000000),
    heroMeshStart: Color(0xFF16193F),
    heroMeshEnd: Color(0xFF0F122F),
    heroMeshAccent: Color(0xFF5B4BDB),
    avatarGradients: AppColors.avatarGradients,
    coverThemePalettes: AppColors.coverThemes,
    isDark: false,
  );

  static const dark = SettlivThemeExtension(
    canvas: AppColors.darkCanvas,
    surface: AppColors.darkSurface,
    surfaceSolid: AppColors.darkSurfaceSolid,
    raised: AppColors.darkRaised,
    hairline: AppColors.darkHairline,
    innerHighlight: Color(0x1AFFFFFF),
    ink: AppColors.darkInk,
    muted: AppColors.darkMuted,
    tertiary: AppColors.darkTertiary,
    navy: AppColors.anchorIndigo,
    accent: AppColors.accentViolet,
    onNavy: Color(0xFFECEBF5),
    primaryButtonBg: AppColors.offWhite,
    primaryButtonText: AppColors.lightInk,
    emerald: AppColors.emerald,
    textEmerald: AppColors.textEmeraldDark,
    emeraldTint: AppColors.emeraldTintDark,
    coral: AppColors.coral,
    textCoral: AppColors.textCoralDark,
    coralTint: AppColors.coralTintDark,
    saffron: AppColors.saffron,
    saffronTint: AppColors.saffronTint,
    teal: AppColors.teal,
    tealTint: AppColors.tealTint,
    orchid: AppColors.orchid,
    orchidTint: AppColors.orchidTint,
    scrim: Color(0x80000000),
    transparent: Color(0x00000000),
    white: Color(0xFFFFFFFF),
    black: Color(0xFF000000),
    shadow: Color(0xFF000000),
    barSurface: Color(0xE012142A), // ~88% opacity
    auroraViolet: Color(0x1F5B4BDB),
    auroraBlue: Color(0x183F4685),
    canvasWash: AppColors.darkCanvasWash,
    heroMeshStart: Color(0xFF16193F),
    heroMeshEnd: Color(0xFF0A0C1C),
    heroMeshAccent: Color(0xFF5B4BDB),
    avatarGradients: AppColors.avatarGradients,
    coverThemePalettes: AppColors.coverThemes,
    isDark: true,
  );

  @override
  SettlivThemeExtension copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceSolid,
    Color? raised,
    Color? hairline,
    Color? innerHighlight,
    Color? ink,
    Color? muted,
    Color? tertiary,
    Color? navy,
    Color? accent,
    Color? onNavy,
    Color? primaryButtonBg,
    Color? primaryButtonText,
    Color? emerald,
    Color? textEmerald,
    Color? emeraldTint,
    Color? coral,
    Color? textCoral,
    Color? coralTint,
    Color? saffron,
    Color? saffronTint,
    Color? teal,
    Color? tealTint,
    Color? orchid,
    Color? orchidTint,
    Color? scrim,
    Color? transparent,
    Color? white,
    Color? black,
    Color? shadow,
    Color? barSurface,
    Color? auroraViolet,
    Color? auroraBlue,
    Color? canvasWash,
    Color? heroMeshStart,
    Color? heroMeshEnd,
    Color? heroMeshAccent,
    List<List<Color>>? avatarGradients,
    List<List<Color>>? coverThemePalettes,
    bool? isDark,
  }) {
    return SettlivThemeExtension(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceSolid: surfaceSolid ?? this.surfaceSolid,
      raised: raised ?? this.raised,
      hairline: hairline ?? this.hairline,
      innerHighlight: innerHighlight ?? this.innerHighlight,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      tertiary: tertiary ?? this.tertiary,
      navy: navy ?? this.navy,
      accent: accent ?? this.accent,
      onNavy: onNavy ?? this.onNavy,
      primaryButtonBg: primaryButtonBg ?? this.primaryButtonBg,
      primaryButtonText: primaryButtonText ?? this.primaryButtonText,
      emerald: emerald ?? this.emerald,
      textEmerald: textEmerald ?? this.textEmerald,
      emeraldTint: emeraldTint ?? this.emeraldTint,
      coral: coral ?? this.coral,
      textCoral: textCoral ?? this.textCoral,
      coralTint: coralTint ?? this.coralTint,
      saffron: saffron ?? this.saffron,
      saffronTint: saffronTint ?? this.saffronTint,
      teal: teal ?? this.teal,
      tealTint: tealTint ?? this.tealTint,
      orchid: orchid ?? this.orchid,
      orchidTint: orchidTint ?? this.orchidTint,
      scrim: scrim ?? this.scrim,
      transparent: transparent ?? this.transparent,
      white: white ?? this.white,
      black: black ?? this.black,
      shadow: shadow ?? this.shadow,
      barSurface: barSurface ?? this.barSurface,
      auroraViolet: auroraViolet ?? this.auroraViolet,
      auroraBlue: auroraBlue ?? this.auroraBlue,
      canvasWash: canvasWash ?? this.canvasWash,
      heroMeshStart: heroMeshStart ?? this.heroMeshStart,
      heroMeshEnd: heroMeshEnd ?? this.heroMeshEnd,
      heroMeshAccent: heroMeshAccent ?? this.heroMeshAccent,
      avatarGradients: avatarGradients ?? this.avatarGradients,
      coverThemePalettes: coverThemePalettes ?? this.coverThemePalettes,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  SettlivThemeExtension lerp(ThemeExtension<SettlivThemeExtension>? other, double t) {
    if (other is! SettlivThemeExtension) return this;
    return SettlivThemeExtension(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceSolid: Color.lerp(surfaceSolid, other.surfaceSolid, t) ?? surfaceSolid,
      raised: Color.lerp(raised, other.raised, t) ?? raised,
      hairline: Color.lerp(hairline, other.hairline, t) ?? hairline,
      innerHighlight: Color.lerp(innerHighlight, other.innerHighlight, t) ?? innerHighlight,
      ink: Color.lerp(ink, other.ink, t) ?? ink,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      tertiary: Color.lerp(tertiary, other.tertiary, t) ?? tertiary,
      navy: Color.lerp(navy, other.navy, t) ?? navy,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      onNavy: Color.lerp(onNavy, other.onNavy, t) ?? onNavy,
      primaryButtonBg: Color.lerp(primaryButtonBg, other.primaryButtonBg, t) ?? primaryButtonBg,
      primaryButtonText: Color.lerp(primaryButtonText, other.primaryButtonText, t) ?? primaryButtonText,
      emerald: Color.lerp(emerald, other.emerald, t) ?? emerald,
      textEmerald: Color.lerp(textEmerald, other.textEmerald, t) ?? textEmerald,
      emeraldTint: Color.lerp(emeraldTint, other.emeraldTint, t) ?? emeraldTint,
      coral: Color.lerp(coral, other.coral, t) ?? coral,
      textCoral: Color.lerp(textCoral, other.textCoral, t) ?? textCoral,
      coralTint: Color.lerp(coralTint, other.coralTint, t) ?? coralTint,
      saffron: Color.lerp(saffron, other.saffron, t) ?? saffron,
      saffronTint: Color.lerp(saffronTint, other.saffronTint, t) ?? saffronTint,
      teal: Color.lerp(teal, other.teal, t) ?? teal,
      tealTint: Color.lerp(tealTint, other.tealTint, t) ?? tealTint,
      orchid: Color.lerp(orchid, other.orchid, t) ?? orchid,
      orchidTint: Color.lerp(orchidTint, other.orchidTint, t) ?? orchidTint,
      scrim: Color.lerp(scrim, other.scrim, t) ?? scrim,
      transparent: transparent,
      white: white,
      black: black,
      shadow: Color.lerp(shadow, other.shadow, t) ?? shadow,
      barSurface: Color.lerp(barSurface, other.barSurface, t) ?? barSurface,
      auroraViolet: Color.lerp(auroraViolet, other.auroraViolet, t) ?? auroraViolet,
      auroraBlue: Color.lerp(auroraBlue, other.auroraBlue, t) ?? auroraBlue,
      canvasWash: Color.lerp(canvasWash, other.canvasWash, t) ?? canvasWash,
      heroMeshStart: Color.lerp(heroMeshStart, other.heroMeshStart, t) ?? heroMeshStart,
      heroMeshEnd: Color.lerp(heroMeshEnd, other.heroMeshEnd, t) ?? heroMeshEnd,
      heroMeshAccent: Color.lerp(heroMeshAccent, other.heroMeshAccent, t) ?? heroMeshAccent,
      avatarGradients: t < 0.5 ? avatarGradients : other.avatarGradients,
      coverThemePalettes: t < 0.5 ? coverThemePalettes : other.coverThemePalettes,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

extension SettlivThemeContext on BuildContext {
  SettlivThemeExtension get settliv =>
      Theme.of(this).extension<SettlivThemeExtension>() ?? SettlivThemeExtension.light;
}

class AppTheme {
  static ThemeData light() => lightTheme;
  static ThemeData dark() => darkTheme;

  static ThemeData get lightTheme {
    const ext = SettlivThemeExtension.light;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: ext.canvas,
      fontFamily: AppTypography.fontBody,
      extensions: const [ext],
      colorScheme: ColorScheme.light(
        surface: ext.surfaceSolid,
        primary: ext.navy,
        secondary: ext.accent,
        error: ext.coral,
        onSurface: ext.ink,
        onPrimary: ext.white,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightHairline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.lightInk),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static ThemeData get darkTheme {
    const ext = SettlivThemeExtension.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ext.canvas,
      fontFamily: AppTypography.fontBody,
      extensions: const [ext],
      colorScheme: ColorScheme.dark(
        surface: ext.surfaceSolid,
        primary: ext.primaryButtonBg,
        secondary: ext.accent,
        error: ext.coral,
        onSurface: ext.ink,
        onPrimary: ext.primaryButtonText,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkHairline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.darkInk),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
