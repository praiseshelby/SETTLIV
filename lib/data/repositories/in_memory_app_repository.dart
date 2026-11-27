import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_repository.dart';
import '../../supabase_config.dart';
import '../models/person.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import '../models/recurring_template.dart';
import '../models/iou_note.dart';
import '../engine/balance_engine.dart';
import 'app_repository.dart';
import '../models/savings_goal.dart';
import '../models/feedback_report.dart';
import 'persistent_app_repository.dart';
import 'supabase_ledger_repository.dart';

// An in-memory implementation that matches AppRepository for tests and fast mocks
class InMemoryAppRepository extends PersistentAppRepository {
  InMemoryAppRepository({
    super.prefs,
    super.clock,
  });
}

// -----------------------------------------------------------------------------
// Riverpod State Providers
// -----------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  // Can be overridden in main() or tests
  return null;
});

final ledgerSyncStateProvider = StateProvider<LedgerSyncState>((ref) {
  return const LedgerSyncState();
});

class AppStateNotifier extends Notifier<int> {
  late AppRepository repository;
  bool _hadSignedInUser = false;

  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authStatus = ref.watch(authStateProvider);

    if (authStatus is AuthSignedIn) {
      _hadSignedInUser = true;
      if (SupabaseConfig.isSupabaseConfigured && SupabaseConfig.isInitialized) {
        var disposed = false;
        ref.onDispose(() => disposed = true);
        final sbRepo = SupabaseLedgerRepository(
          client: Supabase.instance.client,
          uid: authStatus.user.id,
          prefs: prefs,
          onRemoteChange: () {
            Future.microtask(() {
              if (!disposed) notifyChange();
            });
          },
          onSyncStateChanged: (syncState) {
            Future.microtask(() {
              if (!disposed) {
                ref.read(ledgerSyncStateProvider.notifier).state = syncState;
              }
            });
          },
        );
        repository = sbRepo;
        ref.onDispose(sbRepo.dispose);
        Future.microtask(() => sbRepo.initialize());
      } else {
        repository = PersistentAppRepository(
          prefs: prefs,
          storageKey: 'settliv_ledger_uid_${authStatus.user.id}',
        );
      }
    } else if (authStatus is AuthSignedOut && _hadSignedInUser) {
      // Clear previous user's in-memory state on sign-out
      _hadSignedInUser = false;
      final cleanRepo = PersistentAppRepository(
        prefs: null,
        storageKey: 'settliv_signed_out_empty',
      );
      cleanRepo.startFresh();
      repository = cleanRepo;
    } else {
      // Guest mode or standalone widget tests
      repository = PersistentAppRepository(prefs: prefs);
    }
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

  void updateGroup(Group group) {
    repository.updateGroup(group);
    notifyChange();
  }

  void addPerson(Person person) {
    repository.addPerson(person);
    notifyChange();
  }

  void updatePerson(Person person) {
    repository.updatePerson(person);
    notifyChange();
  }

  void updateCurrentUser({String? name, String? upiId}) {
    repository.updateCurrentUser(name: name, upiId: upiId);
    notifyChange();
  }

  void addRecurringTemplate(RecurringTemplate template) {
    repository.addRecurringTemplate(template);
    notifyChange();
  }

  void updateRecurringTemplate(RecurringTemplate template) {
    repository.updateRecurringTemplate(template);
    notifyChange();
  }

  void deleteRecurringTemplate(String id) {
    repository.deleteRecurringTemplate(id);
    notifyChange();
  }

  void addIouNote(IouNote note) {
    repository.addIouNote(note);
    notifyChange();
  }

  void updateIouNote(IouNote note) {
    repository.updateIouNote(note);
    notifyChange();
  }

  void deleteIouNote(String id) {
    repository.deleteIouNote(id);
    notifyChange();
  }

  void restoreIouNote(String id) {
    repository.restoreIouNote(id);
    notifyChange();
  }

  void recordIouPayment(String noteId, int amountPaise) {
    repository.recordIouPayment(noteId, amountPaise);
    notifyChange();
  }

  void addSavingsGoal(SavingsGoal goal) {
    repository.addSavingsGoal(goal);
    notifyChange();
  }

  void updateSavingsGoal(SavingsGoal goal) {
    repository.updateSavingsGoal(goal);
    notifyChange();
  }

  void deleteSavingsGoal(String id) {
    repository.deleteSavingsGoal(id);
    notifyChange();
  }

  void contributeToSavingsGoal(String id, int amountPaise) {
    repository.contributeToSavingsGoal(id, amountPaise);
    notifyChange();
  }

  void withdrawFromSavingsGoal(String id, int amountPaise) {
    repository.withdrawFromSavingsGoal(id, amountPaise);
    notifyChange();
  }

  void addFeedbackReport(FeedbackReport report) {
    repository.addFeedbackReport(report);
    notifyChange();
  }

  void deleteFeedbackReport(String id) {
    repository.deleteFeedbackReport(id);
    notifyChange();
  }

  int processDueRecurringExpenses({DateTime? asOf}) {
    final generated = repository.processDueRecurringExpenses(asOf: asOf);
    if (generated.isNotEmpty) {
      notifyChange();
    }
    return generated.length;
  }

  String exportLedgerJson() => repository.exportLedgerJson();

  String exportExpensesCsv() => repository.exportExpensesCsv();

  bool restoreFromJson(String jsonString) {
    final ok = repository.restoreFromJson(jsonString);
    if (ok) {
      notifyChange();
    }
    return ok;
  }

  Future<void> startFresh() async {
    await repository.startFresh();
    notifyChange();
  }

  Future<void> resetDemoData() async {
    await repository.resetDemoData();
    notifyChange();
  }

  Future<void> deleteAllData() async {
    await repository.deleteAllData();
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
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return repo.getUserOverallBalance();
});

final currentUserProvider = Provider<Person?>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return repo.currentUser;
});

final allGroupsProvider = Provider<List<Group>>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getGroups());
});

final groupProvider = Provider.family<Group?, String>((ref, groupId) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return repo.getGroup(groupId);
});

final groupSummaryProvider =
    Provider.family<GroupBalanceSummary, String>((ref, groupId) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return repo.getGroupSummary(groupId);
});

final allExpensesProvider = Provider<List<Expense>>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getAllExpenses());
});

final allSettlementsProvider = Provider<List<Settlement>>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getAllSettlements());
});

final groupExpensesProvider =
    Provider.family<List<Expense>, String>((ref, groupId) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getExpensesForGroup(groupId));
});

final allPeopleProvider = Provider<List<Person>>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getPeople());
});

final personProvider = Provider.family<Person?, String>((ref, personId) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return repo.getPerson(personId);
});

final allRecurringTemplatesProvider = Provider<List<RecurringTemplate>>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getRecurringTemplates());
});

final allIouNotesProvider = Provider<List<IouNote>>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getAllIouNotes());
});

final allSavingsGoalsProvider = Provider<List<SavingsGoal>>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getSavingsGoals());
});

final allFeedbackReportsProvider = Provider<List<FeedbackReport>>((ref) {
  ref.watch(appStateProvider);
  final repo = ref.watch(appRepositoryProvider);
  return List.unmodifiable(repo.getFeedbackReports());
});
