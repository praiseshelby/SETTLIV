import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/category_badge.dart';
import '../../../core/widgets/coming_soon_tag.dart';
import '../../../core/widgets/member_chip.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/segmented_tabs.dart';
import '../../../core/widgets/sheet_scaffold.dart';
import '../../../core/widgets/text_action_button.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
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

  // Custom shares for Exact and Percent modes: personId -> raw string input
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
          final pct = ((paise / exp.amount) * 100).round();
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
      _selectedMemberIds = {};
      _splitMode = SplitMode.equal;
    }

    _amountFocusNode = FocusNode();

    // Auto-focus quick tab input on open if on quick tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initMembersForGroup();
      if (_selectedTab == 0 && widget.initialExpense == null) {
        _quickFocusNode.requestFocus();
      }
    });
  }

  void _initMembersForGroup() {
    final groups = ref.read(allGroupsProvider);
    final currentGroup = groups.firstWhere(
      (g) => g.id == _selectedGroupId,
      orElse: () => groups.first,
    );

    if (widget.initialExpense == null ||
        _selectedGroupId != widget.initialExpense!.groupId) {
      setState(() {
        _selectedMemberIds = currentGroup.memberIds.toSet();
        _rebuildSplitControllers();
      });
    }
  }

  void _rebuildSplitControllers() {
    for (final memberId in _selectedMemberIds) {
      _exactControllers.putIfAbsent(
        memberId,
        () => TextEditingController(text: ''),
      );
      _percentControllers.putIfAbsent(
        memberId,
        () => TextEditingController(text: ''),
      );
    }
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

  void _switchToManualPrefilled(QuickParseResult parseResult) {
    setState(() {
      _selectedTab = 1;
      if (parseResult.amountPaise != null) {
        final r = parseResult.amountPaise! ~/ 100;
        final f = parseResult.amountPaise! % 100;
        _amountController.text =
            f > 0 ? '$r.${f.toString().padLeft(2, '0')}' : r.toString();
      }
      _descriptionController.text = parseResult.description;
      _selectedCategory = parseResult.category;
      if (parseResult.inferredGroup != null) {
        _selectedGroupId = parseResult.inferredGroup!.id;
      }
      _selectedMemberIds = parseResult.participants.map((p) => p.id).toSet();
      _splitMode = SplitMode.equal;
      _rebuildSplitControllers();
    });
  }

  Future<void> _saveExpense(Expense expense) async {
    setState(() {
      _isSaving = true;
      _showSavedSuccess = true;
    });

    // Morph button to emerald check for 600ms
    await Future.delayed(const Duration(milliseconds: 600));
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
      backgroundColor: theme.canvas,
      appBar: AppBar(
        backgroundColor: theme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.ink),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.initialExpense != null ? 'Edit expense' : 'Add expense',
          style: AppTypography.titleLarge.copyWith(color: theme.ink),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: SegmentedTabs(
                labels: const ['Quick', 'Manual'],
                selectedIndex: _selectedTab,
                onTabSelected: (idx) {
                  setState(() => _selectedTab = idx);
                  if (idx == 0) {
                    _quickFocusNode.requestFocus();
                  } else {
                    _amountFocusNode.requestFocus();
                  }
                },
              ),
            ),
            Expanded(
              child: _selectedTab == 0
                  ? _buildQuickTab(people, groups)
                  : _buildManualTab(people, groups, currentGroup),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. QUICK TAB
  // ---------------------------------------------------------------------------

  Widget _buildQuickTab(List<Person> people, List<Group> groups) {
    final theme = context.settliv;
    final parser = QuickExpenseParser(
      availablePeople: people,
      availableGroups: groups,
      currentUser: people.firstWhere((p) => p.id == 'person_arjun'),
    );

    final parseResult = parser.parse(
      _quickTextController.text,
      defaultGroupId: _selectedGroupId,
    );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _quickFocusNode.hasFocus
                  ? AppColors.midnightNavy
                  : theme.hairline,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _quickTextController,
            focusNode: _quickFocusNode,
            maxLines: 3,
            minLines: 2,
            style: AppTypography.body.copyWith(
              color: theme.ink,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. dinner 800 with Meera and Kabir',
              hintStyle: AppTypography.body.copyWith(
                color: theme.tertiary,
                fontSize: 16,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 16),

        // Live Draft Card
        if (parseResult.isValid && parseResult.amountPaise != null) ...[
          _buildLiveDraftCard(parseResult),
        ] else if (parseResult.hint != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.hairline),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 18,
                  color: AppColors.saffron,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parseResult.hint!,
                    style: AppTypography.caption.copyWith(
                      color: theme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLiveDraftCard(QuickParseResult result) {
    final theme = context.settliv;
    final int memberCount = result.participants.length;
    final perPersonPaise = result.amountPaise! ~/ memberCount;

    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryBadge(category: result.category, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.description,
                      style: AppTypography.titleLarge.copyWith(
                        color: theme.ink,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '${result.inferredGroup?.name ?? 'Group'} · Split equally',
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatPaise(result.amountPaise!, absolute: true),
                style: AppTypography.displayMoney.copyWith(
                  fontSize: 22,
                  color: theme.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            'Split with ($memberCount members · ~${CurrencyFormatter.formatPaise(perPersonPaise, absolute: true)} each):',
            style: AppTypography.caption.copyWith(
              color: theme.secondary,
              fontWeight: FontWeight.w600,
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
          const SizedBox(height: 20),
          PrimaryButton(
            label: _showSavedSuccess
                ? 'Saved!'
                : 'Confirm · ${CurrencyFormatter.formatPaise(result.amountPaise!, absolute: true)} split with $memberCount people',
            variant: _showSavedSuccess
                ? PrimaryButtonVariant.emeraldConfirm
                : PrimaryButtonVariant.navy,
            isLoading: _isSaving && !_showSavedSuccess,
            leading: _showSavedSuccess
                ? const Icon(Icons.check_circle_rounded, color: Colors.white)
                : null,
            onPressed: _isSaving
                ? null
                : () {
                    final Map<String, int> shares = {};
                    int remaining = result.amountPaise!;
                    for (int i = 0; i < result.participants.length; i++) {
                      final p = result.participants[i];
                      if (i == result.participants.length - 1) {
                        shares[p.id] = remaining;
                      } else {
                        shares[p.id] = perPersonPaise;
                        remaining -= perPersonPaise;
                      }
                    }

                    final newExp = Expense(
                      id: widget.initialExpense?.id ??
                          'exp_${DateTime.now().millisecondsSinceEpoch}',
                      groupId: result.inferredGroup?.id ?? _selectedGroupId,
                      title: result.description,
                      category: result.category,
                      amount: result.amountPaise!,
                      date: DateTime.now(),
                      paidBy: result.payerId ?? 'person_arjun',
                      splitMode: SplitMode.equal,
                      shares: shares,
                    );
                    _saveExpense(newExp);
                  },
          ),
          const SizedBox(height: 8),
          Center(
            child: TextActionButton(
              label: 'Edit details in Manual',
              onPressed: () => _switchToManualPrefilled(result),
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
    final int? enteredPaise = CurrencyFormatter.parseToPaise(_amountController.text);
    final int amountPaise = enteredPaise ?? 0;

    // Validate shares based on split mode
    final validation = _validateManualSplit(amountPaise);

    final String buttonLabel;
    if (widget.initialExpense != null) {
      buttonLabel = 'Update ${CurrencyFormatter.formatPaise(amountPaise, absolute: true)}';
    } else {
      buttonLabel =
          'Save ${CurrencyFormatter.formatPaise(amountPaise, absolute: true)} · split with ${_selectedMemberIds.length} people';
    }

    final payer = people.firstWhere(
      (p) => p.id == _paidById,
      orElse: () => people.first,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              // 1. Giant AmountField
              Center(
                child: SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    textAlign: TextAlign.center,
                    style: AppTypography.displayMoney.copyWith(
                      color: theme.ink,
                      fontSize: 44,
                    ),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: AppTypography.displayMoney.copyWith(
                        color: theme.secondary,
                        fontSize: 36,
                      ),
                      hintText: '0',
                      hintStyle: AppTypography.displayMoney.copyWith(
                        color: theme.tertiary.withValues(alpha: 0.5),
                        fontSize: 44,
                      ),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Description field
              Container(
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.hairline),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _descriptionController,
                  style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                  decoration: InputDecoration(
                    hintText: 'What was this expense for?',
                    hintStyle: AppTypography.body.copyWith(color: theme.tertiary),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 14),

              // Category chip row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final cat in ExpenseCategory.values) ...[
                      _buildCategoryChip(cat),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Group chips
              Text(
                'Group',
                style: AppTypography.caption.copyWith(
                  color: theme.secondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final g in groups) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (_selectedGroupId != g.id) {
                            setState(() {
                              _selectedGroupId = g.id;
                              _initMembersForGroup();
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedGroupId == g.id
                                ? AppColors.midnightNavy
                                : theme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedGroupId == g.id
                                  ? Colors.transparent
                                  : theme.hairline,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              g.name,
                              style: AppTypography.chip.copyWith(
                                color: _selectedGroupId == g.id
                                    ? Colors.white
                                    : theme.ink,
                                fontWeight: _selectedGroupId == g.id
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (g != groups.last) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // 4. Two compact row cards: Date & Paid by
              Row(
                children: [
                  // Date Card
                  Expanded(
                    child: InkWell(
                      onTap: () => _openDatePickerSheet(),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: AppTypography.caption.copyWith(
                                color: theme.secondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                  ),
                  const SizedBox(width: 12),
                  // Paid by Card
                  Expanded(
                    child: InkWell(
                      onTap: () => _openPaidBySheet(people, currentGroup),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.hairline),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paid by',
                              style: AppTypography.caption.copyWith(
                                color: theme.secondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                PersonAvatar(person: payer, size: 20),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    payer.id == 'person_arjun' ? 'You' : payer.name,
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
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 5. "Split with" section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Split with: ${_selectedMemberIds.length} members',
                    style: AppTypography.sectionHeader.copyWith(
                      color: theme.ink,
                      fontSize: 15,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedMemberIds.length == currentGroup.memberIds.length) {
                          _selectedMemberIds = {'person_arjun'};
                        } else {
                          _selectedMemberIds = currentGroup.memberIds.toSet();
                        }
                        _rebuildSplitControllers();
                      });
                    },
                    child: Text(
                      _selectedMemberIds.length == currentGroup.memberIds.length
                          ? 'Select none'
                          : 'Select all',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.cobaltGlow,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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

              // 6. Split mode selector: Equal / Exact / Percent
              SegmentedTabs(
                labels: const ['Equal', 'Exact', 'Percent'],
                selectedIndex: _splitMode.index,
                onTabSelected: (idx) {
                  setState(() => _splitMode = SplitMode.values[idx]);
                },
              ),
              const SizedBox(height: 14),

              // Per-person split inputs / breakdown
              _buildSplitModeContent(people, amountPaise),

              const SizedBox(height: 20),
              // Scan a receipt coming soon tag
              Center(
                child: ComingSoonTag(
                  label: 'Scan a receipt · full app',
                  featureDescription:
                      'OCR receipt scanning automatically extracts items, tax, tip and assigns them to flatmates.',
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),

        // 7. Sticky bottom action bar
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.hairline)),
          ),
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
              PrimaryButton(
                label: _showSavedSuccess ? 'Saved!' : buttonLabel,
                variant: _showSavedSuccess
                    ? PrimaryButtonVariant.emeraldConfirm
                    : PrimaryButtonVariant.navy,
                isLoading: _isSaving && !_showSavedSuccess,
                leading: _showSavedSuccess
                    ? const Icon(Icons.check_circle_rounded, color: Colors.white)
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
      ],
    );
  }

  Widget _buildCategoryChip(ExpenseCategory category) {
    final theme = context.settliv;
    final isSelected = _selectedCategory == category;

    return Semantics(
      button: true,
      selected: isSelected,
      label: category.label,
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = category),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.midnightNavy : theme.raised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? Colors.transparent : theme.hairline,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CategoryBadge(
                category: category,
                size: 26,
                iconSize: 14,
                borderRadius: 8,
              ),
              const SizedBox(width: 6),
              Text(
                category.label,
                style: AppTypography.chip.copyWith(
                  color: isSelected ? Colors.white : theme.ink,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSplitModeContent(List<Person> people, int totalPaise) {
    final theme = context.settliv;

    if (_splitMode == SplitMode.equal) {
      final int count = _selectedMemberIds.length;
      final int perPersonPaise = count > 0 ? totalPaise ~/ count : 0;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.raised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.hairline),
        ),
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

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.hairline),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assign amounts in ₹',
                  style: AppTypography.caption.copyWith(color: theme.secondary),
                ),
                Text(
                  remainingPaise == 0
                      ? 'All assigned'
                      : '${CurrencyFormatter.formatPaise(remainingPaise.abs(), absolute: true)} ${remainingPaise > 0 ? "left" : "over"}',
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
                          style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        height: 40,
                        child: TextField(
                          controller: controller,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.hairline),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assign % shares',
                style: AppTypography.caption.copyWith(color: theme.secondary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: totalPct == 100
                      ? AppColors.emeraldTint
                      : AppColors.coralTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$totalPct% of 100%',
                  style: AppTypography.caption.copyWith(
                    color: totalPct == 100
                        ? AppColors.emerald
                        : AppColors.coral,
                    fontWeight: FontWeight.w700,
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
                            style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                          ),
                          Text(
                            CurrencyFormatter.formatPaise(approxPaise, absolute: true),
                            style: AppTypography.caption.copyWith(color: theme.secondary),
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
      return (isValid: false, errorMessage: 'Add an amount');
    }
    if (_selectedMemberIds.isEmpty) {
      return (isValid: false, errorMessage: 'Select at least one person to split with');
    }

    if (_splitMode == SplitMode.exact) {
      int assigned = 0;
      for (final id in _selectedMemberIds) {
        assigned += CurrencyFormatter.parseToPaise(_exactControllers[id]?.text ?? '') ?? 0;
      }
      final diff = totalPaise - assigned;
      if (diff != 0) {
        final formatted = CurrencyFormatter.formatPaise(diff.abs(), absolute: true);
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
    final Map<String, int> result = {};

    if (_splitMode == SplitMode.equal) {
      final count = _selectedMemberIds.length;
      final perPerson = totalPaise ~/ count;
      int remaining = totalPaise;
      final membersList = _selectedMemberIds.toList();

      for (int i = 0; i < membersList.length; i++) {
        final id = membersList[i];
        if (i == membersList.length - 1) {
          result[id] = remaining;
        } else {
          result[id] = perPerson;
          remaining -= perPerson;
        }
      }
    } else if (_splitMode == SplitMode.exact) {
      for (final id in _selectedMemberIds) {
        result[id] =
            CurrencyFormatter.parseToPaise(_exactControllers[id]?.text ?? '') ?? 0;
      }
    } else if (_splitMode == SplitMode.percent) {
      int remaining = totalPaise;
      final membersList = _selectedMemberIds.toList();
      for (int i = 0; i < membersList.length; i++) {
        final id = membersList[i];
        final pct = int.tryParse(_percentControllers[id]?.text ?? '') ?? 0;
        if (i == membersList.length - 1) {
          result[id] = remaining;
        } else {
          final share = (totalPaise * pct) ~/ 100;
          result[id] = share;
          remaining -= share;
        }
      }
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Date and Paid By Pickers
  // ---------------------------------------------------------------------------

  void _openDatePickerSheet() {
    final now = DateTime.now();
    final dates = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
    );

    SheetScaffold.show(
      context: context,
      isScrollControlled: false,
      builder: (ctx) {
        final theme = ctx.settliv;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in dates) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    DateFormatter.formatDayHeader(d),
                    style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                  ),
                  subtitle: Text(
                    DateFormatter.formatFull(d),
                    style: AppTypography.caption.copyWith(color: theme.secondary),
                  ),
                  trailing: d.day == _selectedDate.day &&
                          d.month == _selectedDate.month &&
                          d.year == _selectedDate.year
                      ? const Icon(Icons.check_rounded, color: AppColors.emerald)
                      : null,
                  onTap: () {
                    setState(() => _selectedDate = d);
                    Navigator.of(ctx).pop();
                  },
                ),
                if (d != dates.last) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openPaidBySheet(List<Person> people, Group group) {
    final groupMembers = people.where((p) => group.memberIds.contains(p.id)).toList();

    SheetScaffold.show(
      context: context,
      isScrollControlled: false,
      builder: (ctx) {
        final theme = ctx.settliv;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in groupMembers) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: PersonAvatar(person: m, size: 36),
                  title: Text(
                    m.id == 'person_arjun' ? 'You (${m.name})' : m.name,
                    style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                  ),
                  trailing: m.id == _paidById
                      ? const Icon(Icons.check_rounded, color: AppColors.emerald)
                      : null,
                  onTap: () {
                    setState(() => _paidById = m.id);
                    Navigator.of(ctx).pop();
                  },
                ),
                if (m != groupMembers.last) const Divider(height: 1),
              ],
            ],
          ),
        );
      },
    );
  }
}
