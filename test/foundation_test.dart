import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/utils/currency_formatter.dart';
import 'package:settliv/data/engine/balance_engine.dart';
import 'package:settliv/data/engine/split_calculator.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/models/settlement.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/seed/seed_data.dart';

void main() {
  group('Part 1(f): Money Formatting & Parsing', () {
    test('formatPaise formats with Indian grouping and hides .00', () {
      expect(CurrencyFormatter.formatPaise(10000000), equals('₹1,00,000'));
      expect(CurrencyFormatter.formatPaise(123456750), equals('₹12,34,567.50'));
      expect(CurrencyFormatter.formatPaise(124000), equals('₹1,240'));
      expect(CurrencyFormatter.formatPaise(0), equals('₹0'));
      expect(CurrencyFormatter.formatPaise(100), equals('₹1'));
      expect(CurrencyFormatter.formatPaise(50), equals('₹0.50'));
      expect(CurrencyFormatter.formatPaise(1000000000), equals('₹1,00,00,000'));
      expect(CurrencyFormatter.formatPaise(10000000000), equals('₹10,00,00,000'));
    });

    test('formatPaise handles signs and negative amounts', () {
      expect(CurrencyFormatter.formatPaise(-50000), equals('-₹500'));
      expect(CurrencyFormatter.formatPaise(124000, showSign: true), equals('+₹1,240'));
      expect(CurrencyFormatter.formatPaise(-38000, showSign: true), equals('-₹380'));
      expect(CurrencyFormatter.formatPaise(-38000, absolute: true), equals('₹380'));
    });

    test('parseToPaise handles plain numbers, commas, k, lakh, and cr', () {
      expect(CurrencyFormatter.parseToPaise('1200'), equals(120000));
      expect(CurrencyFormatter.parseToPaise('₹1,240'), equals(124000));
      expect(CurrencyFormatter.parseToPaise('1.2k'), equals(120000));
      expect(CurrencyFormatter.parseToPaise('2.5K'), equals(250000));
      expect(CurrencyFormatter.parseToPaise('1.5L'), equals(15000000));
      expect(CurrencyFormatter.parseToPaise('2 lakh'), equals(20000000));
      expect(CurrencyFormatter.parseToPaise('1cr'), equals(1000000000));
      expect(CurrencyFormatter.parseToPaise('1.5 crore'), equals(1500000000));
      expect(CurrencyFormatter.parseToPaise('10,00,000'), equals(100000000));
      expect(CurrencyFormatter.parseToPaise(''), isNull);
      expect(CurrencyFormatter.parseToPaise('abc'), isNull);
      expect(CurrencyFormatter.parseToPaise('-500'), isNull);
    });

    test('formatPaiseInWords converts large amounts to Indian words', () {
      expect(CurrencyFormatter.formatPaiseInWords(10000000), equals('One lakh'));
      expect(CurrencyFormatter.formatPaiseInWords(100000000), equals('Ten lakh'));
      expect(CurrencyFormatter.formatPaiseInWords(1000000000), equals('One crore'));
      expect(CurrencyFormatter.formatPaiseInWords(10000000000), equals('Ten crore'));
    });
  });

  group('Part 1(f): Split Distribution & Leftover Paise', () {
    test('3-way split of ₹100 distributes 1 leftover paise to payer first', () {
      final shares = SplitCalculator.splitEqual(
        totalPaise: 10000, // ₹100
        memberIds: ['m1', 'm2', 'm3'],
        paidBy: 'm1',
      );

      expect(shares['m1'], equals(3334)); // Payer gets leftover paise
      expect(shares['m2'], equals(3333));
      expect(shares['m3'], equals(3333));
      expect(shares.values.fold<int>(0, (a, b) => a + b), equals(10000));
    });

    test('3-way split of ₹100 when payer is second member', () {
      final shares = SplitCalculator.splitEqual(
        totalPaise: 10000,
        memberIds: ['m1', 'm2', 'm3'],
        paidBy: 'm2',
      );

      expect(shares['m1'], equals(3333));
      expect(shares['m2'], equals(3334)); // Payer gets leftover paise
      expect(shares['m3'], equals(3333));
      expect(shares.values.fold<int>(0, (a, b) => a + b), equals(10000));
    });

    test('3-way split of ₹100 when payer is not in members list', () {
      final shares = SplitCalculator.splitEqual(
        totalPaise: 10000,
        memberIds: ['m1', 'm2', 'm3'],
        paidBy: 'external_payer',
      );

      expect(shares['m1'], equals(3334)); // First in member order gets remainder
      expect(shares['m2'], equals(3333));
      expect(shares['m3'], equals(3333));
      expect(shares.values.fold<int>(0, (a, b) => a + b), equals(10000));
    });

    test('4-way equal split of ₹4,000 (Mopa airport cab)', () {
      final shares = SplitCalculator.splitEqual(
        totalPaise: 400000,
        memberIds: ['person_arjun', 'person_nisha', 'person_rohan', 'person_tara'],
        paidBy: 'person_arjun',
      );

      expect(shares['person_arjun'], equals(100000));
      expect(shares['person_nisha'], equals(100000));
      expect(shares['person_rohan'], equals(100000));
      expect(shares['person_tara'], equals(100000));
      expect(shares.values.fold<int>(0, (a, b) => a + b), equals(400000));
    });

    test('Percent split sums EXACTLY to total amount with paise remainders', () {
      final shares = SplitCalculator.splitPercent(
        totalPaise: 10000, // ₹100
        memberIds: ['m1', 'm2', 'm3'],
        percentages: {'m1': 33.33, 'm2': 33.33, 'm3': 33.34},
        paidBy: 'm1',
      );

      expect(shares.values.fold<int>(0, (a, b) => a + b), equals(10000));
    });

    test('Exact split validation verifies exact sum', () {
      final valid = SplitCalculator.validateExact(
        totalPaise: 10000,
        memberIds: ['m1', 'm2'],
        exactShares: {'m1': 6000, 'm2': 4000},
      );
      expect(valid.isValid, isTrue);
      expect(valid.differencePaise, equals(0));

      final invalid = SplitCalculator.validateExact(
        totalPaise: 10000,
        memberIds: ['m1', 'm2'],
        exactShares: {'m1': 6000, 'm2': 3000},
      );
      expect(invalid.isValid, isFalse);
      expect(invalid.differencePaise, equals(1000));
    });
  });

  group('Part 1(f): Ledger, Balances & Seed Audit', () {
    const engine = BalanceEngine();

    test('All seed expenses shares sum exactly to total amount', () {
      for (final exp in SeedData.expenses) {
        final sharesSum = exp.shares.values.fold<int>(0, (sum, val) => sum + val);
        expect(
          sharesSum,
          equals(exp.amount),
          reason: 'Expense "${exp.title}" shares must sum to ${exp.amount}',
        );
      }
    });

    test('Mopa airport cab is equal 4-way split yielding Arjun lent ₹3,000', () {
      final cab = SeedData.expenses.firstWhere((e) => e.id == 'exp_goa_11');
      expect(cab.splitMode, equals(SplitMode.equal));
      expect(cab.amount, equals(400000)); // ₹4,000
      expect(cab.shares['person_arjun'], equals(100000)); // ₹1,000 share
      final lent = cab.amount - cab.shares['person_arjun']!;
      expect(lent, equals(300000)); // Exactly ₹3,000 lent!
    });

    test('Flatmates yields Arjun net balance of EXACTLY +₹1,240 (124000 paise)', () {
      final summary = engine.computeGroupSummary(
        groupId: SeedData.flatmates.id,
        memberIds: SeedData.flatmates.memberIds,
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      final arjunNet = summary.netBalances[SeedData.currentUserId];
      expect(arjunNet, equals(124000));
    });

    test('Goa Trip yields Arjun net balance of EXACTLY -₹380 (-38000 paise)', () {
      final summary = engine.computeGroupSummary(
        groupId: SeedData.goaTrip.id,
        memberIds: SeedData.goaTrip.memberIds,
        expenses: SeedData.expenses,
        settlements: SeedData.settlements,
      );

      final arjunNet = summary.netBalances[SeedData.currentUserId];
      expect(arjunNet, equals(-38000));
    });

    test('Group net balances sum to EXACTLY ZERO for both groups', () {
      for (final group in [SeedData.flatmates, SeedData.goaTrip]) {
        final summary = engine.computeGroupSummary(
          groupId: group.id,
          memberIds: group.memberIds,
          expenses: SeedData.expenses,
          settlements: SeedData.settlements,
        );
        final sum = summary.netBalances.values.fold<int>(0, (a, b) => a + b);
        expect(sum, equals(0), reason: '${group.name} net balances must sum to 0');
      }
    });

    test('Home totals invariant: netBalance == totalOwedToUser - totalUserOwes', () {
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
      expect(overall.netBalance, equals(overall.totalOwedToUser - overall.totalUserOwes));
    });
  });

  group('Part 1(f): Settlements & Undo in Ledger', () {
    test('Settlement record reduces what debtor owes and creditor is owed', () {
      final repo = InMemoryAppRepository();
      final initialOverall = repo.getUserOverallBalance();
      expect(initialOverall.netBalance, equals(86000)); // +₹860
      expect(initialOverall.totalUserOwes, equals(38000)); // ₹380

      // Arjun settles ₹380 for Goa Trip with Rohan
      final settlement = Settlement(
        id: 'settle_test_1',
        groupId: 'group_goa',
        payerId: SeedData.currentUserId,
        payeeId: 'person_rohan',
        amount: 38000,
        date: DateTime(2026, 11, 20),
      );

      repo.addSettlement(settlement);

      final goaSummaryAfter = repo.getGroupSummary('group_goa');
      expect(goaSummaryAfter.netBalances[SeedData.currentUserId], equals(0)); // All settled!

      final overallAfter = repo.getUserOverallBalance();
      expect(overallAfter.totalUserOwes, equals(0));
      expect(overallAfter.netBalance, equals(124000)); // Now just owed 1240

      // Delete settlement
      repo.deleteSettlement('settle_test_1');
      final overallRestored = repo.getUserOverallBalance();
      expect(overallRestored.netBalance, equals(86000));
      expect(overallRestored.totalUserOwes, equals(38000));
    });

    test('Deleting an expense removes it from balance, and undo restores it exactly', () {
      final repo = InMemoryAppRepository();
      final initialOverall = repo.getUserOverallBalance();
      final exp = repo.getExpense('exp_fm_14')!; // Kitchen essentials ₹1,740 (Arjun owes 1160)

      // Soft delete expense
      repo.deleteExpense(exp.id);
      final afterDeleteOverall = repo.getUserOverallBalance();
      // Arjun's share of exp_fm_14 was 116000 owed to Meera.
      // Deleting it means Arjun owes 116000 less -> net balance increases by 116000!
      expect(afterDeleteOverall.netBalance, equals(initialOverall.netBalance + 116000));

      // Restore expense (undo)
      repo.restoreExpense(exp.id);
      final afterUndoOverall = repo.getUserOverallBalance();
      expect(afterUndoOverall.netBalance, equals(initialOverall.netBalance));
    });
  });
}
