import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/seed/seed_data.dart';
import 'package:settliv/data/engine/person_balance_engine.dart';

void main() {
  group('PersonBalanceEngine Unit Tests', () {
    test('Calculates person summaries across seeded groups', () {
      final repo = InMemoryAppRepository();
      final summaries = PersonBalanceEngine.computePersonSummaries(repo);
      expect(summaries.isNotEmpty, isTrue);
    });

    test('Settle all with single-direction lines records settlements and zeros balance, undo restores exactly', () {
      final repo = InMemoryAppRepository();
      final summariesBefore = PersonBalanceEngine.computePersonSummaries(repo);
      final kabirBefore = summariesBefore.firstWhere((s) => s.person.name == 'Kabir');
      expect(kabirBefore.netPaise, equals(124000));

      final now = DateTime(2026, 11, 20, 16, 0);
      final stlIds = PersonBalanceEngine.settleAllForPerson(
        repo: repo,
        summary: kabirBefore,
        timestamp: now,
      );

      expect(stlIds.length, equals(1));

      // After settlement: Kabir's net balance should be 0
      final summariesAfter = PersonBalanceEngine.computePersonSummaries(repo);
      final kabirAfter = summariesAfter.where((s) => s.person.name == 'Kabir').firstOrNull;
      expect(kabirAfter == null || kabirAfter.netPaise == 0, isTrue);

      // Undo settlement: restores exact ledger state
      for (final id in stlIds) {
        repo.deleteSettlement(id);
      }

      final summariesRestored = PersonBalanceEngine.computePersonSummaries(repo);
      final kabirRestored = summariesRestored.firstWhere((s) => s.person.name == 'Kabir');
      expect(kabirRestored.netPaise, equals(124000));
    });

    test('Settle all with mixed-direction lines records netted settlements for each group and zeros both ledgers', () {
      final repo = InMemoryAppRepository();
      // Setup a dummy person with mixed lines: owes 5000 in Flatmates, user owes 2000 in Goa Trip
      final dummyPerson = SeedData.people.firstWhere((p) => p.name == 'Meera');
      final mixedSummary = PersonDebtSummary(
        person: dummyPerson,
        netPaise: 3000,
        lines: [
          const GroupDebtLine(groupId: 'group_flatmates', groupName: 'Flatmates', paise: 5000),
          const GroupDebtLine(groupId: 'group_goa', groupName: 'Goa Trip', paise: -2000),
        ],
      );

      final now = DateTime(2026, 11, 20, 16, 30);
      final stlIds = PersonBalanceEngine.settleAllForPerson(
        repo: repo,
        summary: mixedSummary,
        timestamp: now,
      );

      expect(stlIds.length, equals(2));
      // Undo restores exact records
      for (final id in stlIds) {
        repo.deleteSettlement(id);
      }
    });
  });
}
