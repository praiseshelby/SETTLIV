import '../../core/utils/currency_formatter.dart';
import '../models/person.dart';
import '../models/settlement.dart';
import '../repositories/app_repository.dart';

class GroupDebtLine {
  final String groupId;
  final String groupName;
  final int paise; // positive = person owes user, negative = user owes person

  const GroupDebtLine({
    required this.groupId,
    required this.groupName,
    required this.paise,
  });

  bool get personOwesUser => paise > 0;
  bool get userOwesPerson => paise < 0;
  int get amountPaise => paise.abs();
}

class PersonDebtSummary {
  final Person person;
  final int netPaise; // positive = person owes user, negative = user owes person
  final List<GroupDebtLine> lines;

  const PersonDebtSummary({
    required this.person,
    required this.netPaise,
    required this.lines,
  });

  bool get personOwesUser => netPaise > 0;
  bool get userOwesPerson => netPaise < 0;
  int get amountPaise => netPaise.abs();

  String get breakdownText {
    return lines.map((l) {
      return '${l.groupName} ${CurrencyFormatter.formatPaise(l.amountPaise)}';
    }).join(' · ');
  }
}

class PersonBalanceEngine {
  const PersonBalanceEngine();

  /// Computes the list of PersonDebtSummary across all groups for current user.
  static List<PersonDebtSummary> computePersonSummaries(AppRepository repo) {
    final currentUserId = repo.currentUserId;
    final groups = repo.getGroups().where((g) => !g.isPersonal).toList();
    final Map<String, List<GroupDebtLine>> personLines = {};

    for (final group in groups) {
      final summary = repo.getGroupSummary(group.id);
      for (final debt in summary.debts) {
        if (debt.amount <= 0) continue;

        if (debt.toPersonId == currentUserId) {
          // debt.fromPersonId owes current user
          final personId = debt.fromPersonId;
          personLines.putIfAbsent(personId, () => []).add(
                GroupDebtLine(
                  groupId: group.id,
                  groupName: group.name,
                  paise: debt.amount,
                ),
              );
        } else if (debt.fromPersonId == currentUserId) {
          // current user owes debt.toPersonId
          final personId = debt.toPersonId;
          personLines.putIfAbsent(personId, () => []).add(
                GroupDebtLine(
                  groupId: group.id,
                  groupName: group.name,
                  paise: -debt.amount,
                ),
              );
        }
      }
    }

    final List<PersonDebtSummary> summaries = [];
    personLines.forEach((personId, lines) {
      final person = repo.getPerson(personId);
      if (person == null) return;

      final netPaise = lines.fold<int>(0, (sum, line) => sum + line.paise);
      if (netPaise == 0 && lines.isEmpty) return;

      summaries.add(
        PersonDebtSummary(
          person: person,
          netPaise: netPaise,
          lines: lines,
        ),
      );
    });

    return summaries;
  }

  /// Executes "Settle all" for a person:
  /// - If all lines point the same way (all positive or all negative),
  ///   creates one settlement per group for the exact line amount.
  /// - If directions are mixed, creates a clearly labelled netted settlement pair
  ///   so every group's ledger remains exact and never negative.
  /// Returns the list of created settlement IDs for undo tracking.
  static List<String> settleAllForPerson({
    required AppRepository repo,
    required PersonDebtSummary summary,
    required DateTime timestamp,
  }) {
    final currentUserId = repo.currentUserId;
    final otherUserId = summary.person.id;
    final lines = summary.lines.where((l) => l.paise != 0).toList();
    if (lines.isEmpty) return [];

    final createdIds = <String>[];

    // Check if all lines are same direction
    final allOwedToUser = lines.every((l) => l.paise > 0);
    final allUserOwes = lines.every((l) => l.paise < 0);

    if (allOwedToUser || allUserOwes) {
      for (final line in lines) {
        final id = 'stl_${line.groupId}_${DateTime.now().millisecondsSinceEpoch}_${createdIds.length}';
        final fromId = line.personOwesUser ? otherUserId : currentUserId;
        final toId = line.personOwesUser ? currentUserId : otherUserId;

        repo.addSettlement(
          Settlement(
            id: id,
            groupId: line.groupId,
            from: fromId,
            to: toId,
            paise: line.amountPaise,
            date: timestamp,
          ),
        );
        createdIds.add(id);
      }
      return createdIds;
    }

    // Directions are mixed!
    // We settle each group's balance directly with a settlement in that group
    // so every group's ledger balances cancel to zero cleanly.
    for (final line in lines) {
      final id = 'stl_net_${line.groupId}_${DateTime.now().millisecondsSinceEpoch}_${createdIds.length}';
      final fromId = line.personOwesUser ? otherUserId : currentUserId;
      final toId = line.personOwesUser ? currentUserId : otherUserId;

      repo.addSettlement(
        Settlement(
          id: id,
          groupId: line.groupId,
          from: fromId,
          to: toId,
          paise: line.amountPaise,
          date: timestamp,
        ),
      );
      createdIds.add(id);
    }

    return createdIds;
  }
}
