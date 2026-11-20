/// Pure deterministic split calculator for Settliv.
///
/// Guarantees that shares sum EXACTLY to total amount in integer paise.
/// Leftover paise are distributed deterministically: to the payer first
/// (if participating in the split), then in member order.
class SplitCalculator {
  const SplitCalculator._();

  /// Calculates equal split among [memberIds].
  ///
  /// Leftover paise are distributed deterministically: to [paidBy] first
  /// (if in [memberIds]), then in order of [memberIds].
  ///
  /// The returned map sums EXACTLY to [totalPaise].
  static Map<String, int> splitEqual({
    required int totalPaise,
    required List<String> memberIds,
    required String paidBy,
  }) {
    if (memberIds.isEmpty || totalPaise <= 0) return {};

    final count = memberIds.length;
    final base = totalPaise ~/ count;
    int remainder = totalPaise % count;

    final Map<String, int> result = {for (final id in memberIds) id: base};

    if (remainder > 0) {
      // Payer gets first remainder if among participants
      if (result.containsKey(paidBy)) {
        result[paidBy] = result[paidBy]! + 1;
        remainder--;
      }

      // Distribute any remaining leftover paise in member order
      for (final id in memberIds) {
        if (remainder <= 0) break;
        if (id == paidBy) continue; // Already gave 1 to payer
        result[id] = result[id]! + 1;
        remainder--;
      }
    }

    return result;
  }

  /// Calculates percent split among [memberIds] given percentages in [percentages] (e.g. 33.33).
  ///
  /// Leftover paise (from integer division) are distributed to [paidBy] first,
  /// then in member order, guaranteeing the shares sum EXACTLY to [totalPaise].
  static Map<String, int> splitPercent({
    required int totalPaise,
    required List<String> memberIds,
    required Map<String, double> percentages,
    required String paidBy,
  }) {
    if (memberIds.isEmpty || totalPaise <= 0) return {};

    final Map<String, int> result = {};
    int allocated = 0;

    for (final id in memberIds) {
      final pct = percentages[id] ?? 0.0;
      final share = (totalPaise * pct / 100.0).floor();
      result[id] = share;
      allocated += share;
    }

    int remainder = totalPaise - allocated;
    if (remainder > 0) {
      if (result.containsKey(paidBy)) {
        result[paidBy] = result[paidBy]! + 1;
        remainder--;
      }
      for (final id in memberIds) {
        if (remainder <= 0) break;
        if (id == paidBy) continue;
        result[id] = result[id]! + 1;
        remainder--;
      }
    }

    return result;
  }

  /// Validates and normalizes exact shares, ensuring they sum to [totalPaise].
  static ({bool isValid, int differencePaise, Map<String, int> shares}) validateExact({
    required int totalPaise,
    required List<String> memberIds,
    required Map<String, int> exactShares,
  }) {
    int totalAssigned = 0;
    final Map<String, int> result = {};

    for (final id in memberIds) {
      final share = exactShares[id] ?? 0;
      result[id] = share;
      totalAssigned += share;
    }

    final diff = totalPaise - totalAssigned;
    return (
      isValid: diff == 0,
      differencePaise: diff,
      shares: result,
    );
  }
}
