import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/person.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import '../engine/balance_engine.dart';
import '../seed/seed_data.dart';
import 'app_repository.dart';

class InMemoryAppRepository implements AppRepository {
  final BalanceEngine _engine = const BalanceEngine();

  late final List<Person> _people;
  late final List<Group> _groups;
  late final List<Expense> _expenses;
  late final List<Settlement> _settlements;

  InMemoryAppRepository() {
    _resetToSeed();
  }

  void _resetToSeed() {
    _people = List.from(SeedData.people);
    _groups = List.from(SeedData.groups);
    _expenses = List.from(SeedData.expenses);
    _settlements = List.from(SeedData.settlements);
  }

  @override
  String get currentUserId => SeedData.currentUserId;

  @override
  Person? get currentUser => getPerson(currentUserId);

  @override
  List<Person> getPeople() => List.unmodifiable(_people);

  @override
  Person? getPerson(String id) {
    try {
      return _people.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void addPerson(Person person) {
    if (!_people.any((p) => p.id == person.id)) {
      _people.add(person);
    }
  }

  @override
  List<Group> getGroups() => List.unmodifiable(_groups);

  @override
  Group? getGroup(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void addGroup(Group group) {
    if (!_groups.any((g) => g.id == group.id)) {
      _groups.add(group);
    }
  }

  @override
  List<Expense> getAllExpenses() => List.unmodifiable(
        _expenses.where((e) => !e.isDeleted).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
      );

  @override
  List<Expense> getExpensesForGroup(String groupId) => List.unmodifiable(
        _expenses.where((e) => e.groupId == groupId && !e.isDeleted).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
      );

  @override
  Expense? getExpense(String id) {
    try {
      return _expenses.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void addExpense(Expense expense) {
    _expenses.insert(0, expense);
  }

  @override
  void updateExpense(Expense expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index != -1) {
      _expenses[index] = expense;
    }
  }

  @override
  void deleteExpense(String id) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _expenses[index] = _expenses[index].copyWith(isDeleted: true);
    }
  }

  @override
  void restoreExpense(String id) {
    final index = _expenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _expenses[index] = _expenses[index].copyWith(isDeleted: false);
    }
  }

  @override
  void removeExpensePermanently(String id) {
    _expenses.removeWhere((e) => e.id == id);
  }

  @override
  List<Settlement> getAllSettlements() => List.unmodifiable(_settlements);

  @override
  List<Settlement> getSettlementsForGroup(String groupId) => List.unmodifiable(
        _settlements.where((s) => s.groupId == groupId).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
      );

  @override
  void addSettlement(Settlement settlement) {
    _settlements.insert(0, settlement);
  }

  @override
  void deleteSettlement(String id) {
    _settlements.removeWhere((s) => s.id == id);
  }

  @override
  GroupBalanceSummary getGroupSummary(String groupId) {
    final group = getGroup(groupId);
    final members = group?.memberIds ?? [];
    return _engine.computeGroupSummary(
      groupId: groupId,
      memberIds: members,
      expenses: _expenses,
      settlements: _settlements,
    );
  }

  @override
  UserOverallBalance getUserOverallBalance() {
    final groupMap = {for (final g in _groups) g.id: g.memberIds};
    return _engine.computeUserOverallBalance(
      currentUserId: currentUserId,
      groupIds: _groups.map((g) => g.id).toList(),
      groupMembersMap: groupMap,
      expenses: _expenses,
      settlements: _settlements,
    );
  }
}

// -----------------------------------------------------------------------------
// Riverpod State Providers
// -----------------------------------------------------------------------------

class AppStateNotifier extends Notifier<int> {
  late final InMemoryAppRepository repository;

  @override
  int build() {
    repository = InMemoryAppRepository();
    return 0; // State version counter
  }

  void notifyChange() {
    state = state + 1;
  }

  void addExpense(Expense expense) {
    repository.addExpense(expense);
    notifyChange();
  }

  void updateExpense(Expense expense) {
    repository.updateExpense(expense);
    notifyChange();
  }

  void deleteExpense(String id) {
    repository.deleteExpense(id);
    notifyChange();
  }

  void restoreExpense(String id) {
    repository.restoreExpense(id);
    notifyChange();
  }

  void addSettlement(Settlement settlement) {
    repository.addSettlement(settlement);
    notifyChange();
  }

  void deleteSettlement(String id) {
    repository.deleteSettlement(id);
    notifyChange();
  }

  void addGroup(Group group) {
    repository.addGroup(group);
    notifyChange();
  }

  void addPerson(Person person) {
    repository.addPerson(person);
    notifyChange();
  }
}

final appStateProvider =
    NotifierProvider<AppStateNotifier, int>(AppStateNotifier.new);

final appRepositoryProvider = Provider<AppRepository>((ref) {
  final notifier = ref.watch(appStateProvider.notifier);
  // Listen to version changes so consumers of repo-derived providers recompute
  ref.watch(appStateProvider);
  return notifier.repository;
});

final userOverallBalanceProvider = Provider<UserOverallBalance>((ref) {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getUserOverallBalance();
});

final allGroupsProvider = Provider<List<Group>>((ref) {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getGroups();
});

final groupProvider = Provider.family<Group?, String>((ref, groupId) {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getGroup(groupId);
});

final groupSummaryProvider =
    Provider.family<GroupBalanceSummary, String>((ref, groupId) {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getGroupSummary(groupId);
});

final allExpensesProvider = Provider<List<Expense>>((ref) {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getAllExpenses();
});

final groupExpensesProvider =
    Provider.family<List<Expense>, String>((ref, groupId) {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getExpensesForGroup(groupId);
});

final allPeopleProvider = Provider<List<Person>>((ref) {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getPeople();
});

final personProvider = Provider.family<Person?, String>((ref, personId) {
  final repo = ref.watch(appRepositoryProvider);
  return repo.getPerson(personId);
});
