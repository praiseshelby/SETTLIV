import '../models/expense.dart';

class RepeatSuggestion {
  final String displayTitle;
  final String normalizedTitle;
  final int latestAmountPaise;
  final String groupId;
  final ExpenseCategory category;
  final int count;
  final DateTime lastUsedAt;

  const RepeatSuggestion({
    required this.displayTitle,
    required this.normalizedTitle,
    required this.latestAmountPaise,
    required this.groupId,
    required this.category,
    required this.count,
    required this.lastUsedAt,
  });

  // Alias for compatibility
  String get title => displayTitle;
  int get amountPaise => latestAmountPaise;
}

class RepeatSuggestionEngine {
  RepeatSuggestionEngine._();

  /// Normalizes description for comparison: trim, lower-case, collapse multiple spaces
  static String normalizeTitle(String title) {
    return title.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Finds repeated expenses that have been logged 3+ times in the specified group.
  /// Only considers active (non-deleted) expenses.
  /// Threshold logic (Part 2b):
  /// - ONLY descriptions logged 3+ times (normalized description, same group).
  /// - Seed data must not trigger it.
  static List<RepeatSuggestion> getRepeatSuggestions({
    required List<Expense> expenses,
    String? currentUserId,
    String? groupId,
    int threshold = 3,
  }) {
    final filtered = expenses.where((e) {
      if (e.isDeleted) return false;
      if (groupId != null && e.groupId != groupId) return false;
      if (currentUserId != null && e.paidBy != currentUserId) return false;
      return true;
    }).toList();

    // Group expenses by (groupId, normalizedTitle) so descriptions are counted per group
    final Map<String, List<Expense>> grouped = {};
    for (final exp in filtered) {
      final norm = normalizeTitle(exp.title);
      if (norm.isEmpty) continue;
      final key = '${exp.groupId}::$norm';
      grouped.putIfAbsent(key, () => []).add(exp);
    }

    final List<RepeatSuggestion> results = [];

    for (final entry in grouped.entries) {
      final items = entry.value;
      if (items.length >= threshold) {
        // Sort to get the most recent one
        items.sort((a, b) => b.date.compareTo(a.date));
        final latest = items.first;

        results.add(
          RepeatSuggestion(
            displayTitle: latest.title.trim(),
            normalizedTitle: normalizeTitle(latest.title),
            latestAmountPaise: latest.amount,
            groupId: latest.groupId,
            category: latest.category,
            count: items.length,
            lastUsedAt: latest.date,
          ),
        );
      }
    }

    // Sort suggestions by lastUsedAt descending
    results.sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt));
    return results;
  }
}
