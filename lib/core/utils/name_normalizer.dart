class NameNormalizer {
  const NameNormalizer._();

  /// Normalises a person or member name:
  /// 1. Trims leading and trailing whitespace
  /// 2. Collapses internal multiple spaces to a single space
  /// 3. Capitalises words (Title Case) if the user typed all-lowercase
  static String normalize(String name) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return trimmed;

    return trimmed.split(' ').map((word) {
      if (word.isEmpty) return '';
      // Capitalise first letter
      return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
    }).join(' ');
  }

  /// Formats a payer name relative to current user.
  /// If the payer is current user, returns "Paid by you" (or "you" if raw word requested).
  /// Otherwise returns "Paid by <Name>".
  static String formatPayer({
    String? payerId,
    String? currentUserId,
    String? fallbackName,
    bool? isPayer,
    String? payerName,
    bool prefixPaidBy = true,
  }) {
    final bool me = isPayer == true ||
        (payerId != null && currentUserId != null && payerId == currentUserId);
    if (me) {
      return prefixPaidBy ? 'Paid by you' : 'you';
    }
    final name = normalize(payerName ?? fallbackName ?? 'Someone');
    return prefixPaidBy ? 'Paid by $name' : name;
  }
}
