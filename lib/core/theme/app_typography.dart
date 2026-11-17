import 'package:flutter/material.dart';

abstract class AppTypography {
  static const String fontFamily = 'Manrope';
  static const List<String> fontFamilyFallback = [
    'Manrope',
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  /// Hero balance number: 52 / 700 with tight tabular figures
  static const TextStyle heroMoney = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 52,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Standard display money: 40 / 700
  static const TextStyle displayMoney = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.15,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Screen and card titles: 22 / 700
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );

  /// Medium title / card header: 18-20 / 700
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// Section uppercase labels: 12 / 700 uppercase with 0.8 tracking
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1.3,
  );

  /// Section header (alias): 17 / 700
  static const TextStyle sectionHeader = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// Body text: 15 / 500
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    height: 1.4,
  );

  /// Body medium / semibold: 15 / 600
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.4,
  );

  /// Caption: 12-13 / 600
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.35,
  );

  /// Button label: 16 / 700
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.25,
  );

  /// Small chip label: 12 / 600
  static const TextStyle chip = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.25,
  );
}
