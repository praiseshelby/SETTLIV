import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Theme Token Scan: ZERO raw Color(0x...) or Colors.* outside lib/core/theme/', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final colorLiteralRegex = RegExp(r'Color\(0x[0-9a-fA-F]+\)');
    final colorsClassRegex = RegExp(r'\bColors\.[a-zA-Z]+');

    final violations = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final normalizedPath = entity.path.replaceAll('\\', '/');

        // Banned outside lib/core/theme/
        if (normalizedPath.contains('lib/core/theme/')) {
          continue;
        }

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];

          // Ignore comments or test annotations
          final trimmed = line.trim();
          if (trimmed.startsWith('//') || trimmed.startsWith('/*')) {
            continue;
          }

          if (colorLiteralRegex.hasMatch(line)) {
            violations.add('$normalizedPath:${i + 1} uses raw Color(0x...): $trimmed');
          }
          if (colorsClassRegex.hasMatch(line)) {
            violations.add('$normalizedPath:${i + 1} uses Colors.*: $trimmed');
          }
        }
      }
    }

    if (violations.isNotEmpty) {
      fail(
        'Found ${violations.length} raw color violations outside lib/core/theme/:\n'
        '${violations.join('\n')}\n\n'
        'All colors must come from context.settliv / SettlivThemeExtension.',
      );
    }
    expect(violations, isEmpty);
  });
}
