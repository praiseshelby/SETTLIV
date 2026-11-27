import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/person.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import '../models/recurring_template.dart';
import '../models/iou_note.dart';
import '../models/savings_goal.dart';
import '../models/feedback_report.dart';
import '../engine/balance_engine.dart';
import '../engine/split_calculator.dart';
import '../seed/seed_data.dart';
import 'app_repository.dart';

class PersistentAppRepository implements AppRepository {
  static const String defaultStorageKey = 'settliv_ledger_v2';
  static const int schemaVersion = 2;
  static const int seedVersion = 3;

  final BalanceEngine _engine = const BalanceEngine();
  final SharedPreferences? _prefs;
  final DateTime Function() _clock;
  final String storageKey;
  final bool startEmpty;
  final Person? initialUser;

  late String _currentUserId;
  late List<Person> _people;
  late List<Group> _groups;
  late List<Expense> _expenses;
  late List<Settlement> _settlements;
  late List<RecurringTemplate> _recurringTemplates;
  late List<IouNote> _iouNotes;
  late List<SavingsGoal> _savingsGoals;
  late List<FeedbackReport> _feedbackReports;

  bool _wasCorruptDataRecovered = false;
  Timer? _debounceTimer;

  PersistentAppRepository({
    SharedPreferences? prefs,
    DateTime Function()? clock,
    this.storageKey = defaultStorageKey,
    this.startEmpty = false,
    this.initialUser,
  })  : _prefs = prefs,
        _clock = clock ?? DateTime.now {
    _loadInitialData();
  }

  void _loadInitialData() {
    if (startEmpty) {
      _resetToEmpty();
    } else {
      _resetToSeed();
    }
    if (_prefs != null) {
      // Clean up stale v1 storage key if present
      if (_prefs.containsKey('settliv_ledger_v1')) {
        _prefs.remove('settliv_ledger_v1');
      }

      final rawJson = _prefs.getString(storageKey);
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        _loadFromJsonString(rawJson);
      }
    }
  }

  void _resetToEmpty() {
    final user = initialUser ??
        const Person(
          id: 'user_self',
          name: 'You',
        );
    _currentUserId = user.id;
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
    _iouNotes = [];
    _savingsGoals = [];
    _feedbackReports = [];
  }

  void replaceAllState({
    required List<Person> people,
    required List<Group> groups,
    required List<Expense> expenses,
    required List<Settlement> settlements,
    List<IouNote> ious = const [],
    List<RecurringTemplate> recurring = const [],
    List<SavingsGoal> goals = const [],
  }) {
    _people = List.from(people);
    _groups = List.from(groups);
    _expenses = List.from(expenses);
    _settlements = List.from(settlements);
    _iouNotes = List.from(ious);
    _recurringTemplates = List.from(recurring);
    _savingsGoals = List.from(goals);
    _saveToStorageImmediate();
  }

  void _resetToSeed() {
    _currentUserId = SeedData.currentUserId;
    _people = List.from(SeedData.people);
    _groups = List.from(SeedData.groups);
    _expenses = List.from(SeedData.expenses);
    _settlements = List.from(SeedData.settlements);
    _recurringTemplates = [];
    _iouNotes = [];
    _savingsGoals = [
      SavingsGoal(
        id: 'goal_emergency',
        name: 'Emergency Fund',
        targetPaise: 10000000,
        savedPaise: 4250000,
        targetDate: _clock().add(const Duration(days: 90)),
        createdAt: _clock().subtract(const Duration(days: 60)),
      ),
      SavingsGoal(
        id: 'goal_vacation',
        name: 'Goa Next Trip',
        targetPaise: 3000000,
        savedPaise: 2400000,
        targetDate: _clock().add(const Duration(days: 45)),
        createdAt: _clock().subtract(const Duration(days: 30)),
      ),
    ];
    _feedbackReports = [];
  }

  bool _loadFromJsonString(String rawJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawJson) as Map<String, dynamic>;
      final int version = data['version'] as int? ?? 0;
      final int loadedSeedVersion = data['seedVersion'] as int? ?? 0;
      if (version != schemaVersion || loadedSeedVersion < seedVersion) {
        _wasCorruptDataRecovered = true;
        _resetToSeed();
        _saveToStorageImmediate();
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
      final iouList = (data['iouNotes'] as List<dynamic>?)
              ?.map((i) => IouNote.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [];
      final savingsList = (data['savingsGoals'] as List<dynamic>?)
              ?.map((s) => SavingsGoal.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];
      final feedbackList = (data['feedbackReports'] as List<dynamic>?)
              ?.map((f) => FeedbackReport.fromJson(f as Map<String, dynamic>))
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
      _iouNotes = iouList;
      _savingsGoals = savingsList;
      _feedbackReports = feedbackList;
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

  void _saveToStorageImmediate() {
    _debounceTimer?.cancel();
    _saveNow();
  }

  Future<void> _saveNow() async {
    if (_prefs == null) return;
    try {
      final data = {
        'version': schemaVersion,
        'seedVersion': seedVersion,
        'savedAt': _clock().toIso8601String(),
        'currentUserId': _currentUserId,
        'people': _people.map((p) => p.toJson()).toList(),
        'groups': _groups.map((g) => g.toJson()).toList(),
        'expenses': _expenses.map((e) => e.toJson()).toList(),
        'settlements': _settlements.map((s) => s.toJson()).toList(),
        'recurringTemplates': _recurringTemplates.map((r) => r.toJson()).toList(),
        'iouNotes': _iouNotes.map((i) => i.toJson()).toList(),
        'savingsGoals': _savingsGoals.map((s) => s.toJson()).toList(),
        'feedbackReports': _feedbackReports.map((f) => f.toJson()).toList(),
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
  List<IouNote> getAllIouNotes() => List.unmodifiable(
        _iouNotes.where((i) => !i.isDeleted).toList()
          ..sort((a, b) => b.date.compareTo(a.date)),
      );

  @override
  IouNote? getIouNote(String id) {
    try {
      return _iouNotes.firstWhere((i) => i.id == id && !i.isDeleted);
    } catch (_) {
      return null;
    }
  }

  @override
  void addIouNote(IouNote note) {
    _iouNotes.insert(0, note);
    _scheduleSave();
  }

  @override
  void updateIouNote(IouNote note) {
    final idx = _iouNotes.indexWhere((i) => i.id == note.id);
    if (idx != -1) {
      _iouNotes[idx] = note;
      _scheduleSave();
    }
  }

  @override
  void deleteIouNote(String id) {
    final idx = _iouNotes.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _iouNotes[idx] = _iouNotes[idx].copyWith(deletedAt: _clock());
      _scheduleSave();
    }
  }

  @override
  void restoreIouNote(String id) {
    final idx = _iouNotes.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _iouNotes[idx] = _iouNotes[idx].copyWith(clearDeletedAt: true);
      _scheduleSave();
    }
  }

  @override
  void recordIouPayment(String noteId, int amountPaise) {
    final idx = _iouNotes.indexWhere((i) => i.id == noteId);
    if (idx != -1) {
      final note = _iouNotes[idx];
      final newPayment = IouPayment(
        id: 'ioup_${DateTime.now().millisecondsSinceEpoch}',
        amountPaise: amountPaise,
        date: _clock(),
      );
      _iouNotes[idx] = note.copyWith(
        payments: [...note.payments, newPayment],
      );
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
  List<Expense> processDueRecurringExpenses({DateTime? asOf}) {
    final now = asOf ?? _clock();
    final generated = <Expense>[];

    for (int i = 0; i < _recurringTemplates.length; i++) {
      final template = _recurringTemplates[i];
      if (template.isPaused) continue;
      if (template.endDate != null && now.isAfter(template.endDate!)) continue;

      DateTime nextDate;
      if (template.lastGeneratedDate == null) {
        nextDate = template.startDate;
      } else {
        nextDate = _calculateNextDueDate(template.lastGeneratedDate!, template.frequency);
      }

      var currentTemplate = template;
      while (!nextDate.isAfter(now) &&
          (currentTemplate.endDate == null || !nextDate.isAfter(currentTemplate.endDate!))) {
        final payerId = currentTemplate.payers.isNotEmpty
            ? currentTemplate.payers.first.personId
            : currentUserId;

        final shares = SplitCalculator.splitEqual(
          totalPaise: currentTemplate.totalPaise,
          memberIds: currentTemplate.participants,
          paidBy: payerId,
        );

        final newExpense = Expense(
          id: 'rec_${currentTemplate.id}_${nextDate.millisecondsSinceEpoch}',
          groupId: currentTemplate.groupId,
          description: currentTemplate.description,
          note: currentTemplate.note ?? 'Recurring (${currentTemplate.frequency.label})',
          category: currentTemplate.category,
          totalPaise: currentTemplate.totalPaise,
          date: nextDate,
          payers: currentTemplate.payers,
          splitMode: currentTemplate.splitMode,
          splitParameters: currentTemplate.splitParameters,
          participants: currentTemplate.participants,
          computedShares: shares,
          createdAt: _clock(),
        );

        generated.add(newExpense);
        _expenses.insert(0, newExpense);

        currentTemplate = currentTemplate.copyWith(lastGeneratedDate: nextDate);
        nextDate = _calculateNextDueDate(nextDate, currentTemplate.frequency);
      }

      if (currentTemplate != template) {
        _recurringTemplates[i] = currentTemplate;
      }
    }

    if (generated.isNotEmpty) {
      _scheduleSave();
    }
    return generated;
  }

  DateTime _calculateNextDueDate(DateTime from, RecurringFrequency freq) {
    switch (freq) {
      case RecurringFrequency.daily:
        return from.add(const Duration(days: 1));
      case RecurringFrequency.weekly:
        return from.add(const Duration(days: 7));
      case RecurringFrequency.monthly:
        int year = from.year;
        int month = from.month + 1;
        if (month > 12) {
          year++;
          month = 1;
        }
        final maxDay = _daysInMonth(year, month);
        final day = from.day.clamp(1, maxDay);
        return DateTime(year, month, day, from.hour, from.minute);
      case RecurringFrequency.yearly:
        int year = from.year + 1;
        final maxDay = _daysInMonth(year, from.month);
        final day = from.day.clamp(1, maxDay);
        return DateTime(year, from.month, day, from.hour, from.minute);
    }
  }

  int _daysInMonth(int year, int month) {
    final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  @override
  List<SavingsGoal> getSavingsGoals() => List.unmodifiable(_savingsGoals);

  @override
  SavingsGoal? getSavingsGoal(String id) {
    try {
      return _savingsGoals.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void addSavingsGoal(SavingsGoal goal) {
    _savingsGoals.add(goal);
    _scheduleSave();
  }

  @override
  void updateSavingsGoal(SavingsGoal goal) {
    final idx = _savingsGoals.indexWhere((g) => g.id == goal.id);
    if (idx != -1) {
      _savingsGoals[idx] = goal;
      _scheduleSave();
    }
  }

  @override
  void deleteSavingsGoal(String id) {
    _savingsGoals.removeWhere((g) => g.id == id);
    _scheduleSave();
  }

  @override
  void contributeToSavingsGoal(String id, int amountPaise) {
    final goal = getSavingsGoal(id);
    if (goal != null && amountPaise > 0) {
      updateSavingsGoal(goal.copyWith(savedPaise: goal.savedPaise + amountPaise));
    }
  }

  @override
  void withdrawFromSavingsGoal(String id, int amountPaise) {
    final goal = getSavingsGoal(id);
    if (goal != null && amountPaise > 0) {
      final newSaved = (goal.savedPaise - amountPaise).clamp(0, 100000000000).toInt();
      updateSavingsGoal(goal.copyWith(savedPaise: newSaved));
    }
  }

  @override
  List<FeedbackReport> getFeedbackReports() => List.unmodifiable(_feedbackReports);

  @override
  void addFeedbackReport(FeedbackReport report) {
    _feedbackReports.insert(0, report);
    _scheduleSave();
  }

  @override
  void deleteFeedbackReport(String id) {
    _feedbackReports.removeWhere((f) => f.id == id);
    _scheduleSave();
  }

  @override
  String exportLedgerJson() {
    final data = {
      'version': schemaVersion,
      'seedVersion': seedVersion,
      'savedAt': _clock().toIso8601String(),
      'currentUserId': _currentUserId,
      'people': _people.map((p) => p.toJson()).toList(),
      'groups': _groups.map((g) => g.toJson()).toList(),
      'expenses': _expenses.map((e) => e.toJson()).toList(),
      'settlements': _settlements.map((s) => s.toJson()).toList(),
      'recurringTemplates': _recurringTemplates.map((r) => r.toJson()).toList(),
      'iouNotes': _iouNotes.map((i) => i.toJson()).toList(),
      'savingsGoals': _savingsGoals.map((s) => s.toJson()).toList(),
      'feedbackReports': _feedbackReports.map((f) => f.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  @override
  String exportExpensesCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Date,Title,Category,Group,Amount (INR),Paid By,Split Mode,Is Personal');

    final groupMap = {for (final g in _groups) g.id: g.name};
    final personMap = {for (final p in _people) p.id: p.name};

    final activeExpenses = _expenses.where((e) => !e.isDeleted).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    for (final e in activeExpenses) {
      final dateStr =
          '${e.date.year.toString().padLeft(4, '0')}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      final titleEscaped = '"${e.description.replaceAll('"', '""')}"';
      final category = e.category.label;
      final groupName = groupMap[e.groupId] ?? 'Unknown';
      final groupEscaped = '"${groupName.replaceAll('"', '""')}"';
      final amount = (e.totalPaise / 100).toStringAsFixed(2);
      final payerName = e.payers.isNotEmpty
          ? (personMap[e.payers.first.personId] ?? e.payers.first.personId)
          : 'Unknown';
      final payerEscaped = '"${payerName.replaceAll('"', '""')}"';
      final splitMode = e.splitMode.label;
      final isPersonal = e.groupId == 'group_personal' ? 'Yes' : 'No';

      buffer.writeln('$dateStr,$titleEscaped,$category,$groupEscaped,$amount,$payerEscaped,$splitMode,$isPersonal');
    }

    return buffer.toString();
  }

  @override
  bool restoreFromJson(String rawJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawJson) as Map<String, dynamic>;
      final int version = data['version'] as int? ?? 0;
      final int loadedSeedVersion = data['seedVersion'] as int? ?? 0;
      if (version != schemaVersion || loadedSeedVersion < seedVersion) {
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
      final iouList = (data['iouNotes'] as List<dynamic>?)
              ?.map((i) => IouNote.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [];
      final savingsList = (data['savingsGoals'] as List<dynamic>?)
              ?.map((s) => SavingsGoal.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [];
      final feedbackList = (data['feedbackReports'] as List<dynamic>?)
              ?.map((f) => FeedbackReport.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [];

      // Validate invariants
      final peopleIds = peopleList.map((p) => p.id).toSet();
      final groupIds = groupsList.map((g) => g.id).toSet();

      if (!peopleIds.contains(currentUserId)) {
        return false;
      }
      for (final g in groupsList) {
        for (final m in g.memberIds) {
          if (!peopleIds.contains(m)) return false;
        }
      }
      for (final e in expensesList) {
        if (!groupIds.contains(e.groupId)) return false;
        final sharesSum = e.computedShares.values.fold<int>(0, (a, b) => a + b);
        if (sharesSum != e.totalPaise) return false;
        for (final m in e.computedShares.keys) {
          if (!peopleIds.contains(m)) return false;
        }
        for (final p in e.payers) {
          if (!peopleIds.contains(p.personId)) return false;
        }
      }
      for (final s in settlementsList) {
        if (!groupIds.contains(s.groupId)) return false;
        if (!peopleIds.contains(s.from) || !peopleIds.contains(s.to)) return false;
      }

      // Valid! Commit state
      _currentUserId = currentUserId;
      _people = peopleList;
      _groups = groupsList;
      _expenses = expensesList;
      _settlements = settlementsList;
      _recurringTemplates = recurringList;
      _iouNotes = iouList;
      _savingsGoals = savingsList;
      _feedbackReports = feedbackList;
      _wasCorruptDataRecovered = false;
      _saveToStorageImmediate();
      return true;
    } catch (_) {
      return false;
    }
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
      iouNotes: _iouNotes,
    );
  }

  @override
  Future<void> startFresh() async {
    final user = currentUser ??
        initialUser ??
        (startEmpty
            ? const Person(id: 'user_self', name: 'You')
            : SeedData.arjun);
    _currentUserId = user.id;
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
    _iouNotes = [];
    _savingsGoals = [];
    _feedbackReports = [];
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
