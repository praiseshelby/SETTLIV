import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/models/settlement.dart';
import 'package:settliv/features/home/domain/recent_activity_engine.dart';

void main() {
  group('RecentActivityEngine Pure Function Unit Tests (Max 3 items)', () {
    final baseNow = DateTime(2026, 11, 20, 15, 0);

    Expense makeExpense({
      required String id,
      required DateTime date,
      bool isDeleted = false,
    }) {
      return Expense(
        id: id,
        groupId: 'g1',
        description: 'Expense $id',
        category: ExpenseCategory.food,
        totalPaise: 10000,
        date: date,
        payers: const [PayerShare(personId: 'u1', paise: 10000)],
        splitMode: SplitMode.equal,
        computedShares: const {'u1': 5000, 'u2': 5000},
        createdAt: date,
        isDeleted: isDeleted,
      );
    }

    Settlement makeSettlement({
      required String id,
      required DateTime date,
    }) {
      return Settlement(
        id: id,
        groupId: 'g1',
        from: 'u2',
        to: 'u1',
        paise: 5000,
        date: date,
      );
    }

    test('Returns empty when no items exist', () {
      final res = RecentActivityEngine.computeRecentActivity(
        expenses: [],
        settlements: [],
        now: baseNow,
      );
      expect(res.items, isEmpty);
      expect(res.hasMoreToday, isFalse);
      expect(res.moreTodayCount, equals(0));
    });

    test('Excludes soft-deleted expenses', () {
      final active = makeExpense(id: 'e1', date: baseNow);
      final deleted = makeExpense(id: 'e2', date: baseNow, isDeleted: true);

      final res = RecentActivityEngine.computeRecentActivity(
        expenses: [active, deleted],
        settlements: [],
        now: baseNow,
      );
      expect(res.items.length, equals(1));
      expect(res.items.first.id, equals('e1'));
      expect(res.moreTodayCount, equals(0));
    });

    test('Today has > 3 items: shows 3 items only, moreTodayCount = count - 3', () {
      final todayItems = List.generate(
        6,
        (i) => makeExpense(id: 'e_$i', date: baseNow.subtract(Duration(minutes: i))),
      );
      final yesterdayItem = makeExpense(id: 'yesterday', date: baseNow.subtract(const Duration(days: 1)));

      final res = RecentActivityEngine.computeRecentActivity(
        expenses: [...todayItems, yesterdayItem],
        settlements: [],
        now: baseNow,
      );

      // Max 3 items shown
      expect(res.items.length, equals(3));
      expect(res.hasMoreToday, isTrue);
      expect(res.moreTodayCount, equals(3));
      expect(res.spansMultipleDays, isFalse);
      expect(res.items.any((item) => item.id == 'yesterday'), isFalse);
    });

    test('Today has exactly 3 items: shows all 3, moreTodayCount = 0', () {
      final todayItems = List.generate(
        3,
        (i) => makeExpense(id: 'e_$i', date: baseNow.subtract(Duration(minutes: i))),
      );

      final res = RecentActivityEngine.computeRecentActivity(
        expenses: todayItems,
        settlements: [],
        now: baseNow,
      );

      expect(res.items.length, equals(3));
      expect(res.hasMoreToday, isFalse);
      expect(res.moreTodayCount, equals(0));
    });

    test('Today has < 3 items: adds earlier days up to 7 back until 3 are shown', () {
      final today1 = makeExpense(id: 'today1', date: baseNow);
      final yest1 = makeExpense(id: 'yest1', date: baseNow.subtract(const Duration(days: 1)));
      final twoDaysAgo1 = makeExpense(id: 'twodays1', date: baseNow.subtract(const Duration(days: 2, hours: 1)));
      final twoDaysAgo2 = makeExpense(id: 'twodays2', date: baseNow.subtract(const Duration(days: 2, hours: 2)));

      final res = RecentActivityEngine.computeRecentActivity(
        expenses: [today1, yest1, twoDaysAgo1, twoDaysAgo2],
        settlements: [],
        now: baseNow,
      );

      // Takes max 3 items
      expect(res.items.length, equals(3));
      expect(res.spansMultipleDays, isTrue);
      expect(res.items.map((i) => i.id).toList(), equals(['today1', 'yest1', 'twodays1']));
    });

    test('Combines settlements and expenses chronologically', () {
      final exp = makeExpense(id: 'exp1', date: baseNow.subtract(const Duration(hours: 2)));
      final stl = makeSettlement(id: 'stl1', date: baseNow.subtract(const Duration(hours: 1)));

      final res = RecentActivityEngine.computeRecentActivity(
        expenses: [exp],
        settlements: [stl],
        now: baseNow,
      );

      expect(res.items.length, equals(2));
      expect(res.items.first.id, equals('stl1'));
      expect(res.items.last.id, equals('exp1'));
    });
  });
}
