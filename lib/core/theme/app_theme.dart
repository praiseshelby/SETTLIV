import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
export 'app_colors.dart';

class SettlivThemeExtension extends ThemeExtension<SettlivThemeExtension> {
  // Surfaces
  final Color canvas;
  final Color surface;
  final Color raised;
  final Color hairline;

  // Text / Inks
  final Color ink;
  final Color muted;
  final Color tertiary;

  // Anchor & Primary Buttons
  final Color navy;
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

  // Custom Painter Tokens
  final Color heroMeshStart;
  final Color heroMeshEnd;
  final Color heroMeshAccent;
  final List<List<Color>> avatarGradients;
  final List<List<Color>> coverThemePalettes;

  final bool isDark;

  const SettlivThemeExtension({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.hairline,
    required this.ink,
    required this.muted,
    required this.tertiary,
    required this.navy,
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
    raised: AppColors.lightRaised,
    hairline: AppColors.lightHairline,
    ink: AppColors.lightInk,
    muted: AppColors.lightMuted,
    tertiary: AppColors.lightTertiary,
    navy: AppColors.navy,
    onNavy: Color(0xFFFFFFFF),
    primaryButtonBg: AppColors.navy,
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
    scrim: Color(0x660E1A3A),
    transparent: Color(0x00000000),
    white: Color(0xFFFFFFFF),
    black: Color(0xFF000000),
    shadow: Color(0x1F0E1A3A),
    barSurface: Color(0xE6FFFFFF), // ~90% white
    heroMeshStart: AppColors.navy,
    heroMeshEnd: Color(0xFF1B2E5E),
    heroMeshAccent: Color(0xFF263F7C),
    avatarGradients: AppColors.avatarGradients,
    coverThemePalettes: AppColors.coverThemes,
    isDark: false,
  );

  static const dark = SettlivThemeExtension(
    canvas: AppColors.darkCanvas,
    surface: AppColors.darkSurface,
    raised: AppColors.darkRaised,
    hairline: AppColors.darkHairline,
    ink: AppColors.darkInk,
    muted: AppColors.darkMuted,
    tertiary: AppColors.darkTertiary,
    navy: AppColors.navy,
    onNavy: AppColors.darkInk,
    primaryButtonBg: AppColors.offWhite,
    primaryButtonText: AppColors.navy,
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
    scrim: Color(0x99000000),
    transparent: Color(0x00000000),
    white: Color(0xFFFFFFFF),
    black: Color(0xFF000000),
    shadow: Color(0x66000000),
    barSurface: Color(0xE6131A2E), // ~90% dark surface
    heroMeshStart: Color(0xFF0A1227),
    heroMeshEnd: Color(0xFF131D3B),
    heroMeshAccent: Color(0xFF1A274E),
    avatarGradients: AppColors.avatarGradients,
    coverThemePalettes: AppColors.coverThemes,
    isDark: true,
  );

  @override
  SettlivThemeExtension copyWith({
    Color? canvas,
    Color? surface,
    Color? raised,
    Color? hairline,
    Color? ink,
    Color? muted,
    Color? tertiary,
    Color? navy,
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
      raised: raised ?? this.raised,
      hairline: hairline ?? this.hairline,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      tertiary: tertiary ?? this.tertiary,
      navy: navy ?? this.navy,
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
      heroMeshStart: heroMeshStart ?? this.heroMeshStart,
      heroMeshEnd: heroMeshEnd ?? this.heroMeshEnd,
      heroMeshAccent: heroMeshAccent ?? this.heroMeshAccent,
      avatarGradients: avatarGradients ?? this.avatarGradients,
      coverThemePalettes: coverThemePalettes ?? this.coverThemePalettes,
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
      muted: Color.lerp(muted, other.muted, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      navy: Color.lerp(navy, other.navy, t)!,
      onNavy: Color.lerp(onNavy, other.onNavy, t)!,
      primaryButtonBg: Color.lerp(primaryButtonBg, other.primaryButtonBg, t)!,
      primaryButtonText:
          Color.lerp(primaryButtonText, other.primaryButtonText, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      textEmerald: Color.lerp(textEmerald, other.textEmerald, t)!,
      emeraldTint: Color.lerp(emeraldTint, other.emeraldTint, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      textCoral: Color.lerp(textCoral, other.textCoral, t)!,
      coralTint: Color.lerp(coralTint, other.coralTint, t)!,
      saffron: Color.lerp(saffron, other.saffron, t)!,
      saffronTint: Color.lerp(saffronTint, other.saffronTint, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealTint: Color.lerp(tealTint, other.tealTint, t)!,
      orchid: Color.lerp(orchid, other.orchid, t)!,
      orchidTint: Color.lerp(orchidTint, other.orchidTint, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      transparent: transparent,
      white: white,
      black: black,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      barSurface: Color.lerp(barSurface, other.barSurface, t)!,
      heroMeshStart: Color.lerp(heroMeshStart, other.heroMeshStart, t)!,
      heroMeshEnd: Color.lerp(heroMeshEnd, other.heroMeshEnd, t)!,
      heroMeshAccent: Color.lerp(heroMeshAccent, other.heroMeshAccent, t)!,
      avatarGradients: t < 0.5 ? avatarGradients : other.avatarGradients,
      coverThemePalettes:
          t < 0.5 ? coverThemePalettes : other.coverThemePalettes,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightCanvas,
      canvasColor: AppColors.lightCanvas,
      cardColor: AppColors.lightSurface,
      dividerColor: AppColors.lightHairline,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      colorScheme: const ColorScheme.light(
        primary: AppColors.navy,
        onPrimary: Color(0xFFFFFFFF),
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightInk,
        error: AppColors.coral,
        onError: Color(0xFFFFFFFF),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.lightHairline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.navy,
        selectionColor: AppColors.navy.withValues(alpha: 0.2),
        selectionHandleColor: AppColors.navy,
      ),
      extensions: const [SettlivThemeExtension.light],
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkCanvas,
      canvasColor: AppColors.darkCanvas,
      cardColor: AppColors.darkSurface,
      dividerColor: AppColors.darkHairline,
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFamilyFallback,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.offWhite,
        onPrimary: AppColors.navy,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkInk,
        error: AppColors.coral,
        onError: Color(0xFFFFFFFF),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.darkHairline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkRaised,
        contentTextStyle: const TextStyle(
          color: AppColors.darkInk,
          fontFamily: AppTypography.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.offWhite,
        selectionColor: AppColors.offWhite.withValues(alpha: 0.25),
        selectionHandleColor: AppColors.offWhite,
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
