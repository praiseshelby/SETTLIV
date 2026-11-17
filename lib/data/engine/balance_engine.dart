import 'dart:math' as math;
import '../models/expense.dart';
import '../models/settlement.dart';

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

      totalSpend += exp.amount;
      categorySpend[exp.category] = (categorySpend[exp.category] ?? 0) + exp.amount;

      // Payer gets credited full amount
      net[exp.paidBy] = (net[exp.paidBy] ?? 0) + exp.amount;

      // Each participant owes their share
      exp.shares.forEach((personId, shareAmount) {
        net[personId] = (net[personId] ?? 0) - shareAmount;
      });
    }

    // Process settlements
    for (final s in settlements) {
      if (s.groupId != groupId) continue;
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
  UserOverallBalance computeUserOverallBalance({
    required String currentUserId,
    required List<String> groupIds,
    required Map<String, List<String>> groupMembersMap,
    required List<Expense> expenses,
    required List<Settlement> settlements,
  }) {
    int totalNet = 0;
    int totalOwedToUser = 0;
    int totalUserOwes = 0;

    for (final groupId in groupIds) {
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
}
