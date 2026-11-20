import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/category_badge.dart';
import '../../../core/widgets/coming_soon_tag.dart';
import '../../../core/widgets/glass_chip.dart';
import '../../../core/widgets/glass_segmented.dart';
import '../../../core/widgets/glass_sheet_scaffold.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/gradient_primary_button.dart';
import '../../../core/widgets/member_chip.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/engine/split_calculator.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../logic/quick_expense_parser.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Expense? initialExpense;
  final String? initialText;
  final String? preselectedGroupId;
  final int initialTabIndex;

  const AddExpenseScreen({
    super.key,
    this.initialExpense,
    this.initialText,
    this.preselectedGroupId,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late int _selectedTab;

  // Quick Tab state
  late final TextEditingController _quickTextController;
  late final FocusNode _quickFocusNode;

  // Manual Tab state
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final FocusNode _amountFocusNode;

  late ExpenseCategory _selectedCategory;
  late String _selectedGroupId;
  late DateTime _selectedDate;
  late String _paidById;
  late Set<String> _selectedMemberIds;
  late SplitMode _splitMode;

  // Custom shares for Exact and Percent modes
  final Map<String, TextEditingController> _exactControllers = {};
  final Map<String, TextEditingController> _percentControllers = {};

  bool _isSaving = false;
  bool _showSavedSuccess = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialExpense != null ? 1 : widget.initialTabIndex;

    _quickTextController = TextEditingController(text: widget.initialText ?? '');
    _quickFocusNode = FocusNode();

    final exp = widget.initialExpense;
    if (exp != null) {
      final rupeePart = exp.amount ~/ 100;
      final frac = exp.amount % 100;
      final amountStr = frac > 0
          ? '$rupeePart.${frac.toString().padLeft(2, '0')}'
          : rupeePart.toString();

      _amountController = TextEditingController(text: amountStr);
      _descriptionController = TextEditingController(text: exp.title);
      _selectedCategory = exp.category;
      _selectedGroupId = exp.groupId;
      _selectedDate = exp.date;
      _paidById = exp.paidBy;
      _selectedMemberIds = exp.shares.keys.toSet();
      _splitMode = exp.splitMode;

      if (_splitMode == SplitMode.exact) {
        exp.shares.forEach((personId, paise) {
          _exactControllers[personId] =
              TextEditingController(text: (paise ~/ 100).toString());
        });
      } else if (_splitMode == SplitMode.percent) {
        exp.shares.forEach((personId, paise) {
          final pct = exp.amount > 0 ? (paise * 100) ~/ exp.amount : 0;
          _percentControllers[personId] =
              TextEditingController(text: pct.toString());
        });
      }
    } else {
      _amountController = TextEditingController();
      _descriptionController = TextEditingController();
      _selectedCategory = ExpenseCategory.food;
      _selectedGroupId = widget.preselectedGroupId ?? 'group_flatmates';
      _selectedDate = DateTime.now();
      _paidById = 'person_arjun';
      _selectedMemberIds = _selectedGroupId == 'group_flatmates'
          ? {'person_arjun', 'person_meera', 'person_kabir'}
          : {'person_arjun', 'person_nisha', 'person_rohan', 'person_tara'};
      _splitMode = SplitMode.equal;
      _rebuildSplitControllers();
    }

    _amountFocusNode = FocusNode();
  }

  void _rebuildSplitControllers() {
    for (final memberId in _selectedMemberIds) {
      _exactControllers.putIfAbsent(
        memberId,
        () => TextEditingController(text: '0'),
      );
      _percentControllers.putIfAbsent(
        memberId,
        () => TextEditingController(
          text: (_selectedMemberIds.isNotEmpty
                  ? (100 ~/ _selectedMemberIds.length)
                  : 0)
              .toString(),
        ),
      );
    }
  }

  void _initMembersForGroup() {
    if (_selectedGroupId == 'group_flatmates') {
      _selectedMemberIds = {'person_arjun', 'person_meera', 'person_kabir'};
    } else {
      _selectedMemberIds = {
        'person_arjun',
        'person_nisha',
        'person_rohan',
        'person_tara',
      };
    }
    _rebuildSplitControllers();
  }

  @override
  void dispose() {
    _quickTextController.dispose();
    _quickFocusNode.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _switchToManualPrefilled(QuickParseResult result) {
    if (result.amountPaise != null) {
      final rupeePart = result.amountPaise! ~/ 100;
      final frac = result.amountPaise! % 100;
      _amountController.text = frac > 0
          ? '$rupeePart.${frac.toString().padLeft(2, '0')}'
          : rupeePart.toString();
    }
    _descriptionController.text = result.description;
    _selectedCategory = result.category;
    if (result.inferredGroup != null) {
      _selectedGroupId = result.inferredGroup!.id;
    }
    _selectedMemberIds = result.participants.map((p) => p.id).toSet();
    _paidById = result.payerId ?? 'person_arjun';
    _splitMode = SplitMode.equal;
    _rebuildSplitControllers();

    setState(() => _selectedTab = 1);
    _amountFocusNode.requestFocus();
  }

  Future<void> _saveExpense(Expense expense) async {
    setState(() {
      _isSaving = true;
      _showSavedSuccess = true;
    });

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final repoNotifier = ref.read(appStateProvider.notifier);
    if (widget.initialExpense != null) {
      repoNotifier.updateExpense(expense);
    } else {
      repoNotifier.addExpense(expense);
    }

    if (mounted) {
      context.pop(expense.id); // Return saved expense ID for highlighting
      UndoSnackbar.show(
        context: context,
        message:
            'Added ${CurrencyFormatter.formatPaise(expense.amount, absolute: true)}',
        onUndo: () {
          if (widget.initialExpense != null) {
            repoNotifier.updateExpense(widget.initialExpense!);
          } else {
            repoNotifier.deleteExpense(expense.id);
          }
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final groups = ref.watch(allGroupsProvider);
    final people = ref.watch(allPeopleProvider);
    final currentGroup = groups.firstWhere(
      (g) => g.id == _selectedGroupId,
      orElse: () => groups.first,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar: Glass circular close button + "New expense" title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Close',
                      child: GlassSurface(
                        level: GlassLevel.level1,
                        borderRadius: 999,
                        padding: const EdgeInsets.all(8),
                        onTap: () => context.pop(),
                        child: Icon(
                          Icons.close_rounded,
                          color: theme.ink,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      widget.initialExpense != null
                          ? 'Edit expense'
                          : 'New expense',
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // GlassSegmented: Quick | Manual
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: GlassSegmented<int>(
                  values: const [0, 1],
                  labels: const ['Quick', 'Manual'],
                  selectedValue: _selectedTab,
                  onValueChanged: (idx) {
                    setState(() => _selectedTab = idx);
                    if (idx == 0) {
                      _quickFocusNode.requestFocus();
                    } else {
                      _amountFocusNode.requestFocus();
                    }
                  },
                ),
              ),

              // Tab Body with Sticky Glass Bottom Bar
              Expanded(
                child: _selectedTab == 0
                    ? _buildQuickTab(people, groups)
                    : _buildManualTab(people, groups, currentGroup),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. QUICK TAB
  // ---------------------------------------------------------------------------

  Widget _buildQuickTab(List<Person> people, List<Group> groups) {
    final theme = context.settliv;
    final isDark = context.isDarkMode;
    final parser = QuickExpenseParser(
      availablePeople: people,
      availableGroups: groups,
      currentUser: people.firstWhere((p) => p.id == 'person_arjun'),
    );

    final parseResult = parser.parse(
      _quickTextController.text,
      defaultGroupId: _selectedGroupId,
    );

    final bool hasValidExpense =
        parseResult.isValid && parseResult.amountPaise != null;

    final String bottomCaption = hasValidExpense
        ? 'Tap confirm to add to ${parseResult.inferredGroup?.name ?? "your group"}'
        : 'Type an expense to continue';

    final String ctaLabel = hasValidExpense
        ? 'Confirm · ${CurrencyFormatter.formatPaise(parseResult.amountPaise!, absolute: true)} with ${parseResult.participants.length} people'
        : 'Add expense';

    return Stack(
      children: [
        // Scrollable content with bottom clearance padding (140px)
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 150),
          children: [
            // Composer Card (Glass level 2, min height 140)
            GlassSurface(
              level: GlassLevel.level2,
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHAT DID YOU SPEND ON?',
                    style: AppTypography.sectionLabel.copyWith(
                      color: theme.secondary,
                      letterSpacing: 0.8,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 80),
                    child: TextField(
                      controller: _quickTextController,
                      focusNode: _quickFocusNode,
                      maxLines: 4,
                      minLines: 2,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. dinner 800 with Meera and Kabir',
                        hintStyle: AppTypography.titleLarge.copyWith(
                          color: theme.tertiary.withValues(alpha: 0.6),
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.3,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // "Try one of these" label + 4 example chips
            Text(
              'TRY ONE OF THESE',
              style: AppTypography.sectionLabel.copyWith(
                color: theme.secondary,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  GlassChip(
                    label: 'Dinner 800 with Meera and Kabir',
                    onTap: () {
                      _quickTextController.text =
                          'dinner 800 with Meera and Kabir';
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: 'Rent 18,000',
                    onTap: () {
                      _quickTextController.text = 'Rent 18,000';
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: 'Cab 240 with Kabir',
                    onTap: () {
                      _quickTextController.text = 'Cab 240 with Kabir';
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  GlassChip(
                    label: 'Groceries 1,250',
                    onTap: () {
                      _quickTextController.text = 'Groceries 1,250';
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Calm three-icon hint row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0x14FFFFFF)
                    : Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x40FFFFFF),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.sapphire, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Amount, people and category are picked up automatically.',
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Draft Card when parsed
            if (hasValidExpense) ...[
              _buildLiveDraftCard(parseResult),
            ] else if (parseResult.hint != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.amberTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 18,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        parseResult.hint!,
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? const Color(0xFFFFD580)
                              : const Color(0xFF8F5D00),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        // Sticky GLASS bottom bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GlassSurface(
            level: GlassLevel.level3,
            borderRadius: 0,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bottomCaption,
                  style: AppTypography.caption.copyWith(
                    color: hasValidExpense
                        ? theme.secondary
                        : AppColors.coral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                GradientPrimaryButton(
                  label: _showSavedSuccess ? 'Saved!' : ctaLabel,
                  isLoading: _isSaving && !_showSavedSuccess,
                  icon: _showSavedSuccess
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 20)
                      : null,
                  onPressed: (!hasValidExpense || _isSaving)
                      ? null
                      : () {
                          final int memberCount =
                              parseResult.participants.length;
                          final perPersonPaise =
                              parseResult.amountPaise! ~/ memberCount;
                          final Map<String, int> shares = {};
                          int remaining = parseResult.amountPaise!;
                          for (int i = 0; i < parseResult.participants.length; i++) {
                            final p = parseResult.participants[i];
                            if (i == parseResult.participants.length - 1) {
                              shares[p.id] = remaining;
                            } else {
                              shares[p.id] = perPersonPaise;
                              remaining -= perPersonPaise;
                            }
                          }

                          final newExp = Expense(
                            id: widget.initialExpense?.id ??
                                'exp_${DateTime.now().millisecondsSinceEpoch}',
                            groupId: parseResult.inferredGroup?.id ??
                                _selectedGroupId,
                            title: parseResult.description,
                            category: parseResult.category,
                            amount: parseResult.amountPaise!,
                            date: DateTime.now(),
                            paidBy: parseResult.payerId ?? 'person_arjun',
                            splitMode: SplitMode.equal,
                            shares: shares,
                          );
                          _saveExpense(newExp);
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveDraftCard(QuickParseResult result) {
    final theme = context.settliv;
    final int memberCount = result.participants.length;
    final perPersonPaise = result.amountPaise! ~/ memberCount;

    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryTile(category: result.category, size: 44, iconSize: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.description,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${result.inferredGroup?.name ?? 'Group'} · Split equally',
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatPaise(result.amountPaise!,
                    absolute: true),
                style: AppTypography.displayMoney.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: theme.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.hairline),
          const SizedBox(height: 12),
          Text(
            'Split with $memberCount people · ~${CurrencyFormatter.formatPaise(perPersonPaise, absolute: true)} each:',
            style: AppTypography.caption.copyWith(
              color: theme.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final p in result.participants)
                MemberChip(
                  person: p,
                  isSelected: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton.icon(
              onPressed: () => _switchToManualPrefilled(result),
              icon: const Icon(Icons.tune_rounded,
                  size: 16, color: AppColors.sapphire),
              label: const Text(
                'Edit details in Manual',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: AppColors.sapphire,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. MANUAL TAB
  // ---------------------------------------------------------------------------

  Widget _buildManualTab(
    List<Person> people,
    List<Group> groups,
    Group currentGroup,
  ) {
    final theme = context.settliv;

    // Parse current entered amount
    final int? enteredPaise =
        CurrencyFormatter.parseToPaise(_amountController.text);
    final int amountPaise = enteredPaise ?? 0;

    // Validate shares based on split mode
    final validation = _validateManualSplit(amountPaise);

    final String buttonLabel;
    if (widget.initialExpense != null) {
      buttonLabel =
          'Update ${CurrencyFormatter.formatPaise(amountPaise, absolute: true)}';
    } else {
      buttonLabel =
          'Save ${CurrencyFormatter.formatPaise(amountPaise, absolute: true)} · split with ${_selectedMemberIds.length} people';
    }

    final payer = people.firstWhere(
      (p) => p.id == _paidById,
      orElse: () => people.first,
    );

    return Stack(
      children: [
        // Scrollable content with bottom clearance padding (160px)
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
          children: [
            // 1. Amount hero, centred: attached ₹ prefix with 56/700 number & dimmed 0
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '₹',
                      style: AppTypography.titleLarge.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: theme.secondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IntrinsicWidth(
                      child: TextField(
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: AppTypography.heroMoney.copyWith(
                          fontSize: 52,
                          color: theme.ink,
                          letterSpacing: -1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: AppTypography.heroMoney.copyWith(
                            fontSize: 52,
                            color: theme.tertiary.withValues(alpha: 0.35),
                            letterSpacing: -1.5,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Description as single glass input
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _descriptionController,
                style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                decoration: InputDecoration(
                  hintText: 'What was this expense for?',
                  hintStyle:
                      AppTypography.body.copyWith(color: theme.tertiary),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 18),

            // Categories: 4x2 grid of CategoryTiles with 11px labels (no clipping!)
            Text(
              'CATEGORY',
              style: AppTypography.sectionLabel.copyWith(
                color: theme.secondary,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            _buildCategoryGrid(),
            const SizedBox(height: 20),

            // 3. Compact Group selector + Date & Paid by tiles
            Text(
              'GROUP',
              style: AppTypography.sectionLabel.copyWith(
                color: theme.secondary,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            GlassSegmented<String>(
              values: groups.map((g) => g.id).toList(),
              labels: groups.map((g) => g.name).toList(),
              selectedValue: _selectedGroupId,
              onValueChanged: (newId) {
                if (_selectedGroupId != newId) {
                  setState(() {
                    _selectedGroupId = newId;
                    _initMembersForGroup();
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            // Date & Paid by Row
            Row(
              children: [
                // Date Tile
                Expanded(
                  child: GlassSurface(
                    level: GlassLevel.level1,
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    onTap: () => _openDatePickerSheet(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATE',
                          style: AppTypography.sectionLabel.copyWith(
                            color: theme.secondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormatter.formatShort(_selectedDate),
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Paid By Tile
                Expanded(
                  child: GlassSurface(
                    level: GlassLevel.level1,
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    onTap: () => _openPaidBySheet(people, currentGroup),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PAID BY',
                          style: AppTypography.sectionLabel.copyWith(
                            color: theme.secondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            PersonAvatar(person: payer, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                payer.id == 'person_arjun'
                                    ? 'You'
                                    : payer.name,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // "Split between" header with quiet "Clear" / "All" toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SPLIT BETWEEN (${_selectedMemberIds.length} PEOPLE)',
                  style: AppTypography.sectionLabel.copyWith(
                    color: theme.secondary,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedMemberIds.length ==
                          currentGroup.memberIds.length) {
                        _selectedMemberIds = {'person_arjun'};
                      } else {
                        _selectedMemberIds = currentGroup.memberIds.toSet();
                      }
                      _rebuildSplitControllers();
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      _selectedMemberIds.length == currentGroup.memberIds.length
                          ? 'Clear'
                          : 'All',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.sapphire,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final memberId in currentGroup.memberIds) ...[
                  Builder(builder: (context) {
                    final p = people.firstWhere((m) => m.id == memberId);
                    final isSelected = _selectedMemberIds.contains(memberId);
                    return MemberChip(
                      person: p,
                      isSelected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedMemberIds.add(memberId);
                          } else {
                            if (_selectedMemberIds.length > 1) {
                              _selectedMemberIds.remove(memberId);
                            }
                          }
                          _rebuildSplitControllers();
                        });
                      },
                    );
                  }),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Equal / Exact / Percent Segmented Control
            GlassSegmented<int>(
              values: const [0, 1, 2],
              labels: const ['Equal', 'Exact', 'Percent'],
              selectedValue: _splitMode.index,
              onValueChanged: (idx) {
                setState(() => _splitMode = SplitMode.values[idx]);
              },
            ),
            const SizedBox(height: 14),

            // Live per-person list in a glass card beneath
            _buildSplitModeContent(people, amountPaise),
            const SizedBox(height: 20),

            // Receipt scanning ComingSoonTag
            const Center(
              child: ComingSoonTag(
                label: 'Scan receipt · full app',
                featureDescription:
                    'Automated OCR scans receipt items, calculates GST/tip, and splits shares among flatmates.',
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),

        // Sticky GLASS bottom bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GlassSurface(
            level: GlassLevel.level3,
            borderRadius: 0,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (validation.errorMessage != null) ...[
                  Text(
                    validation.errorMessage!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.coral,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                GradientPrimaryButton(
                  label: _showSavedSuccess ? 'Saved!' : buttonLabel,
                  isLoading: _isSaving && !_showSavedSuccess,
                  icon: _showSavedSuccess
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 20)
                      : null,
                  onPressed: (validation.isValid && !_isSaving)
                      ? () {
                          final shares = _computeFinalShares(amountPaise);
                          final newExp = Expense(
                            id: widget.initialExpense?.id ??
                                'exp_${DateTime.now().millisecondsSinceEpoch}',
                            groupId: _selectedGroupId,
                            title: _descriptionController.text.trim().isEmpty
                                ? _selectedCategory.label
                                : _descriptionController.text.trim(),
                            category: _selectedCategory,
                            amount: amountPaise,
                            date: _selectedDate,
                            paidBy: _paidById,
                            splitMode: _splitMode,
                            shares: shares,
                          );
                          _saveExpense(newExp);
                        }
                      : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final theme = context.settliv;
    final categories = ExpenseCategory.values;

    return GlassSurface(
      level: GlassLevel.level1,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          // Row 1: Food, Rent, Travel, Stay
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < 4; i++)
                _buildCategoryGridItem(categories[i], theme),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Groceries, Bills, Fun, Other
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 4; i < 8; i++)
                _buildCategoryGridItem(categories[i], theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGridItem(ExpenseCategory cat, SettlivThemeExtension theme) {
    final isSelected = _selectedCategory == cat;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = cat),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sapphireGradient.colors.first.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: AppColors.sapphire, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CategoryTile(
              category: cat,
              size: 38,
              iconSize: 18,
            ),
            const SizedBox(height: 4),
            Text(
              cat.label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? theme.ink : theme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitModeContent(List<Person> people, int totalPaise) {
    final theme = context.settliv;

    if (_splitMode == SplitMode.equal) {
      final int count = _selectedMemberIds.length;
      final int perPersonPaise = count > 0 ? totalPaise ~/ count : 0;
      return GlassSurface(
        level: GlassLevel.level1,
        borderRadius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Per person share',
              style: AppTypography.body.copyWith(color: theme.secondary),
            ),
            Text(
              CurrencyFormatter.formatPaise(perPersonPaise, absolute: true),
              style: AppTypography.bodyMedium.copyWith(
                color: theme.ink,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    if (_splitMode == SplitMode.exact) {
      int assignedPaise = 0;
      for (final id in _selectedMemberIds) {
        final text = _exactControllers[id]?.text ?? '';
        final val = CurrencyFormatter.parseToPaise(text) ?? 0;
        assignedPaise += val;
      }
      final remainingPaise = totalPaise - assignedPaise;

      return GlassSurface(
        level: GlassLevel.level1,
        borderRadius: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXACT AMOUNTS IN ₹',
                  style: AppTypography.sectionLabel.copyWith(
                    color: theme.secondary,
                    fontSize: 11,
                  ),
                ),
                Text(
                  remainingPaise == 0
                      ? '₹0 left to assign'
                      : '${CurrencyFormatter.formatPaise(remainingPaise.abs(), absolute: true)} ${remainingPaise > 0 ? "left to assign" : "over assigned"}',
                  style: AppTypography.caption.copyWith(
                    color: remainingPaise == 0
                        ? AppColors.emerald
                        : AppColors.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final memberId in _selectedMemberIds) ...[
              Builder(builder: (context) {
                final p = people.firstWhere((m) => m.id == memberId);
                final controller = _exactControllers[memberId];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      PersonAvatar(person: p, size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          p.name,
                          style: AppTypography.bodyMedium
                              .copyWith(color: theme.ink),
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        height: 40,
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textAlign: TextAlign.right,
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            prefixText: '₹',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            filled: true,
                            fillColor: theme.raised,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: theme.hairline),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      );
    }

    // SplitMode.percent
    int totalPct = 0;
    for (final id in _selectedMemberIds) {
      final text = _percentControllers[id]?.text ?? '';
      totalPct += int.tryParse(text) ?? 0;
    }

    return GlassSurface(
      level: GlassLevel.level1,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PERCENTAGE SHARES',
                style: AppTypography.sectionLabel.copyWith(
                  color: theme.secondary,
                  fontSize: 11,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalPct == 100
                      ? AppColors.emeraldTint
                      : AppColors.coralTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  totalPct == 100
                      ? '100% assigned'
                      : '${100 - totalPct}% left to assign',
                  style: AppTypography.caption.copyWith(
                    color: totalPct == 100
                        ? AppColors.emerald
                        : AppColors.coral,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final memberId in _selectedMemberIds) ...[
            Builder(builder: (context) {
              final p = people.firstWhere((m) => m.id == memberId);
              final controller = _percentControllers[memberId];
              final pct = int.tryParse(controller?.text ?? '') ?? 0;
              final approxPaise = (totalPaise * pct) ~/ 100;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    PersonAvatar(person: p, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: AppTypography.bodyMedium
                                .copyWith(color: theme.ink),
                          ),
                          Text(
                            CurrencyFormatter.formatPaise(approxPaise,
                                absolute: true),
                            style: AppTypography.caption
                                .copyWith(color: theme.secondary),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      height: 40,
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          suffixText: '%',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          filled: true,
                          fillColor: theme.raised,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: theme.hairline),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Validation & Share Calculations
  // ---------------------------------------------------------------------------

  ({bool isValid, String? errorMessage}) _validateManualSplit(int totalPaise) {
    if (totalPaise <= 0) {
      return (isValid: false, errorMessage: 'Add an amount to continue');
    }
    if (_selectedMemberIds.isEmpty) {
      return (
        isValid: false,
        errorMessage: 'Select at least one person to split with'
      );
    }

    if (_splitMode == SplitMode.exact) {
      int assigned = 0;
      for (final id in _selectedMemberIds) {
        assigned +=
            CurrencyFormatter.parseToPaise(_exactControllers[id]?.text ?? '') ??
                0;
      }
      final diff = totalPaise - assigned;
      if (diff != 0) {
        final formatted =
            CurrencyFormatter.formatPaise(diff.abs(), absolute: true);
        return (
          isValid: false,
          errorMessage: diff > 0 ? '$formatted left to assign' : '$formatted over assigned'
        );
      }
    }

    if (_splitMode == SplitMode.percent) {
      int totalPct = 0;
      for (final id in _selectedMemberIds) {
        totalPct += int.tryParse(_percentControllers[id]?.text ?? '') ?? 0;
      }
      if (totalPct != 100) {
        return (
          isValid: false,
          errorMessage: totalPct < 100
              ? '${100 - totalPct}% left to assign'
              : '${totalPct - 100}% over assigned'
        );
      }
    }

    return (isValid: true, errorMessage: null);
  }

  Map<String, int> _computeFinalShares(int totalPaise) {
    final paidBy = _paidById;
    if (_splitMode == SplitMode.equal) {
      return SplitCalculator.splitEqual(
        totalPaise: totalPaise,
        memberIds: _selectedMemberIds.toList(),
        paidBy: paidBy,
      );
    } else if (_splitMode == SplitMode.exact) {
      final Map<String, int> exactMap = {};
      for (final id in _selectedMemberIds) {
        exactMap[id] =
            CurrencyFormatter.parseToPaise(_exactControllers[id]?.text ?? '') ??
                0;
      }
      return SplitCalculator.validateExact(
        totalPaise: totalPaise,
        memberIds: _selectedMemberIds.toList(),
        exactShares: exactMap,
      ).shares;
    } else if (_splitMode == SplitMode.percent) {
      final Map<String, double> pctMap = {};
      for (final id in _selectedMemberIds) {
        pctMap[id] =
            double.tryParse(_percentControllers[id]?.text ?? '') ?? 0.0;
      }
      return SplitCalculator.splitPercent(
        totalPaise: totalPaise,
        memberIds: _selectedMemberIds.toList(),
        percentages: pctMap,
        paidBy: paidBy,
      );
    }

    return {};
  }

  // ---------------------------------------------------------------------------
  // Date and Paid By Pickers (GlassSheetScaffold)
  // ---------------------------------------------------------------------------

  void _openDatePickerSheet() {
    final now = DateTime.now();
    final dates = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
    );

    GlassSheetScaffold.show(
      context: context,
      title: 'Select Date',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in dates) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                DateFormatter.formatDayHeader(d),
                style: AppTypography.bodyMedium
                    .copyWith(color: context.settliv.ink),
              ),
              subtitle: Text(
                DateFormatter.formatFull(d),
                style: AppTypography.caption
                    .copyWith(color: context.settliv.secondary),
              ),
              trailing: d.day == _selectedDate.day &&
                      d.month == _selectedDate.month &&
                      d.year == _selectedDate.year
                  ? const Icon(Icons.check_rounded, color: AppColors.emerald)
                  : null,
              onTap: () {
                setState(() => _selectedDate = d);
                Navigator.of(context).pop();
              },
            ),
            if (d != dates.last) Divider(height: 1, color: context.settliv.hairline),
          ],
        ],
      ),
    );
  }

  void _openPaidBySheet(List<Person> people, Group group) {
    final groupMembers =
        people.where((p) => group.memberIds.contains(p.id)).toList();

    GlassSheetScaffold.show(
      context: context,
      title: 'Paid By',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in groupMembers) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: PersonAvatar(person: m, size: 36),
              title: Text(
                m.id == 'person_arjun' ? 'You (${m.name})' : m.name,
                style: AppTypography.bodyMedium
                    .copyWith(color: context.settliv.ink),
              ),
              trailing: m.id == _paidById
                  ? const Icon(Icons.check_rounded, color: AppColors.emerald)
                  : null,
              onTap: () {
                setState(() => _paidById = m.id);
                Navigator.of(context).pop();
              },
            ),
            if (m != groupMembers.last)
              Divider(height: 1, color: context.settliv.hairline),
          ],
        ],
      ),
    );
  }
}
