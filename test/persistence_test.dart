import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/data/repositories/persistent_app_repository.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/seed/seed_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersistentAppRepository Verification', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Initializes with default seed data when SharedPreferences is empty', () {
      final repo = PersistentAppRepository(prefs: prefs);
      expect(repo.getPeople().isNotEmpty, isTrue);
      expect(repo.getGroups().length, equals(SeedData.groups.length));
      expect(repo.getAllExpenses().length, equals(SeedData.expenses.length));
      expect(repo.wasCorruptDataRecovered, isFalse);
    });

    test('Round-trip serialization: adding an expense persists JSON', () async {
      final fakeNow = DateTime(2026, 11, 20, 12, 0);
      final repo = PersistentAppRepository(prefs: prefs, clock: () => fakeNow);

      final newExpense = Expense(
        id: 'test_exp_1',
        groupId: SeedData.flatmates.id,
        description: 'Test Groceries',
        category: ExpenseCategory.groceries,
        totalPaise: 50000,
        date: fakeNow,
        payers: const [PayerShare(personId: SeedData.currentUserId, paise: 50000)],
        splitMode: SplitMode.equal,
        computedShares: {
          SeedData.currentUserId: 25000,
          SeedData.flatmates.memberIds[1]: 25000,
        },
        createdAt: fakeNow,
      );

      repo.addExpense(newExpense);
      // Wait for 300ms to allow debounced save to fire
      await Future.delayed(const Duration(milliseconds: 300));

      // Check SharedPreferences holds the serialized key
      final savedJson = prefs.getString(PersistentAppRepository.storageKey);
      expect(savedJson, isNotNull);

      final decoded = jsonDecode(savedJson!) as Map<String, dynamic>;
      expect(decoded['version'], equals(PersistentAppRepository.schemaVersion));
      expect(decoded['expenses'], isA<List>());

      // Create a second repo instance reading the same SharedPreferences
      final repo2 = PersistentAppRepository(prefs: prefs);
      final loadedExp = repo2.getExpense('test_exp_1');
      expect(loadedExp, isNotNull);
      expect(loadedExp!.description, equals('Test Groceries'));
      expect(loadedExp.totalPaise, equals(50000));
    });

    test('Cleans up stale v1 storage and replaces with seed v2', () async {
      await prefs.setString('settliv_ledger_v1', '{"version": 1, "data": "stale"}');
      final repo = PersistentAppRepository(prefs: prefs);
      expect(prefs.containsKey('settliv_ledger_v1'), isFalse);
      expect(repo.getGroups().length, equals(SeedData.groups.length));
    });

    test('Corrupt JSON fallback: recovers to seed data cleanly and flags corrupt flag', () async {
      // Store corrupted/invalid JSON in prefs
      await prefs.setString(PersistentAppRepository.storageKey, '{"version": 999, "corrupt": true}');

      final repo = PersistentAppRepository(prefs: prefs);
      expect(repo.wasCorruptDataRecovered, isTrue);
      expect(repo.getGroups().isNotEmpty, isTrue);
      expect(repo.getAllExpenses().length, equals(SeedData.expenses.length));
    });

    test('Invariant validation: rejects malformed expense where shares do not sum to total', () async {
      final malformedData = {
        'version': PersistentAppRepository.schemaVersion,
        'currentUserId': SeedData.currentUserId,
        'people': SeedData.people.map((p) => p.toJson()).toList(),
        'groups': SeedData.groups.map((g) => g.toJson()).toList(),
        'expenses': [
          {
            'id': 'bad_exp',
            'groupId': SeedData.flatmates.id,
            'description': 'Bad Math',
            'category': 'groceries',
            'totalPaise': 10000, // 10000 paise
            'date': DateTime.now().toIso8601String(),
            'payers': [
              {'personId': SeedData.currentUserId, 'paise': 10000}
            ],
            'splitMode': 'equal',
            'computedShares': {
              SeedData.currentUserId: 5000, // Sum = 5000 != 10000 -> Violation!
            },
            'createdAt': DateTime.now().toIso8601String(),
          }
        ],
        'settlements': [],
        'recurringTemplates': [],
      };

      await prefs.setString(PersistentAppRepository.storageKey, jsonEncode(malformedData));

      final repo = PersistentAppRepository(prefs: prefs);
      // Because invariant check threw, it recovered safely to seed
      expect(repo.wasCorruptDataRecovered, isTrue);
      expect(repo.getExpense('bad_exp'), isNull);
    });

    test('startFresh() clears ledger to empty state', () async {
      final repo = PersistentAppRepository(prefs: prefs);
      expect(repo.getAllExpenses().isNotEmpty, isTrue);

      await repo.startFresh();
      expect(repo.getAllExpenses(), isEmpty);
      expect(repo.getAllSettlements(), isEmpty);
      // Groups and people remain available for user to use
      expect(repo.getPeople().isNotEmpty, isTrue);
    });

    test('resetDemoData() reloads complete seed state', () async {
      final repo = PersistentAppRepository(prefs: prefs);
      await repo.startFresh();
      expect(repo.getAllExpenses(), isEmpty);

      await repo.resetDemoData();
      expect(repo.getAllExpenses().length, equals(SeedData.expenses.length));
    });
  });
}
