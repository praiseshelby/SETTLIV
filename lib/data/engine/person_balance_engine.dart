import '../../core/utils/currency_formatter.dart';
import '../models/person.dart';
import '../models/settlement.dart';
import '../models/iou_note.dart';
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
  final List<IouNote> iouNotes;

  const PersonDebtSummary({
    required this.person,
    required this.netPaise,
    required this.lines,
    this.iouNotes = const [],
  });

  bool get personOwesUser => netPaise > 0;
  bool get userOwesPerson => netPaise < 0;
  int get amountPaise => netPaise.abs();

  String get breakdownText {
    final parts = <String>[];
    for (final l in lines) {
      parts.add('${l.groupName} ${CurrencyFormatter.formatPaise(l.amountPaise)}');
    }
    for (final i in iouNotes) {
      parts.add('IOU note ${CurrencyFormatter.formatPaise(i.remainingPaise)}');
    }
    return parts.join(' · ');
  }
}

class PersonBalanceEngine {
  const PersonBalanceEngine();

  /// Computes the list of PersonDebtSummary across all groups and active IOU notes.
  static List<PersonDebtSummary> computePersonSummaries(AppRepository repo) {
    final currentUserId = repo.currentUserId;
    final groups = repo.getGroups().where((g) => !g.isPersonal).toList();
    final allPeople = repo.getPeople();
    final Map<String, List<GroupDebtLine>> personLines = {};
    final Map<String, List<IouNote>> personIous = {};

    for (final group in groups) {
      final summary = repo.getGroupSummary(group.id);
      for (final debt in summary.debts) {
        if (debt.amount <= 0) continue;

        if (debt.toPersonId == currentUserId) {
          final personId = debt.fromPersonId;
          personLines.putIfAbsent(personId, () => []).add(
                GroupDebtLine(
                  groupId: group.id,
                  groupName: group.name,
                  paise: debt.amount,
                ),
              );
        } else if (debt.fromPersonId == currentUserId) {
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

    // Process IOU notes
    final iouNotes = repo.getAllIouNotes().where((n) => !n.isSettled).toList();
    final Map<String, Person> syntheticPeople = {};

    for (final note in iouNotes) {
      final normalizedName = note.personName.trim().toLowerCase();
      // Try to find matching person in repo
      Person? match;
      for (final p in allPeople) {
        if (p.name.trim().toLowerCase() == normalizedName) {
          match = p;
          break;
        }
      }

      final String personKey;
      if (match != null) {
        personKey = match.id;
      } else {
        personKey = 'iou_$normalizedName';
        syntheticPeople.putIfAbsent(
          personKey,
          () => Person(
            id: personKey,
            name: note.personName,
            phone: note.phone,
          ),
        );
      }

      personIous.putIfAbsent(personKey, () => []).add(note);
    }

    final allPersonKeys = {...personLines.keys, ...personIous.keys};
    final List<PersonDebtSummary> summaries = [];

    for (final personId in allPersonKeys) {
      final person = repo.getPerson(personId) ?? syntheticPeople[personId];
      if (person == null) continue;

      final lines = personLines[personId] ?? const [];
      final ious = personIous[personId] ?? const [];

      int netPaise = lines.fold<int>(0, (sum, line) => sum + line.paise);
      for (final iou in ious) {
        if (iou.direction == IouDirection.owedToMe) {
          netPaise += iou.remainingPaise;
        } else {
          netPaise -= iou.remainingPaise;
        }
      }

      if (netPaise == 0 && lines.isEmpty && ious.isEmpty) continue;

      summaries.add(
        PersonDebtSummary(
          person: person,
          netPaise: netPaise,
          lines: lines,
          iouNotes: ious,
        ),
      );
    }

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
