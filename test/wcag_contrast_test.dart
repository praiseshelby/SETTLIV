import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/theme/app_theme.dart';

double _linearize(double component) {
  return component <= 0.04045
      ? component / 12.92
      : math.pow((component + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color color) {
  final r = _linearize(color.red / 255.0);
  final g = _linearize(color.green / 255.0);
  final b = _linearize(color.blue / 255.0);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color foreground, Color background) {
  final l1 = _relativeLuminance(foreground);
  final l2 = _relativeLuminance(background);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG AA Contrast Verification', () {
    const light = SettlivThemeExtension.light;
    const dark = SettlivThemeExtension.dark;

    group('Light Theme Contrast', () {
      test('Primary text (ink) on surfaces meets WCAG AA (>= 4.5:1)', () {
        final ratioCanvas = contrastRatio(light.ink, light.canvas);
        final ratioSurface = contrastRatio(light.ink, light.surface);
        final ratioRaised = contrastRatio(light.ink, light.raised);

        expect(ratioCanvas, greaterThanOrEqualTo(4.5), reason: 'ink on light canvas');
        expect(ratioSurface, greaterThanOrEqualTo(4.5), reason: 'ink on light surface');
        expect(ratioRaised, greaterThanOrEqualTo(4.5), reason: 'ink on light raised');
      });

      test('Muted text on surfaces meets WCAG AA body (>= 4.5:1)', () {
        final ratioCanvas = contrastRatio(light.muted, light.canvas);
        final ratioSurface = contrastRatio(light.muted, light.surface);

        expect(ratioCanvas, greaterThanOrEqualTo(4.5), reason: 'muted on light canvas');
        expect(ratioSurface, greaterThanOrEqualTo(4.5), reason: 'muted on light surface');
      });

      test('Semantic text colors (emerald & coral) on surface meet WCAG AA (>= 4.5:1)', () {
        final ratioEmerald = contrastRatio(light.textEmerald, light.surface);
        final ratioCoral = contrastRatio(light.textCoral, light.surface);

        expect(ratioEmerald, greaterThanOrEqualTo(4.5), reason: 'textEmerald on light surface');
        expect(ratioCoral, greaterThanOrEqualTo(4.5), reason: 'textCoral on light surface');
      });

      test('Anchor Navy text on primary button / hero card meets WCAG AA (>= 4.5:1)', () {
        final ratioButton = contrastRatio(light.primaryButtonText, light.primaryButtonBg);
        final ratioNavy = contrastRatio(light.onNavy, light.navy);

        expect(ratioButton, greaterThanOrEqualTo(4.5), reason: 'button text on Navy');
        expect(ratioNavy, greaterThanOrEqualTo(4.5), reason: 'onNavy on Navy');
      });
    });

    group('Dark Theme Contrast', () {
      test('Primary text (ink) on surfaces meets WCAG AA (>= 4.5:1)', () {
        final ratioCanvas = contrastRatio(dark.ink, dark.canvas);
        final ratioSurface = contrastRatio(dark.ink, dark.surface);
        final ratioRaised = contrastRatio(dark.ink, dark.raised);

        expect(ratioCanvas, greaterThanOrEqualTo(4.5), reason: 'ink on dark canvas');
        expect(ratioSurface, greaterThanOrEqualTo(4.5), reason: 'ink on dark surface');
        expect(ratioRaised, greaterThanOrEqualTo(4.5), reason: 'ink on dark raised');
      });

      test('Muted text on surfaces meets WCAG AA body (>= 4.5:1)', () {
        final ratioCanvas = contrastRatio(dark.muted, dark.canvas);
        final ratioSurface = contrastRatio(dark.muted, dark.surface);

        expect(ratioCanvas, greaterThanOrEqualTo(4.5), reason: 'muted on dark canvas');
        expect(ratioSurface, greaterThanOrEqualTo(4.5), reason: 'muted on dark surface');
      });

      test('Semantic text colors (emerald & coral) on surface meet WCAG AA (>= 4.5:1)', () {
        final ratioEmerald = contrastRatio(dark.textEmerald, dark.surface);
        final ratioCoral = contrastRatio(dark.textCoral, dark.surface);

        expect(ratioEmerald, greaterThanOrEqualTo(4.5), reason: 'textEmerald on dark surface');
        expect(ratioCoral, greaterThanOrEqualTo(4.5), reason: 'textCoral on dark surface');
      });

      test('Primary button text in dark mode meets WCAG AA (>= 4.5:1)', () {
        final ratioButton = contrastRatio(dark.primaryButtonText, dark.primaryButtonBg);

        expect(ratioButton, greaterThanOrEqualTo(4.5), reason: 'button text in dark mode');
      });
    });
  });
}
