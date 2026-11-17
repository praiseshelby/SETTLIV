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

  const QuickParseResult({
    this.amountPaise,
    required this.description,
    required this.category,
    required this.participants,
    this.inferredGroup,
    this.payerId,
    required this.isValid,
    this.hint,
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

    // 1. Extract amount
    int? amountPaise;
    String textWithoutAmount = text;

    // Matches formats: ₹800, 1,200, 1200, 1.2k, 1.5k, rs 500, rs. 500
    final amountRegex = RegExp(
      r'(?:₹|rs\.?\s*)?(\d+(?:,\d+)*(?:\.\d+)?\s*[kKlL]?)',
      caseSensitive: false,
    );

    final match = amountRegex.firstMatch(text);
    if (match != null) {
      final matchedStr = match.group(1);
      if (matchedStr != null) {
        amountPaise = CurrencyFormatter.parseToPaise(matchedStr);
        if (amountPaise != null && amountPaise > 0) {
          textWithoutAmount = text.replaceRange(match.start, match.end, ' ');
        }
      }
    }

    // 2. Identify mentioned people
    final Set<String> matchedPersonIds = {currentUser.id};
    final lowerText = text.toLowerCase();

    for (final person in availablePeople) {
      if (person.id == currentUser.id) continue;
      final nameLower = person.name.toLowerCase();
      // Match whole word or preceded by with/and
      final nameRegex = RegExp('\\b$nameLower\\b', caseSensitive: false);
      if (nameRegex.hasMatch(lowerText)) {
        matchedPersonIds.add(person.id);
        // Remove name from description text
        textWithoutAmount = textWithoutAmount.replaceAll(
          RegExp('\\b(?:with|and|for)?\\s*$nameLower\\b', caseSensitive: false),
          ' ',
        );
      }
    }

    // 3. Infer Group
    Group? inferredGroup;
    if (matchedPersonIds.length > 1) {
      // Find a group containing all matched members
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

    // If no specific members were named, split with all group members
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
        .replaceAll(RegExp(r'\b(with|and|for|split|in|at)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (description.isEmpty) {
      description = category.label;
    } else {
      // Capitalize first letter
      description = description[0].toUpperCase() + description.substring(1);
    }

    final bool isValid = amountPaise != null && amountPaise > 0;
    final String? hint = isValid
        ? null
        : (amountPaise == null
            ? 'Add an amount to continue'
            : 'Amount must be greater than zero');

    return QuickParseResult(
      amountPaise: amountPaise,
      description: description,
      category: category,
      participants: participants,
      inferredGroup: inferredGroup,
      payerId: currentUser.id,
      isValid: isValid,
      hint: hint,
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
