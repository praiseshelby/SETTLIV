import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/data/models/group.dart';
import 'package:settliv/data/models/person.dart';
import 'package:settliv/data/models/expense.dart';
import 'package:settliv/data/models/recurring_template.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';

void main() {
  group('Extended Features - Group Management (Edit Group)', () {
    late InMemoryAppRepository repo;

    setUp(() {
      repo = InMemoryAppRepository();
    });

    test('Updating group name and coverThemeIndex works correctly', () {
      final initialGroup = repo.getGroups().firstWhere((g) => !g.isPersonal);
      expect(initialGroup.name, isNotEmpty);

      final updatedGroup = initialGroup.copyWith(
        name: 'Super Goa Trip 2026',
        coverThemeIndex: 3,
        type: GroupType.trip,
      );

      repo.updateGroup(updatedGroup);

      final retrieved = repo.getGroup(initialGroup.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Super Goa Trip 2026');
      expect(retrieved.coverThemeIndex, 3);
      expect(retrieved.type, GroupType.trip);
    });

    test('Adding new member to group updates member list', () {
      final initialGroup = repo.getGroups().firstWhere((g) => !g.isPersonal);
      const newPersonId = 'person_new_test_user';

      const newPerson = Person(
        id: newPersonId,
        name: 'New Test User',
        avatarInitials: 'NU',
        avatarPairIndex: 2,
      );
      repo.addPerson(newPerson);

      final updatedMembers = [...initialGroup.memberIds, newPersonId];
      final updatedGroup = initialGroup.copyWith(memberIds: updatedMembers);
      repo.updateGroup(updatedGroup);

      final retrieved = repo.getGroup(initialGroup.id);
      expect(retrieved!.memberIds, contains(newPersonId));
    });
  });

  group('Extended Features - Recurring Expenses Engine', () {
    late InMemoryAppRepository repo;

    setUp(() {
      repo = InMemoryAppRepository();
    });

    test('Adding and retrieving recurring templates', () {
      final group = repo.getGroups().firstWhere((g) => !g.isPersonal);
      final template = RecurringTemplate(
        id: 'rec_rent_1',
        groupId: group.id,
        description: 'Monthly Apartment Rent',
        category: ExpenseCategory.rent,
        totalPaise: 3000000, // ₹30,000
        payers: [PayerShare(personId: repo.currentUserId, paise: 3000000)],
        splitMode: SplitMode.equal,
        participants: group.memberIds,
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
      );

      repo.addRecurringTemplate(template);

      final templates = repo.getRecurringTemplates();
      expect(templates.length, 1);
      expect(templates.first.description, 'Monthly Apartment Rent');
      expect(templates.first.frequency, RecurringFrequency.monthly);
    });

    test('processDueRecurringExpenses generates due expense and updates template', () {
      final group = repo.getGroups().firstWhere((g) => !g.isPersonal);
      final startDate = DateTime(2026, 1, 1);
      final asOf = DateTime(2026, 1, 15);

      final template = RecurringTemplate(
        id: 'rec_wifi_1',
        groupId: group.id,
        description: 'WiFi Broadband',
        category: ExpenseCategory.bills,
        totalPaise: 99900, // ₹999
        payers: [PayerShare(personId: repo.currentUserId, paise: 99900)],
        splitMode: SplitMode.equal,
        participants: group.memberIds,
        frequency: RecurringFrequency.monthly,
        startDate: startDate,
      );

      repo.addRecurringTemplate(template);

      final countBefore = repo.getAllExpenses().length;
      final generated = repo.processDueRecurringExpenses(asOf: asOf);

      expect(generated.length, 1);
      expect(generated.first.description, 'WiFi Broadband');
      expect(generated.first.totalPaise, 99900);
      expect(repo.getAllExpenses().length, countBefore + 1);

      // Verify template lastGeneratedDate was updated
      final updatedTmpl = repo.getRecurringTemplates().firstWhere((t) => t.id == 'rec_wifi_1');
      expect(updatedTmpl.lastGeneratedDate, isNotNull);
      expect(updatedTmpl.lastGeneratedDate, startDate);

      // Processing again on the same day generates nothing
      final generatedAgain = repo.processDueRecurringExpenses(asOf: asOf);
      expect(generatedAgain.isEmpty, true);
    });

    test('Paused recurring template is not processed', () {
      final group = repo.getGroups().firstWhere((g) => !g.isPersonal);
      final template = RecurringTemplate(
        id: 'rec_paused_1',
        groupId: group.id,
        description: 'Gym Subscription',
        category: ExpenseCategory.other,
        totalPaise: 150000,
        payers: [PayerShare(personId: repo.currentUserId, paise: 150000)],
        splitMode: SplitMode.equal,
        participants: group.memberIds,
        frequency: RecurringFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
        isPaused: true,
      );

      repo.addRecurringTemplate(template);

      final generated = repo.processDueRecurringExpenses(asOf: DateTime(2026, 1, 15));
      expect(generated.isEmpty, true);
    });
  });

  group('Extended Features - Data Export & Import', () {
    late InMemoryAppRepository repo;

    setUp(() {
      repo = InMemoryAppRepository();
    });

    test('exportLedgerJson produces valid JSON adhering to schema', () {
      final jsonString = repo.exportLedgerJson();
      expect(jsonString, isNotEmpty);

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['version'], 2);
      expect(decoded['seedVersion'], 3);
      expect(decoded['people'], isA<List>());
      expect(decoded['groups'], isA<List>());
      expect(decoded['expenses'], isA<List>());
      expect(decoded['settlements'], isA<List>());
      expect(decoded['recurringTemplates'], isA<List>());
    });

    test('exportExpensesCsv produces CSV with correct headers and rows', () {
      final csvString = repo.exportExpensesCsv();
      expect(csvString, isNotEmpty);

      final lines = csvString.trim().split('\n');
      expect(lines.first, 'Date,Title,Category,Group,Amount (INR),Paid By,Split Mode,Is Personal');
      expect(lines.length, greaterThan(1));
    });

    test('restoreFromJson restores ledger successfully from valid JSON string', () {
      final exported = repo.exportLedgerJson();

      // Wipe or change data
      repo.addPerson(const Person(
        id: 'temp_user',
        name: 'Temp User',
        avatarInitials: 'TU',
      ));

      // Restore
      final success = repo.restoreFromJson(exported);
      expect(success, isTrue);

      // Verify temp_user is not in restored data
      expect(repo.getPerson('temp_user'), isNull);
    });

    test('restoreFromJson rejects invalid JSON without mutating existing data', () {
      final originalPeopleCount = repo.getPeople().length;

      final success = repo.restoreFromJson('{"version": 1, "corrupt": true}');
      expect(success, isFalse);

      // Verify data is completely intact
      expect(repo.getPeople().length, originalPeopleCount);
    });
  });

  group('Extended Features - UPI Deep-Linking', () {
    test('Constructs valid UPI deep-link URI structure', () {
      const upiId = 'arjun@okaxis';
      const payeeName = 'Arjun Verma';
      const amountStr = '450.00';
      const groupName = 'Flatmates';

      final uri = Uri.parse(
        'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(payeeName)}&am=$amountStr&cu=INR&tn=${Uri.encodeComponent("Settliv: $groupName")}',
      );

      expect(uri.scheme, 'upi');
      expect(uri.host, 'pay');
      expect(uri.queryParameters['pa'], 'arjun@okaxis');
      expect(uri.queryParameters['pn'], 'Arjun Verma');
      expect(uri.queryParameters['am'], '450.00');
      expect(uri.queryParameters['cu'], 'INR');
      expect(uri.queryParameters['tn'], 'Settliv: Flatmates');
    });
  });
}
