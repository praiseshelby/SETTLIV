import 'dart:math' as math;
import '../models/expense.dart';
import '../models/settlement.dart';
import '../models/iou_note.dart';
import '../models/person.dart';
import '../models/group.dart';

class SimplifiedDebt {
  final String fromPersonId;
  final String toPersonId;
  final int amount; // in paise

  const SimplifiedDebt({
    required this.fromPersonId,
    required this.toPersonId,
    required this.amount,
  });
}

class CounterpartyNet {
  final Person person;
  final int netPaise; // positive = person owes user, negative = user owes person

  const CounterpartyNet({
    required this.person,
    required this.netPaise,
  });
}

class GroupBalanceSummary {
  final String groupId;
  final Map<String, int> netBalances; // personId -> paise (positive = owed to them, negative = they owe)
  final List<SimplifiedDebt> debts;
  final Map<ExpenseCategory, int> categorySpend; // category -> total paise
  final int totalSpend; // in paise

  const GroupBalanceSummary({
    required this.groupId,
    required this.netBalances,
    required this.debts,
    required this.categorySpend,
    required this.totalSpend,
  });
}

class UserOverallBalance {
  final String userId;
  final int netBalance; // in paise (positive = net owed to user, negative = net user owes)
  final int totalOwedToUser; // sum of positive balances for user across groups
  final int totalUserOwes; // sum of negative balances for user across groups (positive number)

  const UserOverallBalance({
    required this.userId,
    required this.netBalance,
    required this.totalOwedToUser,
    required this.totalUserOwes,
  });
}

class BalanceEngine {
  const BalanceEngine();

  /// Computes the net balances and simplified debt plan for a specific group.
  GroupBalanceSummary computeGroupSummary({
    required String groupId,
    required List<String> memberIds,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    final Map<String, int> net = {for (final m in memberIds) m: 0};
    final Map<ExpenseCategory, int> categorySpend = {
      for (final c in ExpenseCategory.values) c: 0,
    };
    int totalSpend = 0;

    // Process non-deleted expenses for this group
    for (final exp in expenses) {
      if (exp.groupId != groupId || exp.isDeleted) continue;

      totalSpend += exp.totalPaise;
      categorySpend[exp.category] = (categorySpend[exp.category] ?? 0) + exp.totalPaise;

      // Payer(s) get credited full amount
      if (exp.payers.isNotEmpty) {
        for (final p in exp.payers) {
          net[p.personId] = (net[p.personId] ?? 0) + p.paise;
        }
      } else {
        net[exp.paidBy] = (net[exp.paidBy] ?? 0) + exp.amount;
      }

      // Each participant owes their share
      exp.shares.forEach((personId, shareAmount) {
        net[personId] = (net[personId] ?? 0) - shareAmount;
      });
    }

    // Process non-deleted settlements
    for (final s in settlements) {
      if (s.groupId != groupId || s.isDeleted) continue;
      // Payer paid off debt -> net increases
      net[s.payerId] = (net[s.payerId] ?? 0) + s.amount;
      // Payee received payment -> net decreases
      net[s.payeeId] = (net[s.payeeId] ?? 0) - s.amount;
    }

    final debts = _simplifyDebts(net);

    return GroupBalanceSummary(
      groupId: groupId,
      netBalances: net,
      debts: debts,
      categorySpend: categorySpend,
      totalSpend: totalSpend,
    );
  }

  /// Computes overall balances across all groups for a specific user.
  /// Skips personal group ('group_personal') which is excluded from balances.
  UserOverallBalance computeUserOverallBalance({
    required String currentUserId,
    required List<String> groupIds,
    required Map<String, List<String>> groupMembersMap,
    required List<Expense> expenses,
    required List<Settlement> settlements,
    List<IouNote>? iouNotes,
  }) {
    int totalNet = 0;
    int totalOwedToUser = 0;
    int totalUserOwes = 0;

    for (final groupId in groupIds) {
      if (groupId == 'group_personal') continue; // Excluded from shared balances

      final members = groupMembersMap[groupId] ?? [];
      final summary = computeGroupSummary(
        groupId: groupId,
        memberIds: members,
        expenses: expenses,
        settlements: settlements,
      );

      final userNetInGroup = summary.netBalances[currentUserId] ?? 0;
      totalNet += userNetInGroup;

      if (userNetInGroup > 0) {
        totalOwedToUser += userNetInGroup;
      } else if (userNetInGroup < 0) {
        totalUserOwes += userNetInGroup.abs();
      }
    }

    if (iouNotes != null) {
      for (final note in iouNotes) {
        if (note.isDeleted || note.isSettled) continue;
        if (note.direction == IouDirection.owedToMe) {
          totalOwedToUser += note.remainingPaise;
          totalNet += note.remainingPaise;
        } else {
          totalUserOwes += note.remainingPaise;
          totalNet -= note.remainingPaise;
        }
      }
    }

    return UserOverallBalance(
      userId: currentUserId,
      netBalance: totalNet,
      totalOwedToUser: totalOwedToUser,
      totalUserOwes: totalUserOwes,
    );
  }

  /// Simplifies debt using greedy matching of largest creditor and largest debtor.
  List<SimplifiedDebt> _simplifyDebts(Map<String, int> netBalances) {
    final List<MapEntry<String, int>> creditors = [];
    final List<MapEntry<String, int>> debtors = [];

    netBalances.forEach((personId, balance) {
      if (balance > 0) {
        creditors.add(MapEntry(personId, balance));
      } else if (balance < 0) {
        debtors.add(MapEntry(personId, balance.abs()));
      }
    });

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final List<SimplifiedDebt> results = [];
    int cIdx = 0;
    int dIdx = 0;

    while (cIdx < creditors.length && dIdx < debtors.length) {
      final creditor = creditors[cIdx];
      final debtor = debtors[dIdx];

      final int settleAmount = math.min(creditor.value, debtor.value);
      if (settleAmount > 0) {
        results.add(
          SimplifiedDebt(
            fromPersonId: debtor.key,
            toPersonId: creditor.key,
            amount: settleAmount,
          ),
        );
      }

      final int newCreditorVal = creditor.value - settleAmount;
      final int newDebtorVal = debtor.value - settleAmount;

      if (newCreditorVal == 0) {
        cIdx++;
      } else {
        creditors[cIdx] = MapEntry(creditor.key, newCreditorVal);
      }

      if (newDebtorVal == 0) {
        dIdx++;
      } else {
        debtors[dIdx] = MapEntry(debtor.key, newDebtorVal);
      }
    }

    return results;
  }

  /// Computes per-counterparty net balances across all groups and active IOUs.
  List<CounterpartyNet> computeCounterpartyNets({
    required String currentUserId,
    required List<Group> groups,
    required Map<String, List<String>> groupMembersMap,
    required List<Expense> expenses,
    required List<Settlement> settlements,
    List<IouNote>? iouNotes,
    required Map<String, Person> peopleMap,
  }) {
    final Map<String, int> netPerPerson = {};

    // 1. Group simplified debts
    for (final group in groups) {
      if (group.isPersonal || group.id == 'group_personal') continue;
      final members = groupMembersMap[group.id] ?? group.memberIds;
      final summary = computeGroupSummary(
        groupId: group.id,
        memberIds: members,
        expenses: expenses,
        settlements: settlements,
      );

      for (final debt in summary.debts) {
        if (debt.toPersonId == currentUserId) {
          netPerPerson[debt.fromPersonId] =
              (netPerPerson[debt.fromPersonId] ?? 0) + debt.amount;
        } else if (debt.fromPersonId == currentUserId) {
          netPerPerson[debt.toPersonId] =
              (netPerPerson[debt.toPersonId] ?? 0) - debt.amount;
        }
      }
    }

    // 2. Active IOU notes
    if (iouNotes != null) {
      for (final note in iouNotes) {
        if (note.isDeleted || note.isSettled) continue;
        final normName = note.counterpartyName.trim().toLowerCase();
        String? targetPersonId;
        for (final p in peopleMap.values) {
          if (p.name.trim().toLowerCase() == normName) {
            targetPersonId = p.id;
            break;
          }
        }
        if (targetPersonId != null && targetPersonId != currentUserId) {
          if (note.direction == IouDirection.owedToMe) {
            netPerPerson[targetPersonId] =
                (netPerPerson[targetPersonId] ?? 0) + note.remainingPaise;
          } else {
            netPerPerson[targetPersonId] =
                (netPerPerson[targetPersonId] ?? 0) - note.remainingPaise;
          }
        }
      }
    }

    final List<CounterpartyNet> results = [];
    netPerPerson.forEach((pId, net) {
      if (net != 0 && peopleMap.containsKey(pId)) {
        results.add(CounterpartyNet(person: peopleMap[pId]!, netPaise: net));
      }
    });

    return results;
  }

  /// Computes the age of a debt in days using FIFO matching of settlements against expenses.
  int computeDebtAgeInDays({
    required String debtorId,
    required String creditorId,
    required String groupId,
    required List<Expense> expenses,
    required List<Settlement> settlements,
    required DateTime now,
  }) {
    // 1. Find all group expenses involving the debtor where debtor owes a share
    final relevantExpenses = expenses.where((e) {
      if (e.isDeleted || e.groupId != groupId) return false;
      final share = e.computedShares[debtorId] ?? e.shares[debtorId] ?? 0;
      return share > 0;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // 2. Total settled by debtor in this group
    final debtorSettlements = settlements.where((s) {
      return !s.isDeleted && s.groupId == groupId && s.from == debtorId;
    }).toList();
    int totalSettled = debtorSettlements.fold<int>(0, (sum, s) => sum + s.paise);

    // 3. FIFO consumption: settle oldest expenses first
    for (final exp in relevantExpenses) {
      final share = exp.computedShares[debtorId] ?? exp.shares[debtorId] ?? 0;
      if (totalSettled >= share) {
        totalSettled -= share;
      } else {
        // This expense has an unpaid portion!
        return math.max(0, now.difference(exp.date).inDays);
      }
    }

    if (relevantExpenses.isNotEmpty) {
      return math.max(0, now.difference(relevantExpenses.last.date).inDays);
    }
    return 0;
  }
}
