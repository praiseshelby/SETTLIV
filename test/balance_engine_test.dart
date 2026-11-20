import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/data/engine/balance_engine.dart';
import 'package:settliv/data/seed/seed_data.dart';

void main() {
  group('BalanceEngine & Seed Data Verification', () {
    const engine = BalanceEngine();

    test('Total seed expenses count is >= 20', () {
      expect(SeedData.expenses.length, greaterThanOrEqualTo(20));
      expect(SeedData.expenses.length, equals(30));
    });

    test('All expenses have shares that sum exactly to total amount', () {
      for (final exp in SeedData.expenses) {
        final sharesSum = exp.shares.values.fold<int>(0, (sum, val) => sum + val);
        expect(
          sharesSum,
          equals(exp.amount),
          reason: 'Expense "${exp.title}" shares must sum to ${exp.amount}',
        );
      }
    });

    test('Flatmates yields Arjun net balance of EXACTLY +₹1,240 (124000 paise)', () {
      final summary = engine.computeGroupSummary(
        groupId: SeedData.flatmates.id,
        memberIds: SeedData.flatmates.memberIds,
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      final arjunNet = summary.netBalances[SeedData.currentUserId];
      expect(arjunNet, equals(124000)); // +₹1,240.00
    });

    test('Flatmates net balances sum to EXACTLY ZERO', () {
      final summary = engine.computeGroupSummary(
        groupId: SeedData.flatmates.id,
        memberIds: SeedData.flatmates.memberIds,
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      final totalGroupBalance =
          summary.netBalances.values.fold<int>(0, (sum, val) => sum + val);
      expect(totalGroupBalance, equals(0));
    });

    test('Goa Trip yields Arjun net balance of EXACTLY -₹380 (-38000 paise)', () {
      final summary = engine.computeGroupSummary(
        groupId: SeedData.goaTrip.id,
        memberIds: SeedData.goaTrip.memberIds,
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      final arjunNet = summary.netBalances[SeedData.currentUserId];
      expect(arjunNet, equals(-38000)); // -₹380.00
    });

    test('Goa Trip net balances sum to EXACTLY ZERO', () {
      final summary = engine.computeGroupSummary(
        groupId: SeedData.goaTrip.id,
        memberIds: SeedData.goaTrip.memberIds,
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      final totalGroupBalance =
          summary.netBalances.values.fold<int>(0, (sum, val) => sum + val);
      expect(totalGroupBalance, equals(0));
    });

    test('Arjun overall balance computes correctly across all groups', () {
      final overall = engine.computeUserOverallBalance(
        currentUserId: SeedData.currentUserId,
        groupIds: [SeedData.flatmates.id, SeedData.goaTrip.id],
        groupMembersMap: {
          SeedData.flatmates.id: SeedData.flatmates.memberIds,
          SeedData.goaTrip.id: SeedData.goaTrip.memberIds,
        },
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      expect(overall.totalOwedToUser, equals(124000)); // ₹1,240
      expect(overall.totalUserOwes, equals(38000)); // ₹380
      expect(overall.netBalance, equals(86000)); // +₹860
    });
  });
}
