import '../../../data/models/expense.dart';
import '../../../data/models/settlement.dart';

sealed class ActivityItem implements Comparable<ActivityItem> {
  final String id;
  final String groupId;
  final DateTime date;
  final DateTime createdAt;

  const ActivityItem({
    required this.id,
    required this.groupId,
    required this.date,
    required this.createdAt,
  });

  @override
  int compareTo(ActivityItem other) {
    // Newest first by date, then createdAt
    final dateComp = other.date.compareTo(date);
    if (dateComp != 0) return dateComp;
    return other.createdAt.compareTo(createdAt);
  }
}

class ExpenseActivityItem extends ActivityItem {
  final Expense expense;

  ExpenseActivityItem(this.expense)
      : super(
          id: expense.id,
          groupId: expense.groupId,
          date: expense.date,
          createdAt: expense.createdAt,
        );
}

class SettlementActivityItem extends ActivityItem {
  final Settlement settlement;

  SettlementActivityItem(this.settlement)
      : super(
          id: settlement.id,
          groupId: settlement.groupId,
          date: settlement.date,
          createdAt: settlement.date,
        );
}

class RecentActivityResult {
  final List<ActivityItem> items;
  final int moreTodayCount;
  final bool spansMultipleDays;

  const RecentActivityResult({
    required this.items,
    this.moreTodayCount = 0,
    this.spansMultipleDays = false,
  });

  bool get hasMoreToday => moreTodayCount > 0;
}

class RecentActivityEngine {
  const RecentActivityEngine();

  /// Pure function computing recent activity items according to the strict rule:
  /// - max 3 rows (newest first, expenses + settlements, soft-deleted excluded).
  /// - Rule: take today's items; if fewer than 3, add earlier days (up to 7 back) until 3 are shown.
  /// - If there are more items today than shown, show a small caption "N more today · See all" -> Records.
  static RecentActivityResult computeRecentActivity({
    required List<Expense> expenses,
    required List<Settlement> settlements,
    required DateTime now,
  }) {
    // 1. Filter active (non-soft-deleted) items
    final activeExpenses = expenses
        .where((e) => !e.isDeleted)
        .map((e) => ExpenseActivityItem(e));

    final activeSettlements = settlements.map((s) => SettlementActivityItem(s));

    // Combine and sort newest first
    final allItems = <ActivityItem>[...activeExpenses, ...activeSettlements]..sort();

    if (allItems.isEmpty) {
      return const RecentActivityResult(items: []);
    }

    // Group items by calendar day: yyyy-MM-dd
    final Map<String, List<ActivityItem>> dayBuckets = {};
    for (final item in allItems) {
      final key = '${item.date.year.toString().padLeft(4, '0')}-'
          '${item.date.month.toString().padLeft(2, '0')}-'
          '${item.date.day.toString().padLeft(2, '0')}';
      dayBuckets.putIfAbsent(key, () => []).add(item);
    }

    final todayKey = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';

    final todayItems = dayBuckets[todayKey] ?? [];

    if (todayItems.length >= 3) {
      final moreCount = todayItems.length - 3;
      final taken = todayItems.take(3).toList();
      return RecentActivityResult(
        items: taken,
        moreTodayCount: moreCount,
        spansMultipleDays: false,
      );
    }

    // Today has < 3 items. Take today's items, then add earlier days (up to 7 back) until 3 are shown.
    final candidateItems = <ActivityItem>[...todayItems];

    for (int dayOffset = 1; dayOffset <= 7; dayOffset++) {
      if (candidateItems.length >= 3) break;

      final checkDate = now.subtract(Duration(days: dayOffset));
      final checkKey = '${checkDate.year.toString().padLeft(4, '0')}-'
          '${checkDate.month.toString().padLeft(2, '0')}-'
          '${checkDate.day.toString().padLeft(2, '0')}';

      final dayItems = dayBuckets[checkKey];
      if (dayItems != null && dayItems.isNotEmpty) {
        candidateItems.addAll(dayItems);
      }
    }

    // Keep up to 3 newest
    candidateItems.sort();
    final resultItems = candidateItems.take(3).toList();

    // Check if result spans multiple calendar days
    final distinctDays = resultItems.map((item) =>
      '${item.date.year}-${item.date.month}-${item.date.day}'
    ).toSet();

    return RecentActivityResult(
      items: resultItems,
      moreTodayCount: 0,
      spansMultipleDays: distinctDays.length > 1,
    );
  }
}
