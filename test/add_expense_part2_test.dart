import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/data/engine/repeat_suggestion_engine.dart';
import 'package:settliv/data/engine/split_calculator.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/features/add_expense/logic/quick_expense_parser.dart';

void main() {
  final parser = QuickExpenseParser(
    availablePeople: SeedData.people,
    availableGroups: SeedData.groups,
    currentUser: SeedData.arjun,
  );

  group('Part 2: Parser Edge Cases', () {
    test('Handles "k" and "K" suffix', () {
      final res = parser.parse('lunch 1.5k with Meera');
      expect(res.amountPaise, equals(150000));
      expect(res.isValid, isTrue);
    });

    test('Handles "lakh" and "L" suffix', () {
      final resL = parser.parse('rent 1.5L with Kabir');
      expect(resL.amountPaise, equals(15000000));
      expect(resL.isValid, isTrue);

      final resLakh = parser.parse('deposit 2 lakh');
      expect(resLakh.amountPaise, equals(20000000));
      expect(resLakh.isValid, isTrue);
    });

    test('Handles "cr" and "crore" suffix', () {
      final resCr = parser.parse('land 1.2cr');
      expect(resCr.amountPaise, equals(1200000000));
      expect(resCr.isValid, isTrue);
    });

    test('Handles Indian commas in amounts', () {
      final res = parser.parse('jewellery 1,25,000');
      expect(res.amountPaise, equals(12500000));
      expect(res.isValid, isTrue);
    });

    test('Handles decimals accurately', () {
      final res = parser.parse('coffee 150.50 with Meera');
      expect(res.amountPaise, equals(15050));
      expect(res.isValid, isTrue);
    });

    test('Identifies ambiguous amounts (multiple distinct amounts)', () {
      final res = parser.parse('dinner 500 800 with Meera');
      expect(res.isAmbiguousAmount, isTrue);
      expect(res.isValid, isFalse);
    });

    test('Identifies missing amount', () {
      final res = parser.parse('drinks with Kabir');
      expect(res.amountPaise, isNull);
      expect(res.isValid, isFalse);
      expect(res.hint, equals('Add an amount to continue'));
    });

    test('Identifies unknown people mentioned after with/and', () {
      final res = parser.parse('dinner 500 with John');
      expect(res.unknownPeople, contains('John'));
      expect(res.amountPaise, equals(50000));
    });

    test('Hard blocks amounts above 10 crore cap', () {
      final res = parser.parse('megamansion 15cr');
      expect(res.isOverCap, isTrue);
      expect(res.isValid, isFalse);
      expect(res.hint, equals('Amount exceeds maximum limit of ₹10,00,00,000'));
    });
  });

  group('Part 2: Manual Split Validation & SplitCalculator', () {
    test('Exact split validation requires sum to match exactly', () {
      final valid = SplitCalculator.validateExact(
        totalPaise: 50000,
        memberIds: ['person_arjun', 'person_meera'],
        exactShares: {'person_arjun': 25000, 'person_meera': 25000},
      );
      expect(valid.isValid, isTrue);
      expect(valid.differencePaise, equals(0));

      final invalid = SplitCalculator.validateExact(
        totalPaise: 50000,
        memberIds: ['person_arjun', 'person_meera'],
        exactShares: {'person_arjun': 25000, 'person_meera': 20000},
      );
      expect(invalid.isValid, isFalse);
      expect(invalid.differencePaise, equals(5000));
    });

    test('Percent split distributes remainder deterministically to payer', () {
      final shares = SplitCalculator.splitPercent(
        totalPaise: 10000,
        memberIds: ['person_arjun', 'person_meera', 'person_kabir'],
        percentages: {
          'person_arjun': 33.33,
          'person_meera': 33.33,
          'person_kabir': 33.34,
        },
        paidBy: 'person_arjun',
      );
      expect(shares.values.fold<int>(0, (a, b) => a + b), equals(10000));
    });
  });

  group('Part 2: Duplicate Guard Logic', () {
    test('Detects duplicate logged within 2 minutes with same details', () {
      final now = DateTime.now();
      final existing = Expense(
        id: 'exp_dup_1',
        groupId: 'group_flatmates',
        title: 'Swiggy snacks',
        category: ExpenseCategory.groceries,
        amount: 68000,
        date: now.subtract(const Duration(seconds: 45)),
        paidBy: 'person_arjun',
        splitMode: SplitMode.equal,
        shares: const {'person_arjun': 34000, 'person_meera': 34000},
      );

      final expenses = [existing];

      // Exact match within 45 seconds -> duplicate!
      final isDuplicate = expenses.any(
        (e) =>
            !e.isDeleted &&
            e.groupId == 'group_flatmates' &&
            e.title.trim().toLowerCase() == 'swiggy snacks' &&
            e.amount == 68000 &&
            DateTime.now().difference(e.date).inMinutes.abs() < 2,
      );
      expect(isDuplicate, isTrue);

      // Different title -> NOT duplicate
      final isDifferentTitle = expenses.any(
        (e) =>
            !e.isDeleted &&
            e.groupId == 'group_flatmates' &&
            e.title.trim().toLowerCase() == 'zomato dinner' &&
            e.amount == 68000 &&
            DateTime.now().difference(e.date).inMinutes.abs() < 2,
      );
      expect(isDifferentTitle, isFalse);

      // Different amount -> NOT duplicate
      final isDifferentAmount = expenses.any(
        (e) =>
            !e.isDeleted &&
            e.groupId == 'group_flatmates' &&
            e.title.trim().toLowerCase() == 'swiggy snacks' &&
            e.amount == 70000 &&
            DateTime.now().difference(e.date).inMinutes.abs() < 2,
      );
      expect(isDifferentAmount, isFalse);

      // Different group -> NOT duplicate
      final isDifferentGroup = expenses.any(
        (e) =>
            !e.isDeleted &&
            e.groupId == 'group_goa' &&
            e.title.trim().toLowerCase() == 'swiggy snacks' &&
            e.amount == 68000 &&
            DateTime.now().difference(e.date).inMinutes.abs() < 2,
      );
      expect(isDifferentGroup, isFalse);
    });
  });

  group('Part 2: Repeat Suggestion Threshold', () {
    test('Seed data has no repeated titles with 3+ occurrences', () {
      final suggestions = RepeatSuggestionEngine.getRepeatSuggestions(
        expenses: SeedData.expenses,
        currentUserId: SeedData.currentUserId,
        threshold: 3,
      );
      expect(suggestions, isEmpty);
    });

    test('Threshold triggers ONLY when logged 3+ times in same group', () {
      final now = DateTime.now();
      Expense makeExpense(String id, String title, int minutesAgo) {
        return Expense(
          id: id,
          groupId: 'group_flatmates',
          title: title,
          category: ExpenseCategory.food,
          amount: 20000,
          date: now.subtract(Duration(minutes: minutesAgo)),
          paidBy: SeedData.currentUserId,
          splitMode: SplitMode.equal,
          shares: const {'person_arjun': 10000, 'person_meera': 10000},
        );
      }

      // 2 times -> not triggered
      final twoExpenses = [
        makeExpense('e1', 'Chai & samosa', 60),
        makeExpense('e2', 'chai & samosa', 30),
      ];
      final suggestions2 = RepeatSuggestionEngine.getRepeatSuggestions(
        expenses: twoExpenses,
        currentUserId: SeedData.currentUserId,
        threshold: 3,
      );
      expect(suggestions2, isEmpty);

      // 3 times -> triggered!
      final threeExpenses = [
        ...twoExpenses,
        makeExpense('e3', 'Chai & Samosa', 5),
      ];
      final suggestions3 = RepeatSuggestionEngine.getRepeatSuggestions(
        expenses: threeExpenses,
        currentUserId: SeedData.currentUserId,
        threshold: 3,
      );
      expect(suggestions3.length, equals(1));
      expect(suggestions3.first.normalizedTitle, equals('chai & samosa'));
      expect(suggestions3.first.count, equals(3));
      expect(suggestions3.first.latestAmountPaise, equals(20000));
    });
  });
}
