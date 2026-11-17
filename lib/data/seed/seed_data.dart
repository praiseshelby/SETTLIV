import '../models/person.dart';
import '../models/group.dart';
import '../models/expense.dart';
import '../models/settlement.dart';

abstract class SeedData {
  static const String currentUserId = 'person_arjun';

  static const Person arjun = Person(
    id: currentUserId,
    name: 'Arjun',
    avatarInitials: 'AR',
    avatarPairIndex: 0, // Navy / Cobalt
  );

  static const Person meera = Person(
    id: 'person_meera',
    name: 'Meera',
    avatarInitials: 'ME',
    avatarPairIndex: 1, // Emerald / Teal
  );

  static const Person kabir = Person(
    id: 'person_kabir',
    name: 'Kabir',
    avatarInitials: 'KA',
    avatarPairIndex: 2, // Coral / Saffron
  );

  static const Person nisha = Person(
    id: 'person_nisha',
    name: 'Nisha',
    avatarInitials: 'NI',
    avatarPairIndex: 3, // Orchid / Cobalt
  );

  static const Person rohan = Person(
    id: 'person_rohan',
    name: 'Rohan',
    avatarInitials: 'RO',
    avatarPairIndex: 4, // Teal / Emerald
  );

  static const Person tara = Person(
    id: 'person_tara',
    name: 'Tara',
    avatarInitials: 'TA',
    avatarPairIndex: 7, // Rose / Coral
  );

  static List<Person> get people => const [
    arjun,
    meera,
    kabir,
    nisha,
    rohan,
    tara,
  ];

  static final DateTime now = DateTime.now();

  static final Group flatmates = Group(
    id: 'group_flatmates',
    name: 'Flatmates',
    type: GroupType.home,
    memberIds: const ['person_arjun', 'person_meera', 'person_kabir'],
    coverType: GroupCoverType.flatmates,
    startDate: now.subtract(const Duration(days: 90)),
  );

  static final Group goaTrip = Group(
    id: 'group_goa',
    name: 'Goa Trip',
    type: GroupType.trip,
    memberIds: const ['person_arjun', 'person_nisha', 'person_rohan', 'person_tara'],
    coverType: GroupCoverType.goaTrip,
    // Spans today: started 2 days ago, ends in 2 days (Day 3 of 5)
    startDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2)),
    endDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 2)),
  );

  static List<Group> get groups => [flatmates, goaTrip];

  static List<Expense> get expenses => [
    // ------------------------------------------------------------------------
    // FLATMATES EXPENSES (14 expenses, yields Arjun = +₹1,240)
    // ------------------------------------------------------------------------
    Expense(
      id: 'exp_fm_1',
      groupId: 'group_flatmates',
      title: 'Apartment rent',
      category: ExpenseCategory.rent,
      amount: 2700000, // ₹27,000
      date: now.subtract(const Duration(days: 16)),
      paidBy: 'person_meera',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 900000,
        'person_meera': 900000,
        'person_kabir': 900000,
      },
    ),
    Expense(
      id: 'exp_fm_2',
      groupId: 'group_flatmates',
      title: 'Wi-Fi fiber',
      category: ExpenseCategory.bills,
      amount: 119900, // ₹1,199
      date: now.subtract(const Duration(days: 14)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.exact,
      shares: const {
        'person_arjun': 39900,
        'person_meera': 40000,
        'person_kabir': 40000,
      },
    ),
    Expense(
      id: 'exp_fm_3',
      groupId: 'group_flatmates',
      title: 'Cook & maid',
      category: ExpenseCategory.bills,
      amount: 450000, // ₹4,500
      date: now.subtract(const Duration(days: 13)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 150000,
        'person_meera': 150000,
        'person_kabir': 150000,
      },
    ),
    Expense(
      id: 'exp_fm_4',
      groupId: 'group_flatmates',
      title: 'Supermarket run',
      category: ExpenseCategory.groceries,
      amount: 246000, // ₹2,460
      date: now.subtract(const Duration(days: 11)),
      paidBy: 'person_kabir',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 82000,
        'person_meera': 82000,
        'person_kabir': 82000,
      },
    ),
    Expense(
      id: 'exp_fm_5',
      groupId: 'group_flatmates',
      title: 'Gas cylinder',
      category: ExpenseCategory.bills,
      amount: 95000, // ₹950
      date: now.subtract(const Duration(days: 10)),
      paidBy: 'person_kabir',
      splitMode: SplitMode.exact,
      shares: const {
        'person_arjun': 35000,
        'person_meera': 30000,
        'person_kabir': 30000,
      },
    ),
    Expense(
      id: 'exp_fm_6',
      groupId: 'group_flatmates',
      title: 'Electricity bill',
      category: ExpenseCategory.bills,
      amount: 186000, // ₹1,860
      date: now.subtract(const Duration(days: 8)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 62000,
        'person_meera': 62000,
        'person_kabir': 62000,
      },
    ),
    Expense(
      id: 'exp_fm_7',
      groupId: 'group_flatmates',
      title: 'Sunday brunch',
      category: ExpenseCategory.food,
      amount: 165000, // ₹1,650
      date: now.subtract(const Duration(days: 7)),
      paidBy: 'person_meera',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 55000,
        'person_meera': 55000,
        'person_kabir': 55000,
      },
    ),
    Expense(
      id: 'exp_fm_8',
      groupId: 'group_flatmates',
      title: 'Water tanker',
      category: ExpenseCategory.bills,
      amount: 120000, // ₹1,200
      date: now.subtract(const Duration(days: 6)),
      paidBy: 'person_kabir',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 40000,
        'person_meera': 40000,
        'person_kabir': 40000,
      },
    ),
    Expense(
      id: 'exp_fm_9',
      groupId: 'group_flatmates',
      title: 'Swiggy snacks',
      category: ExpenseCategory.groceries,
      amount: 68000, // ₹680
      date: now.subtract(const Duration(days: 5)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.exact,
      shares: const {
        'person_arjun': 28000,
        'person_meera': 20000,
        'person_kabir': 20000,
      },
    ),
    Expense(
      id: 'exp_fm_10',
      groupId: 'group_flatmates',
      title: 'Kitchen deep clean',
      category: ExpenseCategory.other,
      amount: 210000, // ₹2,100
      date: now.subtract(const Duration(days: 4)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 70000,
        'person_meera': 70000,
        'person_kabir': 70000,
      },
    ),
    Expense(
      id: 'exp_fm_11',
      groupId: 'group_flatmates',
      title: 'Living room plants',
      category: ExpenseCategory.other,
      amount: 144000, // ₹1,440
      date: now.subtract(const Duration(days: 3)),
      paidBy: 'person_kabir',
      splitMode: SplitMode.percent,
      shares: const {
        'person_arjun': 57600,
        'person_meera': 43200,
        'person_kabir': 43200,
      },
    ),
    Expense(
      id: 'exp_fm_12',
      groupId: 'group_flatmates',
      title: 'Society charges',
      category: ExpenseCategory.bills,
      amount: 750000, // ₹7,500
      date: now.subtract(const Duration(days: 2)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 250000,
        'person_meera': 250000,
        'person_kabir': 250000,
      },
    ),
    Expense(
      id: 'exp_fm_13',
      groupId: 'group_flatmates',
      title: 'House party brew',
      category: ExpenseCategory.fun,
      amount: 282000, // ₹2,820
      date: now.subtract(const Duration(days: 1)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.percent,
      shares: const {
        'person_arjun': 56400,
        'person_meera': 112800,
        'person_kabir': 112800,
      },
    ),
    Expense(
      id: 'exp_fm_14',
      groupId: 'group_flatmates',
      title: 'Kitchen essentials',
      category: ExpenseCategory.other,
      amount: 174000, // ₹1,740
      date: now,
      paidBy: 'person_meera',
      splitMode: SplitMode.exact,
      shares: const {
        'person_arjun': 116000,
        'person_kabir': 58000,
        'person_meera': 0,
      },
    ),

    // ------------------------------------------------------------------------
    // GOA TRIP EXPENSES (11 expenses, yields Arjun = -₹380)
    // ------------------------------------------------------------------------
    Expense(
      id: 'exp_goa_1',
      groupId: 'group_goa',
      title: 'Vagator villa',
      category: ExpenseCategory.stay,
      amount: 2800000, // ₹28,000
      date: now.subtract(const Duration(days: 2, hours: 8)),
      paidBy: 'person_rohan',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 700000,
        'person_nisha': 700000,
        'person_rohan': 700000,
        'person_tara': 700000,
      },
    ),
    Expense(
      id: 'exp_goa_2',
      groupId: 'group_goa',
      title: 'Scooter rental',
      category: ExpenseCategory.travel,
      amount: 480000, // ₹4,800
      date: now.subtract(const Duration(days: 2, hours: 4)),
      paidBy: 'person_nisha',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 120000,
        'person_nisha': 120000,
        'person_rohan': 120000,
        'person_tara': 120000,
      },
    ),
    Expense(
      id: 'exp_goa_3',
      groupId: 'group_goa',
      title: 'Fuel & tolls',
      category: ExpenseCategory.travel,
      amount: 160000, // ₹1,600
      date: now.subtract(const Duration(days: 2, hours: 2)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 40000,
        'person_nisha': 40000,
        'person_rohan': 40000,
        'person_tara': 40000,
      },
    ),
    Expense(
      id: 'exp_goa_4',
      groupId: 'group_goa',
      title: 'Seafood feast',
      category: ExpenseCategory.food,
      amount: 640000, // ₹6,400
      date: now.subtract(const Duration(days: 1, hours: 14)),
      paidBy: 'person_tara',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 160000,
        'person_nisha': 160000,
        'person_rohan': 160000,
        'person_tara': 160000,
      },
    ),
    Expense(
      id: 'exp_goa_5',
      groupId: 'group_goa',
      title: 'Sunset dinner',
      category: ExpenseCategory.food,
      amount: 520000, // ₹5,200
      date: now.subtract(const Duration(days: 1, hours: 10)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 130000,
        'person_nisha': 130000,
        'person_rohan': 130000,
        'person_tara': 130000,
      },
    ),
    Expense(
      id: 'exp_goa_6',
      groupId: 'group_goa',
      title: 'VIP club entry',
      category: ExpenseCategory.fun,
      amount: 800000, // ₹8,000
      date: now.subtract(const Duration(days: 1, hours: 4)),
      paidBy: 'person_rohan',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 200000,
        'person_nisha': 200000,
        'person_rohan': 200000,
        'person_tara': 200000,
      },
    ),
    Expense(
      id: 'exp_goa_7',
      groupId: 'group_goa',
      title: 'Beach shack brunch',
      category: ExpenseCategory.food,
      amount: 188000, // ₹1,880
      date: now.subtract(const Duration(hours: 18)),
      paidBy: 'person_nisha',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 47000,
        'person_nisha': 47000,
        'person_rohan': 47000,
        'person_tara': 47000,
      },
    ),
    Expense(
      id: 'exp_goa_8',
      groupId: 'group_goa',
      title: 'Kayaking & snacks',
      category: ExpenseCategory.fun,
      amount: 440000, // ₹4,400
      date: now.subtract(const Duration(hours: 12)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 110000,
        'person_nisha': 110000,
        'person_rohan': 110000,
        'person_tara': 110000,
      },
    ),
    Expense(
      id: 'exp_goa_9',
      groupId: 'group_goa',
      title: 'Family dinner',
      category: ExpenseCategory.food,
      amount: 216000, // ₹2,160
      date: now.subtract(const Duration(hours: 6)),
      paidBy: 'person_tara',
      splitMode: SplitMode.equal,
      shares: const {
        'person_arjun': 54000,
        'person_nisha': 54000,
        'person_rohan': 54000,
        'person_tara': 54000,
      },
    ),
    Expense(
      id: 'exp_goa_10',
      groupId: 'group_goa',
      title: 'Beach towels & snacks',
      category: ExpenseCategory.groceries,
      amount: 124000, // ₹1,240
      date: now.subtract(const Duration(hours: 3)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.percent,
      shares: const {
        'person_arjun': 31000,
        'person_nisha': 31000,
        'person_rohan': 31000,
        'person_tara': 31000,
      },
    ),
    Expense(
      id: 'exp_goa_11',
      groupId: 'group_goa',
      title: 'Mopa airport cab',
      category: ExpenseCategory.travel,
      amount: 400000, // ₹4,000
      date: now.subtract(const Duration(hours: 1)),
      paidBy: 'person_arjun',
      splitMode: SplitMode.exact,
      shares: const {
        'person_arjun': 90000,
        'person_nisha': 100000,
        'person_rohan': 105000,
        'person_tara': 105000,
      },
    ),
  ];

  static List<Settlement> get settlements => const [];
}
