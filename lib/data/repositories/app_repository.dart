import '../models/person.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/settlement.dart';
import '../engine/balance_engine.dart';

abstract class AppRepository {
  String get currentUserId;
  Person? get currentUser;
  List<Person> getPeople();
  Person? getPerson(String id);

  List<Group> getGroups();
  Group? getGroup(String id);

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

  GroupBalanceSummary getGroupSummary(String groupId);
  UserOverallBalance getUserOverallBalance();
}
