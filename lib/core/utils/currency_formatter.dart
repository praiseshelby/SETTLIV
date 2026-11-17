class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats an integer amount in paise into Indian Rupee format, e.g. "₹1,240" or "₹1,00,000".
  /// If [includeDecimals] is false and paise has no decimal fraction, decimals are omitted.
  static String formatPaise(
    int paise, {
    bool showSign = false,
    bool absolute = false,
    bool includeDecimalsIfPresent = true,
  }) {
    final int valueToFormat = absolute ? paise.abs() : paise;
    final bool isNegative = valueToFormat < 0;
    final int absPaise = valueToFormat.abs();
    final int rupees = absPaise ~/ 100;
    final int fraction = absPaise % 100;

    final String groupedRupees = _formatIndianGrouping(rupees);
    final String decimalPart = (includeDecimalsIfPresent && fraction > 0)
        ? '.${fraction.toString().padLeft(2, '0')}'
        : '';

    final String sign;
    if (showSign) {
      if (paise > 0) {
        sign = '+';
      } else if (paise < 0) {
        sign = '-';
      } else {
        sign = '';
      }
    } else {
      sign = isNegative ? '-' : '';
    }

    return '$sign₹$groupedRupees$decimalPart';
  }

  /// Formats pure integer rupees into Indian grouping, e.g. 100000 -> "1,00,000"
  static String _formatIndianGrouping(int number) {
    final String s = number.toString();
    if (s.length <= 3) return s;

    final String lastThree = s.substring(s.length - 3);
    String remaining = s.substring(0, s.length - 3);
    final List<String> chunks = [];

    while (remaining.length > 2) {
      chunks.add(remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      chunks.add(remaining);
    }

    return '${chunks.reversed.join(',')},$lastThree';
  }

  /// Converts a user input text string (like "1200", "1.2k", "1500.50") into paise.
  static int? parseToPaise(String input) {
    String clean = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (clean.isEmpty) return null;

    final lower = clean.toLowerCase();
    double multiplier = 1.0;
    if (lower.endsWith('k')) {
      multiplier = 1000.0;
      clean = clean.substring(0, clean.length - 1).trim();
    } else if (lower.endsWith('l') || lower.endsWith('lac') || lower.endsWith('lakh')) {
      multiplier = 100000.0;
      clean = clean.replaceAll(RegExp(r'(lakh|lac|l)$'), '').trim();
    }

    final double? parsedVal = double.tryParse(clean);
    if (parsedVal == null || parsedVal.isNaN || parsedVal.isInfinite) {
      return null;
    }

    return (parsedVal * multiplier * 100).round();
  }
}
