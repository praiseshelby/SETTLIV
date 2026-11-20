import '../../../data/models/expense.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../core/utils/currency_formatter.dart';

class QuickParseResult {
  final int? amountPaise;
  final String description;
  final ExpenseCategory category;
  final List<Person> participants; // includes current user + mentioned members
  final Group? inferredGroup;
  final String? payerId;
  final bool isValid;
  final String? hint;
  final bool isAmbiguousAmount;
  final bool isOverCap;
  final List<String> unknownPeople;

  const QuickParseResult({
    this.amountPaise,
    required this.description,
    required this.category,
    required this.participants,
    this.inferredGroup,
    this.payerId,
    required this.isValid,
    this.hint,
    this.isAmbiguousAmount = false,
    this.isOverCap = false,
    this.unknownPeople = const [],
  });
}

class QuickExpenseParser {
  final List<Person> availablePeople;
  final List<Group> availableGroups;
  final Person currentUser;

  const QuickExpenseParser({
    required this.availablePeople,
    required this.availableGroups,
    required this.currentUser,
  });

  QuickParseResult parse(String rawText, {String? defaultGroupId}) {
    final text = rawText.trim();
    if (text.isEmpty) {
      final defaultGroup = _findGroup(defaultGroupId) ??
          (availableGroups.isNotEmpty ? availableGroups.first : null);
      final defaultParticipants = defaultGroup != null
          ? availablePeople
              .where((p) => defaultGroup.memberIds.contains(p.id))
              .toList()
          : [currentUser];

      return QuickParseResult(
        amountPaise: null,
        description: '',
        category: ExpenseCategory.other,
        participants: defaultParticipants,
        inferredGroup: defaultGroup,
        payerId: currentUser.id,
        isValid: false,
        hint: 'e.g. dinner 800 with Meera and Kabir',
      );
    }

    // 1. Extract amount(s)
    // Matches formats: ₹800, 1,200, 1200, 1.2k, 1.5L, 2 lakh, 1cr, 1.5 crore, rs 500, rs. 500
    final amountRegex = RegExp(
      r'(?:₹|rs\.?\s*)?(\d+(?:,\d+)*(?:\.\d+)?\s*(?:cr|crore|lakh|lac|l|k)?)(?!\w)',
      caseSensitive: false,
    );

    final allMatches = amountRegex.allMatches(text).toList();
    final List<({int paise, Match match})> candidateAmounts = [];

    for (final m in allMatches) {
      final matchedStr = m.group(1);
      if (matchedStr == null || matchedStr.trim().isEmpty) continue;
      // Skip pure small integers that could be quantities or counts (e.g. "split 4", "for 2")
      final clean = matchedStr.trim();
      final isPureSmallInt = RegExp(r'^\d+$').hasMatch(clean) &&
          int.tryParse(clean) != null &&
          int.parse(clean) < 10;
      final isPrecededBySplitOrFor = text.substring(0, m.start).trim().toLowerCase().endsWith('split') ||
          text.substring(0, m.start).trim().toLowerCase().endsWith('for');

      if (isPureSmallInt && isPrecededBySplitOrFor) {
        continue;
      }

      final parsed = CurrencyFormatter.parseToPaise(matchedStr);
      if (parsed != null && parsed > 0) {
        candidateAmounts.add((paise: parsed, match: m));
      }
    }

    int? amountPaise;
    String textWithoutAmount = text;
    bool isAmbiguous = false;

    if (candidateAmounts.length == 1) {
      amountPaise = candidateAmounts.first.paise;
      final m = candidateAmounts.first.match;
      textWithoutAmount = text.replaceRange(m.start, m.end, ' ');
    } else if (candidateAmounts.length > 1) {
      // If there are multiple distinct amounts
      final uniqueAmounts = candidateAmounts.map((c) => c.paise).toSet();
      if (uniqueAmounts.length > 1) {
        isAmbiguous = true;
      } else {
        amountPaise = candidateAmounts.first.paise;
        final m = candidateAmounts.first.match;
        textWithoutAmount = text.replaceRange(m.start, m.end, ' ');
      }
    }

    // Check cap
    final bool isOverCap =
        amountPaise != null && amountPaise > CurrencyFormatter.maxAmountPaise;

    // 2. Identify mentioned people & unknown people
    final Set<String> matchedPersonIds = {currentUser.id};
    final List<String> unknownPeople = [];
    final lowerText = text.toLowerCase();

    for (final person in availablePeople) {
      if (person.id == currentUser.id) continue;
      final nameLower = person.name.toLowerCase();
      final nameRegex = RegExp('\\b$nameLower\\b', caseSensitive: false);
      if (nameRegex.hasMatch(lowerText)) {
        matchedPersonIds.add(person.id);
        textWithoutAmount = textWithoutAmount.replaceAll(
          RegExp('\\b(?:with|and|for)?\\s*$nameLower\\b', caseSensitive: false),
          ' ',
        );
      }
    }

    // Check for unknown people after "with" or "and"
    final withMatch = RegExp(r'\b(?:with|and)\s+([A-Za-z]+)\b', caseSensitive: false)
        .allMatches(textWithoutAmount);
    for (final m in withMatch) {
      final potentialName = m.group(1);
      if (potentialName != null) {
        final lower = potentialName.toLowerCase();
        final isKnown = availablePeople
            .any((p) => p.name.toLowerCase() == lower);
        final isCommonWord = const {
          'me', 'all', 'everyone', 'us', 'the', 'split', 'cash', 'upi', 'two',
          'three', 'four', 'five', 'six', 'each', 'both'
        }.contains(lower);
        if (!isKnown && !isCommonWord && !unknownPeople.contains(potentialName)) {
          unknownPeople.add(potentialName);
        }
      }
    }

    // 3. Infer Group
    Group? inferredGroup;
    if (matchedPersonIds.length > 1) {
      for (final g in availableGroups) {
        final containsAll =
            matchedPersonIds.every((id) => g.memberIds.contains(id));
        if (containsAll) {
          inferredGroup = g;
          break;
        }
      }
    }

    inferredGroup ??= _findGroup(defaultGroupId) ??
        (availableGroups.isNotEmpty ? availableGroups.first : null);

    // If no specific members named, split with all group members
    if (matchedPersonIds.length == 1 && inferredGroup != null) {
      matchedPersonIds.addAll(inferredGroup.memberIds);
    }

    final participants = availablePeople
        .where((p) => matchedPersonIds.contains(p.id))
        .toList();

    // 4. Guess Category from keywords
    final category = _guessCategory(lowerText);

    // 5. Clean up description
    String description = textWithoutAmount
        .replaceAll(
            RegExp(r'\b(with|and|for|split|in|at)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (description.isEmpty) {
      description = category.label;
    } else {
      description = description[0].toUpperCase() + description.substring(1);
    }

    final bool isValid = amountPaise != null &&
        amountPaise > 0 &&
        !isOverCap &&
        !isAmbiguous;

    final String? hint;
    if (isOverCap) {
      hint = 'Amount exceeds maximum limit of ₹10,00,00,000';
    } else if (isAmbiguous) {
      hint = 'Multiple amounts found. Please specify a single amount.';
    } else if (amountPaise == null) {
      hint = 'Add an amount to continue';
    } else if (unknownPeople.isNotEmpty) {
      hint = 'Note: "${unknownPeople.first}" was not found in your groups.';
    } else {
      hint = null;
    }

    return QuickParseResult(
      amountPaise: amountPaise,
      description: description,
      category: category,
      participants: participants,
      inferredGroup: inferredGroup,
      payerId: currentUser.id,
      isValid: isValid,
      hint: hint,
      isAmbiguousAmount: isAmbiguous,
      isOverCap: isOverCap,
      unknownPeople: unknownPeople,
    );
  }

  Group? _findGroup(String? groupId) {
    if (groupId == null) return null;
    try {
      return availableGroups.firstWhere((g) => g.id == groupId);
    } catch (_) {
      return null;
    }
  }

  ExpenseCategory _guessCategory(String text) {
    if (RegExp(r'\b(dinner|lunch|brunch|food|breakfast|thali|cafe|coffee|swiggy|zomato|pizza|burger|snack|meals?)\b')
        .hasMatch(text)) {
      return ExpenseCategory.food;
    }
    if (RegExp(r'\b(rent|deposit|flat|apartment|maintenance|society)\b')
        .hasMatch(text)) {
      return ExpenseCategory.rent;
    }
    if (RegExp(r'\b(cab|uber|ola|auto|travel|petrol|diesel|fuel|flight|taxi|scooters?|activa|bike|bus|train|fastag)\b')
        .hasMatch(text)) {
      return ExpenseCategory.travel;
    }
    if (RegExp(r'\b(hotel|stay|villa|resort|airbnb|room|hostel|lodge)\b')
        .hasMatch(text)) {
      return ExpenseCategory.stay;
    }
    if (RegExp(r'\b(wifi|electricity|gas|bill|bescom|water|cylinder|recharge|broadband|airtel|jio)\b')
        .hasMatch(text)) {
      return ExpenseCategory.bills;
    }
    if (RegExp(r'\b(grocer|veg|vegetables|supermarket|fruits|bigbasket|instamart|zepto|blinkit|milk|provisions)\b')
        .hasMatch(text)) {
      return ExpenseCategory.groceries;
    }
    if (RegExp(r'\b(movie|club|party|beer|cocktails?|pub|bar|drinks?|cinema|water sports|kayak|gaming)\b')
        .hasMatch(text)) {
      return ExpenseCategory.fun;
    }
    return ExpenseCategory.other;
  }
}
