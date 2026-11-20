/// Utility for Indian currency formatting, parsing, and number-to-words.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Hard cap: ₹10,00,00,000 (10 crore) = 1,000,000,000 paise
  static const int maxAmountPaise = 10000000000;

  /// Large amount threshold: ₹1,00,000 (1 lakh) = 10,000,000 paise
  static const int largeAmountThresholdPaise = 10000000;

  /// Formats an integer amount in paise into Indian Rupee format.
  /// Examples:
  ///   - 124000 -> "₹1,240"
  ///   - 10000000 -> "₹1,00,000"
  ///   - 123456750 -> "₹12,34,567.50"
  ///   - 0 -> "₹0"
  ///   - -50000 -> "-₹500"
  ///
  /// Trailing ".00" is always hidden.
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

    final String groupedRupees = formatIndianGrouping(rupees);
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
  static String formatIndianGrouping(int number) {
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

  /// Converts a user input text string (like "1200", "1.2k", "1500.50", "1.5L", "2cr") into paise.
  /// Returns null if invalid, negative, or not parseable.
  static int? parseToPaise(String input) {
    String clean = input.replaceAll('₹', '').replaceAll(',', '').trim();
    if (clean.isEmpty) return null;

    final lower = clean.toLowerCase();
    double multiplier = 1.0;
    if (lower.endsWith('k')) {
      multiplier = 1000.0;
      clean = clean.substring(0, clean.length - 1).trim();
    } else if (lower.endsWith('cr') || lower.endsWith('crore')) {
      multiplier = 10000000.0;
      clean = clean.replaceAll(RegExp(r'(crore|cr)$', caseSensitive: false), '').trim();
    } else if (lower.endsWith('l') || lower.endsWith('lac') || lower.endsWith('lakh')) {
      multiplier = 100000.0;
      clean = clean.replaceAll(RegExp(r'(lakh|lac|l)$', caseSensitive: false), '').trim();
    }

    final double? parsedVal = double.tryParse(clean);
    if (parsedVal == null || parsedVal.isNaN || parsedVal.isInfinite) {
      return null;
    }

    if (parsedVal < 0) return null;

    final result = (parsedVal * multiplier * 100).round();
    return result;
  }

  /// Converts an amount in paise to Indian words (e.g. 10000000 -> "One lakh").
  static String formatPaiseInWords(int paise) {
    final int rupees = paise ~/ 100;
    if (rupees == 0) return 'Zero';

    if (rupees >= 10000000) {
      final double crores = rupees / 10000000.0;
      if (crores == crores.roundToDouble()) {
        return '${_smallNumberToWords(crores.toInt())} crore';
      }
      return '${crores.toStringAsFixed(1).replaceAll('.0', '')} crore';
    } else if (rupees >= 100000) {
      final double lakhs = rupees / 100000.0;
      if (lakhs == lakhs.roundToDouble()) {
        return '${_smallNumberToWords(lakhs.toInt())} lakh';
      }
      return '${lakhs.toStringAsFixed(1).replaceAll('.0', '')} lakh';
    } else if (rupees >= 1000) {
      final double thousands = rupees / 1000.0;
      if (thousands == thousands.roundToDouble()) {
        return '${_smallNumberToWords(thousands.toInt())} thousand';
      }
      return '${thousands.toStringAsFixed(1).replaceAll('.0', '')} thousand';
    }
    return _smallNumberToWords(rupees);
  }

  static String _smallNumberToWords(int n) {
    const units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    if (n < 20) return units[n];
    if (n < 100) {
      final t = tens[n ~/ 10];
      final u = units[n % 10];
      return u.isEmpty ? t : '$t $u';
    }
    return n.toString();
  }
}
