import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/features/add_expense/logic/quick_expense_parser.dart';

void main() {
  group('QuickExpenseParser 10+ Phrase Tests', () {
    final parser = QuickExpenseParser(
      availablePeople: SeedData.people,
      availableGroups: SeedData.groups,
      currentUser: SeedData.arjun,
    );

    test('1. "dinner 800 with Meera and Kabir"', () {
      final res = parser.parse('dinner 800 with Meera and Kabir');
      expect(res.amountPaise, equals(80000));
      expect(res.category, equals(ExpenseCategory.food));
      expect(res.inferredGroup?.id, equals(SeedData.flatmates.id));
      expect(res.participants.map((p) => p.name).toSet(),
          containsAll({'Arjun', 'Meera', 'Kabir'}));
      expect(res.isValid, isTrue);
    });

    test('2. "Rent 18,000"', () {
      final res = parser.parse('Rent 18,000');
      expect(res.amountPaise, equals(1800000));
      expect(res.category, equals(ExpenseCategory.rent));
      expect(res.isValid, isTrue);
    });

    test('3. "Cab 240 with Kabir"', () {
      final res = parser.parse('Cab 240 with Kabir');
      expect(res.amountPaise, equals(24000));
      expect(res.category, equals(ExpenseCategory.travel));
      expect(res.inferredGroup?.id, equals(SeedData.flatmates.id));
      expect(res.participants.map((p) => p.name).toSet(),
          containsAll({'Arjun', 'Kabir'}));
      expect(res.isValid, isTrue);
    });

    test('4. "1.2k groceries at BigBasket"', () {
      final res = parser.parse('1.2k groceries at BigBasket');
      expect(res.amountPaise, equals(120000));
      expect(res.category, equals(ExpenseCategory.groceries));
      expect(res.isValid, isTrue);
    });

    test('5. "₹1200 wifi bill"', () {
      final res = parser.parse('₹1200 wifi bill');
      expect(res.amountPaise, equals(120000));
      expect(res.category, equals(ExpenseCategory.bills));
      expect(res.isValid, isTrue);
    });

    test('6. "scooters 4800 with Nisha Rohan and Tara"', () {
      final res = parser.parse('scooters 4800 with Nisha Rohan and Tara');
      expect(res.amountPaise, equals(480000));
      expect(res.category, equals(ExpenseCategory.travel));
      expect(res.inferredGroup?.id, equals(SeedData.goaTrip.id));
      expect(res.participants.length, equals(4));
      expect(res.isValid, isTrue);
    });

    test('7. "Thalassa sunset drinks 5.2k with Rohan"', () {
      final res = parser.parse('Thalassa sunset drinks 5.2k with Rohan');
      expect(res.amountPaise, equals(520000));
      expect(res.category, equals(ExpenseCategory.fun));
      expect(res.inferredGroup?.id, equals(SeedData.goaTrip.id));
      expect(res.isValid, isTrue);
    });

    test('8. "Vagator villa stay 28000"', () {
      final res = parser.parse('Vagator villa stay 28000');
      expect(res.amountPaise, equals(2800000));
      expect(res.category, equals(ExpenseCategory.stay));
      expect(res.isValid, isTrue);
    });

    test('9. "Movie tickets 950 with Meera"', () {
      final res = parser.parse('Movie tickets 950 with Meera');
      expect(res.amountPaise, equals(95000));
      expect(res.category, equals(ExpenseCategory.fun));
      expect(res.inferredGroup?.id, equals(SeedData.flatmates.id));
      expect(res.isValid, isTrue);
    });

    test('10. "Electricity 1860"', () {
      final res = parser.parse('Electricity 1860');
      expect(res.amountPaise, equals(186000));
      expect(res.category, equals(ExpenseCategory.bills));
      expect(res.isValid, isTrue);
    });

    test('11. Incomplete text without amount gives gentle hint', () {
      final res = parser.parse('dinner with Meera');
      expect(res.amountPaise, isNull);
      expect(res.isValid, isFalse);
      expect(res.hint, equals('Add an amount to continue'));
    });
  });
}
