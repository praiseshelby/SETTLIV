import '../models/person.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import '../models/recurring_template.dart';
import '../models/iou_note.dart';
import '../engine/balance_engine.dart';

abstract class AppRepository {
  String get currentUserId;
  Person? get currentUser;
  void updateCurrentUser({String? name, String? upiId});

  List<Person> getPeople();
  Person? getPerson(String id);
  void addPerson(Person person);
  void updatePerson(Person person);

  List<Group> getGroups();
  Group? getGroup(String id);
  void addGroup(Group group);
  void updateGroup(Group group);

  List<Expense> getAllExpenses();
  List<Expense> getExpensesForGroup(String groupId);
  Expense? getExpense(String id);
  void addExpense(Expense expense);
  void updateExpense(Expense expense);
  void deleteExpense(String id); // soft delete
  void restoreExpense(String id); // undo delete
  void removeExpensePermanently(String id);

  List<Settlement> getAllSettlements();
  List<Settlement> getSettlementsForGroup(String groupId);
  void addSettlement(Settlement settlement);
  void deleteSettlement(String id); // for undo

  List<IouNote> getAllIouNotes();
  IouNote? getIouNote(String id);
  void addIouNote(IouNote note);
  void updateIouNote(IouNote note);
  void deleteIouNote(String id); // soft delete
  void restoreIouNote(String id); // undo delete
  void recordIouPayment(String noteId, int amountPaise);

  List<RecurringTemplate> getRecurringTemplates();
  void addRecurringTemplate(RecurringTemplate template);
  void updateRecurringTemplate(RecurringTemplate template);
  void deleteRecurringTemplate(String id);
  List<Expense> processDueRecurringExpenses({DateTime? asOf});

  String exportLedgerJson();
  String exportExpensesCsv();
  bool restoreFromJson(String jsonString);

  GroupBalanceSummary getGroupSummary(String groupId);
  UserOverallBalance getUserOverallBalance();

  Future<void> startFresh();
  Future<void> resetDemoData();
  Future<void> deleteAllData();
  bool get wasCorruptDataRecovered;
  DateTime Function() get clock;
}
