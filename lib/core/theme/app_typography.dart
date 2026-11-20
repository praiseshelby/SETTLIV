import 'package:flutter/material.dart';

abstract class AppTypography {
  static const String fontHeading = 'Sora';
  static const String fontBody = 'PlusJakartaSans';
  static const String fontFamily = fontBody;
  static const List<String> fontFamilyFallback = bodyFallback;

  static const List<String> headingFallback = [
    'PlusJakartaSans',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  static const List<String> bodyFallback = [
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  /// Screen titles: 28 / 700 (Sora)
  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontHeading,
    fontFamilyFallback: headingFallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
  );
  static const TextStyle titleLarge = screenTitle;

  /// Section titles: 17 / 700 (Sora)
  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontHeading,
    fontFamilyFallback: headingFallback,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );
  static const TextStyle sectionHeader = sectionTitle;
  static const TextStyle titleMedium = sectionTitle;

  /// Subheading / card titles: 19 / 700 (Sora)
  static const TextStyle titleCard = TextStyle(
    fontFamily: fontHeading,
    fontFamilyFallback: headingFallback,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  /// Money Hero: 42 / 800 (Sora) with tight tracking and tabular figures
  static const TextStyle moneyHero = TextStyle(
    fontFamily: fontHeading,
    fontFamilyFallback: headingFallback,
    fontSize: 42,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.4,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle heroMoney = moneyHero;

  /// Large Money: 32 / 800 (Sora)
  static const TextStyle moneyLarge = TextStyle(
    fontFamily: fontHeading,
    fontFamilyFallback: headingFallback,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle displayMoney = moneyLarge;

  /// Medium Money: 22 / 700 (Sora)
  static const TextStyle moneyMedium = TextStyle(
    fontFamily: fontHeading,
    fontFamilyFallback: headingFallback,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Regular Money: 16 / 700 (Sora)
  static const TextStyle moneyRegular = TextStyle(
    fontFamily: fontHeading,
    fontFamilyFallback: headingFallback,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Eyebrow labels: 11 / 700 with +0.6 tracking (Plus Jakarta Sans)
  static const TextStyle eyebrow = TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: bodyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    height: 1.2,
  );
  static const TextStyle sectionLabel = eyebrow;

  /// Body text: 15 / 500 (Plus Jakarta Sans)
  static const TextStyle body = TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: bodyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.4,
  );
  static const TextStyle bodyMedium = body;

  /// Body bold / semibold: 15 / 600 (Plus Jakarta Sans)
  static const TextStyle bodySemiBold = TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: bodyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  /// Captions: 12 / 600 (Plus Jakarta Sans)
  static const TextStyle caption = TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: bodyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.3,
  );
  static const TextStyle chip = caption;

  /// Small labels / tabs: 11 / 600 (Plus Jakarta Sans)
  static const TextStyle tabLabel = TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: bodyFallback,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  /// Inputs: 16 / 500 (Plus Jakarta Sans)
  static const TextStyle input = TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: bodyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.35,
  );

  /// Buttons: 15 / 600 (Plus Jakarta Sans)
  static const TextStyle button = TextStyle(
    fontFamily: fontBody,
    fontFamilyFallback: bodyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
  );
}
