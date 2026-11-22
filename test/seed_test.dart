import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/data/engine/balance_engine.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/seed/seed_data.dart';

void main() {
  group('Part 1 Seed Data Validation', () {
    const engine = BalanceEngine();

    test('Seed history spans approximately 6 months', () {
      final dates = SeedData.expenses.map((e) => e.date).toList()..sort();
      final earliest = dates.first;
      final latest = dates.last;
      final differenceInDays = latest.difference(earliest).inDays;
      expect(differenceInDays, greaterThanOrEqualTo(140)); // ~5-6 months
    });

    test('Headline balances match exact target numbers (+₹1,240, -₹380, net +₹860)', () {
      final flatmatesSummary = engine.computeGroupSummary(
        groupId: SeedData.flatmates.id,
        memberIds: SeedData.flatmates.memberIds,
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      final goaSummary = engine.computeGroupSummary(
        groupId: SeedData.goaTrip.id,
        memberIds: SeedData.goaTrip.memberIds,
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      final arjunFlatmates = flatmatesSummary.netBalances[SeedData.currentUserId] ?? 0;
      final arjunGoa = goaSummary.netBalances[SeedData.currentUserId] ?? 0;
      final netTotal = arjunFlatmates + arjunGoa;

      expect(arjunFlatmates, equals(124000), reason: 'Flatmates must be +₹1,240 (124000 paise)');
      expect(arjunGoa, equals(-38000), reason: 'Goa Trip must be -₹380 (-38000 paise)');
      expect(netTotal, equals(86000), reason: 'Net balance must be +₹860 (86000 paise)');
    });

    test('All group internal balances sum to zero', () {
      for (final group in [SeedData.flatmates, SeedData.goaTrip]) {
        final summary = engine.computeGroupSummary(
          groupId: group.id,
          memberIds: group.memberIds,
          expenses: SeedData.expenses,
          settlements: SeedData.settlements,
        );
        final sum = summary.netBalances.values.fold<int>(0, (a, b) => a + b);
        expect(sum, equals(0), reason: 'Group ${group.name} net balances must sum to 0');
      }
    });

    test('Personal space is excluded from shared balances', () {
      final personalGroup = SeedData.personal;
      expect(personalGroup.isPersonal, isTrue);

      final overall = engine.computeUserOverallBalance(
        currentUserId: SeedData.currentUserId,
        groupIds: SeedData.groups.map((g) => g.id).toList(),
        groupMembersMap: {for (final g in SeedData.groups) g.id: g.memberIds},
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      // Overall net must match shared groups net (+86000 paise)
      expect(overall.netBalance, equals(86000));
    });

    test('Invariants: all expenses have payers and shares summing to total paise, and valid group members', () {
      final groupMap = {for (final g in SeedData.groups) g.id: g};

      for (final exp in SeedData.expenses) {
        final group = groupMap[exp.groupId];
        expect(group, isNotNull, reason: 'Expense ${exp.title} has invalid group ${exp.groupId}');

        // Every payer must be a group member
        for (final p in exp.payers) {
          expect(group!.memberIds.contains(p.personId), isTrue,
              reason: 'Payer ${p.personId} in ${exp.title} must be a member of ${group.name}');
        }

        // Every share participant must be a group member
        for (final participantId in exp.computedShares.keys) {
          expect(group!.memberIds.contains(participantId), isTrue,
              reason: 'Participant $participantId in ${exp.title} must be a member of ${group.name}');
        }

        final payersSum = exp.payers.fold<int>(0, (sum, p) => sum + p.paise);
        expect(payersSum, equals(exp.amount), reason: 'Expense ${exp.title} payers must sum to amount');

        final sharesSum = exp.computedShares.values.fold<int>(0, (sum, s) => sum + s);
        expect(sharesSum, equals(exp.amount), reason: 'Expense ${exp.title} shares must sum to amount');

        // Audit displayed lent/owe amounts match the split
        for (final payer in exp.payers) {
          final share = exp.computedShares[payer.personId] ?? 0;
          final lent = payer.paise - share;
          if (lent >= 0) {
            expect(lent, equals(payer.paise - share));
          }
        }
      }
    });

    test('House party brew ₹2,820 split audit (Bug 3)', () {
      final houseParty = SeedData.expenses.firstWhere((e) => e.title == 'House party brew');
      expect(houseParty.totalPaise, equals(282000));
      expect(houseParty.splitMode, equals(SplitMode.equal));
      // Flatmates has 3 members: arjun, meera, kabir
      expect(houseParty.computedShares['person_arjun'], equals(94000)); // Arjun share
      expect(houseParty.computedShares['person_meera'], equals(94000)); // Meera share
      expect(houseParty.computedShares['person_kabir'], equals(94000)); // Kabir share
      // Arjun paid total ₹2,820, so he lent 282,000 - 94,000 = 188,000 (₹1,880)
      final arjunLent = houseParty.totalPaise - (houseParty.computedShares['person_arjun'] ?? 0);
      expect(arjunLent, equals(188000), reason: 'Arjun must have lent ₹1,880, not ₹2,256');
    });
  });
}
