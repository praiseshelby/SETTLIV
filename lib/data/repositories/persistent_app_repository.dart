import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/person.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import '../models/recurring_template.dart';
import '../engine/balance_engine.dart';
import '../seed/seed_data.dart';
import 'app_repository.dart';

class PersistentAppRepository implements AppRepository {
  static const String storageKey = 'settliv_ledger_v1';
  static const int schemaVersion = 1;

  final BalanceEngine _engine = const BalanceEngine();
  final SharedPreferences? _prefs;
  final DateTime Function() _clock;

  late String _currentUserId;
  late List<Person> _people;
  late List<Group> _groups;
  late List<Expense> _expenses;
  late List<Settlement> _settlements;
  late List<RecurringTemplate> _recurringTemplates;

  bool _wasCorruptDataRecovered = false;
  Timer? _debounceTimer;

  PersistentAppRepository({
    SharedPreferences? prefs,
    DateTime Function()? clock,
  })  : _prefs = prefs,
        _clock = clock ?? DateTime.now {
    _loadInitialData();
  }

  void _loadInitialData() {
    _resetToSeed();
    if (_prefs != null) {
      final rawJson = _prefs.getString(storageKey);
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        _loadFromJsonString(rawJson);
      }
    }
  }

  void _resetToSeed() {
    _currentUserId = SeedData.currentUserId;
    _people = List.from(SeedData.people);
    _groups = List.from(SeedData.groups);
    _expenses = List.from(SeedData.expenses);
    _settlements = List.from(SeedData.settlements);
    _recurringTemplates = [];
  }

  bool _loadFromJsonString(String rawJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawJson) as Map<String, dynamic>;
      final int version = data['version'] as int? ?? 0;
      if (version != schemaVersion) {
        _wasCorruptDataRecovered = true;
        _resetToSeed();
        return false;
      }

      final String currentUserId = data['currentUserId'] as String? ?? SeedData.currentUserId;
      final peopleList = (data['people'] as List<dynamic>?)
              ?.map((p) => Person.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [];
      final groupsList = (data['groups'] as List<dynamic>?)
              ?.map((g) => Group.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [];
      final expensesList = (data['expenses'] as List<dynamic>?)
              ?.map((e) => Expense.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final settlementsList = (data['settlements'] as List<dynamic>?)
              ?.map((s) => Settlement.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];
      final recurringList = (data['recurringTemplates'] as List<dynamic>?)
              ?.map((r) => RecurringTemplate.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [];

      // Validate invariants
      final peopleIds = peopleList.map((p) => p.id).toSet();
      final groupIds = groupsList.map((g) => g.id).toSet();

      // Check current user exists
      if (!peopleIds.contains(currentUserId)) {
        throw FormatException('Current user $currentUserId not found in people');
      }

      // Check groups
      for (final g in groupsList) {
        for (final m in g.memberIds) {
          if (!peopleIds.contains(m)) {
            throw FormatException('Group ${g.id} has orphan member $m');
          }
        }
      }

      // Check expenses
      for (final e in expensesList) {
        if (!groupIds.contains(e.groupId)) {
          throw FormatException('Expense ${e.id} has orphan groupId ${e.groupId}');
        }
        // Shares must sum to totalPaise
        final sharesSum = e.computedShares.values.fold<int>(0, (a, b) => a + b);
        if (sharesSum != e.totalPaise) {
          throw FormatException('Expense ${e.id} shares ($sharesSum) != total (${e.totalPaise})');
        }
        // Payers must sum to totalPaise
        if (e.payers.isNotEmpty) {
          final payersSum = e.payers.fold<int>(0, (a, b) => a + b.paise);
          if (payersSum != e.totalPaise) {
            throw FormatException('Expense ${e.id} payers ($payersSum) != total (${e.totalPaise})');
          }
        }
        // Check member IDs
        for (final m in e.computedShares.keys) {
          if (!peopleIds.contains(m)) {
            throw FormatException('Expense ${e.id} has orphan share member $m');
          }
        }
        for (final p in e.payers) {
          if (!peopleIds.contains(p.personId)) {
            throw FormatException('Expense ${e.id} has orphan payer ${p.personId}');
          }
        }
      }

      // Check settlements
      for (final s in settlementsList) {
        if (!groupIds.contains(s.groupId)) {
          throw FormatException('Settlement ${s.id} has orphan groupId ${s.groupId}');
        }
        if (!peopleIds.contains(s.from) || !peopleIds.contains(s.to)) {
          throw FormatException('Settlement ${s.id} has orphan person (${s.from} -> ${s.to})');
        }
      }

      // All invariants passed! Apply loaded data
      _currentUserId = currentUserId;
      _people = peopleList;
      _groups = groupsList;
      _expenses = expensesList;
      _settlements = settlementsList;
      _recurringTemplates = recurringList;
      _wasCorruptDataRecovered = false;
      return true;
    } catch (e) {
      _wasCorruptDataRecovered = true;
      _resetToSeed();
      return false;
    }
  }

  void _scheduleSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _saveNow();
    });
  }

  Future<void> _saveNow() async {
    if (_prefs == null) return;
    try {
      final data = {
        'version': schemaVersion,
        'savedAt': _clock().toIso8601String(),
        'currentUserId': _currentUserId,
        'people': _people.map((p) => p.toJson()).toList(),
        'groups': _groups.map((g) => g.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'settlements': _settlements.map((s) => s.toJson()).toList(),
        'recurringTemplates': _recurringTemplates.map((r) => r.toJson()).toList(),
      };
      await _prefs.setString(storageKey, jsonEncode(data));
    } catch (_) {
      // Save failure handled gracefully
    }
  }

  @override
  bool get wasCorruptDataRecovered => _wasCorruptDataRecovered;

  @override
  DateTime Function() get clock => _clock;

  @override
  String get currentUserId => _currentUserId;

  @override
  Person? get currentUser => getPerson(_currentUserId);

  @override
  void updateCurrentUser({String? name, String? upiId}) {
    final user = currentUser;
    if (user != null) {
      final updated = user.copyWith(
        name: name ?? user.name,
        upiId: upiId ?? user.upiId,
      );
      updatePerson(updated);
    }
  }

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
      _scheduleSave();
    }
  }

  @override
  void updatePerson(Person person) {
    final idx = _people.indexWhere((p) => p.id == person.id);
    if (idx != -1) {
      _people[idx] = person;
      _scheduleSave();
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
      _scheduleSave();
    }
  }

  @override
  void updateGroup(Group group) {
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      _groups[idx] = group;
      _scheduleSave();
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
    _scheduleSave();
  }

  @override
  void updateExpense(Expense expense) {
    final idx = _expenses.indexWhere((e) => e.id == expense.id);
    if (idx != -1) {
      _expenses[idx] = expense;
      _scheduleSave();
    }
  }

  @override
  void deleteExpense(String id) {
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _expenses[idx] = _expenses[idx].copyWith(deletedAt: _clock());
      _scheduleSave();
    }
  }

  @override
  void restoreExpense(String id) {
    final idx = _expenses.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _expenses[idx] = _expenses[idx].copyWith(isDeleted: false);
      _scheduleSave();
    }
  }

  @override
  void removeExpensePermanently(String id) {
    _expenses.removeWhere((e) => e.id == id);
    _scheduleSave();
  }

  @override
  List<Settlement> getAllSettlements() => List.unmodifiable(
        _settlements.where((s) => !s.isDeleted).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
      );

  @override
  List<Settlement> getSettlementsForGroup(String groupId) => List.unmodifiable(
        _settlements.where((s) => s.groupId == groupId && !s.isDeleted).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
      );

  @override
  void addSettlement(Settlement settlement) {
    _settlements.insert(0, settlement);
    _scheduleSave();
  }

  @override
  void deleteSettlement(String id) {
    final idx = _settlements.indexWhere((s) => s.id == id);
    if (idx != -1) {
      _settlements[idx] = _settlements[idx].copyWith(deletedAt: _clock());
      _scheduleSave();
    }
  }

  @override
  List<RecurringTemplate> getRecurringTemplates() => List.unmodifiable(_recurringTemplates);

  @override
  void addRecurringTemplate(RecurringTemplate template) {
    _recurringTemplates.add(template);
    _scheduleSave();
  }

  @override
  void updateRecurringTemplate(RecurringTemplate template) {
    final idx = _recurringTemplates.indexWhere((r) => r.id == template.id);
    if (idx != -1) {
      _recurringTemplates[idx] = template;
      _scheduleSave();
    }
  }

  @override
  void deleteRecurringTemplate(String id) {
    _recurringTemplates.removeWhere((r) => r.id == id);
    _scheduleSave();
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

  @override
  Future<void> startFresh() async {
    final user = currentUser ?? SeedData.arjun;
    _people = [user];
    _groups = [
      Group(
        id: 'group_personal',
        name: 'Personal',
        type: GroupType.other,
        memberIds: [user.id],
        coverThemeIndex: 4,
        createdAt: _clock(),
      ),
    ];
    _expenses = [];
    _settlements = [];
    _recurringTemplates = [];
    await _saveNow();
  }

  @override
  Future<void> resetDemoData() async {
    _resetToSeed();
    _wasCorruptDataRecovered = false;
    await _saveNow();
  }

  @override
  Future<void> deleteAllData() async {
    if (_prefs != null) {
      await _prefs.remove(storageKey);
    }
    await startFresh();
  }
}
