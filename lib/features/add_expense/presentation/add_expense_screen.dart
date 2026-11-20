import 'dart:async';
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
import '../../../core/widgets/glass_segmented.dart';
import '../../../core/widgets/glass_sheet_scaffold.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/gradient_primary_button.dart';
import '../../../core/widgets/member_chip.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/engine/repeat_suggestion_engine.dart';
import '../../../data/engine/split_calculator.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../../data/seed/seed_data.dart';
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

  // Placeholder cycling
  static const List<String> _placeholderExamples = [
    'dinner 800 with Meera and Kabir',
    'cab 240 with Kabir',
    'groceries 1,250',
    'rent 18,000',
    'movie 600 split 4',
  ];
  int _exampleIndex = 0;
  Timer? _exampleTimer;

  // Manual Tab state
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final FocusNode _amountFocusNode;
  late final FocusNode _descFocusNode;

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
  bool _attemptedSave = false;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialExpense != null ? 1 : widget.initialTabIndex;

    _quickTextController =
        TextEditingController(text: widget.initialText ?? '');
    _quickFocusNode = FocusNode();
    _quickFocusNode.addListener(() {
      if (mounted) setState(() {});
    });

    _startExampleTimer();

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
      _selectedCategory = ExpenseCategory.other; // Default: Other per spec
      _selectedGroupId = widget.preselectedGroupId ?? 'group_flatmates';
      _selectedDate = DateTime.now();
      _paidById = SeedData.currentUserId;
      _selectedMemberIds = _selectedGroupId == 'group_flatmates'
          ? {'person_arjun', 'person_meera', 'person_kabir'}
          : {'person_arjun', 'person_nisha', 'person_rohan', 'person_tara'};
      _splitMode = SplitMode.equal;
      _rebuildSplitControllers();
    }

    _amountFocusNode = FocusNode();
    _descFocusNode = FocusNode();
    _amountFocusNode.addListener(() {
      if (!_amountFocusNode.hasFocus && mounted) {
        setState(() {});
      }
    });
    _descFocusNode.addListener(() {
      if (!_descFocusNode.hasFocus && mounted) {
        setState(() {});
      }
    });
  }

  void _startExampleTimer() {
    _exampleTimer?.cancel();
    _exampleTimer =
        Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final bool reduceMotion =
          MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (_quickFocusNode.hasFocus ||
          _quickTextController.text.isNotEmpty ||
          reduceMotion) {
        return;
      }
      setState(() {
        _exampleIndex = (_exampleIndex + 1) % _placeholderExamples.length;
      });
    });
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
    _exampleTimer?.cancel();
    _quickTextController.dispose();
    _quickFocusNode.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _amountFocusNode.dispose();
    _descFocusNode.dispose();
    for (final c in _exactControllers.values) {
      c.dispose();
    }
    for (final c in _percentControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    if (_showSavedSuccess || _isSaving) return false;
    if (_selectedTab == 0) {
      return _quickTextController.text.trim().isNotEmpty;
    } else {
      return _amountController.text.trim().isNotEmpty ||
          _descriptionController.text.trim().isNotEmpty;
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges()) return true;

    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved expense details. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return discard == true;
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
    _paidById = result.payerId ?? SeedData.currentUserId;
    _splitMode = SplitMode.equal;
    _rebuildSplitControllers();

    setState(() => _selectedTab = 1);
    _amountFocusNode.requestFocus();
  }

  Future<void> _checkAndSaveExpense(Expense expense) async {
    // 1. Guard against hard block above ₹10,00,00,000 (Global Rule 3)
    if (expense.amount > CurrencyFormatter.maxAmountPaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount exceeds maximum limit of ₹10,00,00,000'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 2. Large amount confirmation (From ₹1,00,000 up to cap) (Global Rule 3)
    if (expense.amount >= CurrencyFormatter.largeAmountThresholdPaise) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm large amount'),
          content: Text(
            '${CurrencyFormatter.formatPaise(expense.amount, absolute: true)} · ${CurrencyFormatter.formatPaiseInWords(expense.amount)}\n\nIs this correct?',
            style: const TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Edit amount'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.sapphire,
              ),
              child: const Text('Yes, add it'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
    }

    // 3. Duplicate guard: same description + amount + group within 2 minutes (Part 2d)
    final allExpenses = ref.read(allExpensesProvider);
    final isDuplicate = allExpenses.any(
      (e) =>
          !e.isDeleted &&
          e.id != expense.id &&
          e.groupId == expense.groupId &&
          e.title.trim().toLowerCase() == expense.title.trim().toLowerCase() &&
          e.amount == expense.amount &&
          DateTime.now().difference(e.date).inMinutes.abs() < 2,
    );

    if (isDuplicate) {
      final addAnyway = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate expense?'),
          content: const Text(
            'An expense with the same description, amount and group was logged within the last 2 minutes.\n\nLooks like a duplicate. Add anyway?',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add anyway'),
            ),
          ],
        ),
      );
      if (addAnyway != true) return;
      if (!mounted) return;
    }

    // Double-tap guard
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _showSavedSuccess = true;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final repoNotifier = ref.read(appStateProvider.notifier);
    if (widget.initialExpense != null) {
      repoNotifier.updateExpense(expense);
    } else {
      repoNotifier.addExpense(expense);
    }

    if (mounted) {
      context.pop(expense.id);
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
    final allExpenses = ref.watch(allExpensesProvider);
    final currentGroup = groups.firstWhere(
      (g) => g.id == _selectedGroupId,
      orElse: () => groups.first,
    );

    return PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: AuroraBackground(
          child: SafeArea(
            child: Column(
              children: [
                // Top Bar: Glass circular close button + title
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
                          onTap: () async {
                            final shouldPop = await _onWillPop();
                            if (shouldPop && context.mounted) {
                              context.pop();
                            }
                          },
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

                // Tab Body
                Expanded(
                  child: _selectedTab == 0
                      ? _buildQuickTab(people, groups, allExpenses)
                      : _buildManualTab(people, groups, currentGroup),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. QUICK TAB
  // ---------------------------------------------------------------------------

  Widget _buildQuickTab(
    List<Person> people,
    List<Group> groups,
    List<Expense> allExpenses,
  ) {
    final theme = context.settliv;
    final parser = QuickExpenseParser(
      availablePeople: people,
      availableGroups: groups,
      currentUser: people.firstWhere(
        (p) => p.id == SeedData.currentUserId,
        orElse: () => people.first,
      ),
    );

    final parseResult = parser.parse(
      _quickTextController.text,
      defaultGroupId: _selectedGroupId,
    );

    final bool hasValidExpense = parseResult.isValid;

    final String ctaLabel = hasValidExpense
        ? 'Confirm · ${CurrencyFormatter.formatPaise(parseResult.amountPaise!, absolute: true)} with ${parseResult.participants.length} people'
        : 'Add expense';

    // Repeat suggestions for descriptions logged 3+ times
    final repeatSuggestions = RepeatSuggestionEngine.getRepeatSuggestions(
      expenses: allExpenses,
      currentUserId: SeedData.currentUserId,
    );

    final currentExample = _placeholderExamples[_exampleIndex];

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 140),
          children: [
            // Composer Card with cycling placeholder and "Use this" button
            GlassSurface(
              level: GlassLevel.level2,
              borderRadius: 24,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'WHAT DID YOU SPEND ON?',
                          style: AppTypography.sectionLabel.copyWith(
                            color: theme.secondary,
                            letterSpacing: 0.8,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_quickTextController.text.isEmpty) ...[
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Use current example',
                          child: InkWell(
                            onTap: () {
                              _quickTextController.text = currentExample;
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              child: Text(
                                'Use this',
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sapphire,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 84),
                    child: Stack(
                      children: [
                        // Cycling placeholder text when empty
                        if (_quickTextController.text.isEmpty)
                          IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              transitionBuilder: (child, animation) {
                                final offset = Tween<Offset>(
                                  begin: const Offset(0.0, 0.2),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ));
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                      position: offset, child: child),
                                );
                              },
                              child: Text(
                                currentExample,
                                key: ValueKey<int>(_exampleIndex),
                                style: AppTypography.titleLarge.copyWith(
                                  color: theme.tertiary.withValues(alpha: 0.5),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.3,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        TextField(
                          controller: _quickTextController,
                          focusNode: _quickFocusNode,
                          maxLines: 4,
                          minLines: 2,
                          style: AppTypography.titleLarge.copyWith(
                            color: theme.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            height: 1.35,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),

                  // Live Parse Preview (plain small text rows, not capsules)
                  if (_quickTextController.text.isNotEmpty) ...[
                    Divider(height: 20, color: theme.hairline),
                    _buildLiveParsePreview(parseResult, theme),
                  ],
                ],
              ),
            ),

            // Repeat row (ONLY appears when user has logged 3+ times in same group)
            if (repeatSuggestions.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'REPEAT RECENT EXPENSES',
                style: AppTypography.sectionLabel.copyWith(
                  color: theme.secondary,
                  letterSpacing: 0.8,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              _buildRepeatSuggestions(repeatSuggestions, groups),
            ],

            const SizedBox(height: 16),

            // Live Draft Card when valid
            if (hasValidExpense) ...[
              _buildLiveDraftCard(parseResult),
            ],
          ],
        ),

        // Sticky Bottom Bar
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
                if (parseResult.hint != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      parseResult.hint!,
                      style: AppTypography.caption.copyWith(
                        color: hasValidExpense
                            ? theme.secondary
                            : (parseResult.isOverCap
                                ? AppColors.coral
                                : theme.secondary),
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
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
                          final memberIds = parseResult.participants
                              .map((p) => p.id)
                              .toList();
                          final payerId =
                              parseResult.payerId ?? SeedData.currentUserId;
                          final shares = SplitCalculator.splitEqual(
                            totalPaise: parseResult.amountPaise!,
                            memberIds: memberIds,
                            paidBy: payerId,
                          );

                          final newExp = Expense(
                            id: widget.initialExpense?.id ??
                                'exp_${DateTime.now().millisecondsSinceEpoch}',
                            groupId: parseResult.inferredGroup?.id ??
                                _selectedGroupId,
                            title: parseResult.description,
                            category: parseResult.category,
                            amount: parseResult.amountPaise!,
                            date: DateTime.now(),
                            paidBy: payerId,
                            splitMode: SplitMode.equal,
                            shares: shares,
                          );
                          _checkAndSaveExpense(newExp);
                        },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Live parse preview under the quick input field: plain small text rows, not capsules.
  Widget _buildLiveParsePreview(
      QuickParseResult result, SettlivThemeExtension theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.amountPaise != null)
          _buildPreviewRow(
            icon: Icons.currency_rupee_rounded,
            label: 'Amount',
            value: CurrencyFormatter.formatPaise(result.amountPaise!,
                absolute: true),
            theme: theme,
          ),
        if (result.participants.isNotEmpty)
          _buildPreviewRow(
            icon: Icons.people_outline_rounded,
            label: 'Split with',
            value: result.participants.map((p) => p.name).join(', '),
            theme: theme,
          ),
        _buildPreviewRow(
          icon: Icons.category_outlined,
          label: 'Category',
          value: result.category.label,
          theme: theme,
        ),
        if (result.inferredGroup != null)
          _buildPreviewRow(
            icon: Icons.group_work_outlined,
            label: 'Group',
            value: result.inferredGroup!.name,
            theme: theme,
          ),
      ],
    );
  }

  Widget _buildPreviewRow({
    required IconData icon,
    required String label,
    required String value,
    required SettlivThemeExtension theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.sapphire),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.secondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepeatSuggestions(
    List<RepeatSuggestion> suggestions,
    List<Group> groups,
  ) {
    final theme = context.settliv;

    return Column(
      children: [
        for (final s in suggestions) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                final group = groups.firstWhere(
                  (g) => g.id == s.groupId,
                  orElse: () => groups.first,
                );
                final paise = s.latestAmountPaise;
                final amountText = paise > 0
                    ? ' ${CurrencyFormatter.formatPaise(paise, absolute: true).replaceAll('₹', '')}'
                    : '';
                _quickTextController.text = '${s.displayTitle}$amountText';
                setState(() => _selectedGroupId = group.id);
              },
              borderRadius: BorderRadius.circular(16),
              child: GlassSurface(
                level: GlassLevel.level1,
                borderRadius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.replay_rounded,
                        size: 16, color: AppColors.sapphire),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.displayTitle} (${CurrencyFormatter.formatPaise(s.latestAmountPaise, absolute: true)})',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${s.count} times',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        color: theme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLiveDraftCard(QuickParseResult result) {
    final theme = context.settliv;
    final int memberCount = result.participants.length;
    final perPersonPaise =
        memberCount > 0 ? result.amountPaise! ~/ memberCount : 0;

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

    // Validate manual split
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
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 160),
          children: [
            // 1. Amount hero: digits only, max 2 decimals, live grouping
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

            if (_attemptedSave && amountPaise <= 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Center(
                  child: Text(
                    'Add an amount to continue',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.coral,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 14),

            // 2. Description (required, max 60 chars)
            GlassSurface(
              level: GlassLevel.level1,
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _descriptionController,
                focusNode: _descFocusNode,
                maxLength: 60,
                buildCounter: (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null, // hide default counter
                style: AppTypography.bodyMedium.copyWith(color: theme.ink),
                decoration: InputDecoration(
                  hintText: 'What was this expense for? (Required)',
                  hintStyle:
                      AppTypography.body.copyWith(color: theme.tertiary),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            if (_attemptedSave &&
                _descriptionController.text.trim().isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Description is required',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.coral,
                  ),
                ),
              ),

            const SizedBox(height: 18),

            // Categories: 4x2 grid of CategoryTiles with Other as default
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

            // Group selector
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
                Expanded(
                  child: GlassSurface(
                    level: GlassLevel.level1,
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    onTap: _openDatePickerSheet,
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 18, color: AppColors.sapphire),
                        const SizedBox(width: 8),
                        Expanded(
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
                              Text(
                                DateFormatter.formatRelative(_selectedDate),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassSurface(
                    level: GlassLevel.level1,
                    borderRadius: 18,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    onTap: () => _openPaidByPickerSheet(people),
                    child: Row(
                      children: [
                        PersonAvatar(person: payer, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
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
                              Text(
                                payer.name,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Split with section: Clear / All toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SPLIT WITH',
                  style: AppTypography.sectionLabel.copyWith(
                    color: theme.secondary,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
                InkWell(
                  onTap: () {
                    final groupMembers = people
                        .where((p) => currentGroup.memberIds.contains(p.id))
                        .map((p) => p.id)
                        .toSet();
                    setState(() {
                      if (_selectedMemberIds.length == groupMembers.length) {
                        _selectedMemberIds = {};
                      } else {
                        _selectedMemberIds = groupMembers;
                      }
                      _rebuildSplitControllers();
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      _selectedMemberIds.length == currentGroup.memberIds.length
                          ? 'Clear'
                          : 'All',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: AppColors.sapphire,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
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
                for (final p in people
                    .where((p) => currentGroup.memberIds.contains(p.id))) ...[
                  MemberChip(
                    person: p,
                    isSelected: _selectedMemberIds.contains(p.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedMemberIds.add(p.id);
                        } else {
                          _selectedMemberIds.remove(p.id);
                        }
                        _rebuildSplitControllers();
                      });
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 22),

            // Split mode: Equal | Exact | Percent
            Text(
              'SPLIT MODE',
              style: AppTypography.sectionLabel.copyWith(
                color: theme.secondary,
                letterSpacing: 0.8,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            GlassSegmented<int>(
              values: const [0, 1, 2],
              labels: const ['Equal', 'Exact', 'Percent'],
              selectedValue: _splitMode.index,
              onValueChanged: (idx) =>
                  setState(() => _splitMode = SplitMode.values[idx]),
            ),
            const SizedBox(height: 14),

            _buildSplitModeContent(people, amountPaise),
          ],
        ),

        // Sticky Bottom Bar
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
                if (!validation.isValid && validation.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      validation.errorMessage!,
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary, // Neutral helper text per rule
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                GradientPrimaryButton(
                  label: _showSavedSuccess ? 'Saved!' : buttonLabel,
                  isLoading: _isSaving && !_showSavedSuccess,
                  icon: _showSavedSuccess
                      ? const Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 20)
                      : null,
                  onPressed: (!validation.isValid || _isSaving)
                      ? () {
                          setState(() => _attemptedSave = true);
                        }
                      : () {
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
                          _checkAndSaveExpense(newExp);
                        },
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < 4; i++)
                _buildCategoryGridItem(categories[i], theme),
            ],
          ),
          const SizedBox(height: 12),
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

  Widget _buildCategoryGridItem(
      ExpenseCategory cat, SettlivThemeExtension theme) {
    final isSelected = _selectedCategory == cat;

    return InkWell(
      onTap: () => setState(() => _selectedCategory = cat),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.sapphireGradient.colors.first.withValues(alpha: 0.15)
              : Colors.transparent,
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
              'Each person pays',
              style: AppTypography.body.copyWith(
                color: theme.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '~${CurrencyFormatter.formatPaise(perPersonPaise, absolute: true)}',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.ink,
              ),
            ),
          ],
        ),
      );
    }

    if (_splitMode == SplitMode.exact) {
      int totalAssigned = 0;
      for (final id in _selectedMemberIds) {
        totalAssigned +=
            CurrencyFormatter.parseToPaise(_exactControllers[id]?.text ?? '') ??
                0;
      }
      final diff = totalPaise - totalAssigned;

      return Column(
        children: [
          for (final id in _selectedMemberIds) ...[
            Builder(builder: (context) {
              final p = people.firstWhere(
                (m) => m.id == id,
                orElse: () => Person(
                    id: id,
                    name: 'Member',
                    avatarInitials: 'M',
                    avatarPairIndex: 0),
              );
              final controller = _exactControllers[id]!;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GlassSurface(
                  level: GlassLevel.level1,
                  borderRadius: 16,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    children: [
                      PersonAvatar(person: p, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p.name,
                          style: AppTypography.bodyMedium.copyWith(
                            color: theme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text('₹ ',
                          style: TextStyle(
                              color: theme.secondary,
                              fontWeight: FontWeight.w700)),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          textAlign: TextAlign.right,
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.ink,
                          ),
                          decoration: const InputDecoration(
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
              );
            }),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  diff == 0
                      ? 'Total assigned matches'
                      : (diff > 0
                          ? '${CurrencyFormatter.formatPaise(diff.abs(), absolute: true)} left to assign'
                          : 'Over by ${CurrencyFormatter.formatPaise(diff.abs(), absolute: true)}'),
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: diff == 0 ? AppColors.emerald : theme.secondary,
                  ),
                ),
                Text(
                  'Total: ${CurrencyFormatter.formatPaise(totalAssigned, absolute: true)} / ${CurrencyFormatter.formatPaise(totalPaise, absolute: true)}',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // SplitMode.percent
    double totalPct = 0;
    for (final id in _selectedMemberIds) {
      totalPct +=
          double.tryParse(_percentControllers[id]?.text ?? '') ?? 0.0;
    }
    final diffPct = 100.0 - totalPct;

    return Column(
      children: [
        for (final id in _selectedMemberIds) ...[
          Builder(builder: (context) {
            final p = people.firstWhere(
              (m) => m.id == id,
              orElse: () => Person(
                  id: id,
                  name: 'Member',
                  avatarInitials: 'M',
                  avatarPairIndex: 0),
            );
            final controller = _percentControllers[id]!;
            final pctVal = double.tryParse(controller.text) ?? 0.0;
            final sharePaise = (totalPaise * pctVal / 100.0).round();

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GlassSurface(
                level: GlassLevel.level1,
                borderRadius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    PersonAvatar(person: p, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.name,
                        style: AppTypography.bodyMedium.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatPaise(sharePaise,
                          absolute: true),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: theme.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 50,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        textAlign: TextAlign.right,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.ink,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    Text(' %',
                        style: TextStyle(
                            color: theme.secondary,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            );
          }),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                (diffPct.abs() < 0.01)
                    ? '100% assigned'
                    : (diffPct > 0
                        ? '${diffPct.toStringAsFixed(2)}% left to assign'
                        : 'Over by ${diffPct.abs().toStringAsFixed(2)}%'),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (diffPct.abs() < 0.01)
                      ? AppColors.emerald
                      : theme.secondary,
                ),
              ),
              Text(
                'Total: ${totalPct.toStringAsFixed(1)}% / 100%',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Validation & Share Calculations
  // ---------------------------------------------------------------------------

  ({bool isValid, String? errorMessage}) _validateManualSplit(int totalPaise) {
    if (totalPaise <= 0) {
      return (isValid: false, errorMessage: 'Add an amount to continue');
    }
    if (totalPaise > CurrencyFormatter.maxAmountPaise) {
      return (
        isValid: false,
        errorMessage: 'Amount exceeds maximum limit of ₹10,00,00,000'
      );
    }
    if (_descriptionController.text.trim().isEmpty) {
      return (isValid: false, errorMessage: 'Description is required');
    }
    if (_descriptionController.text.trim().length > 60) {
      return (
        isValid: false,
        errorMessage: 'Description must be 60 characters or less'
      );
    }
    if (_selectedMemberIds.isEmpty) {
      return (
        isValid: false,
        errorMessage: 'Select at least one person to split with'
      );
    }
    if (_paidById.isEmpty) {
      return (isValid: false, errorMessage: 'Select who paid');
    }
    if (_selectedDate.isAfter(DateTime.now())) {
      return (isValid: false, errorMessage: 'Date cannot be in the future');
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
          errorMessage:
              diff > 0 ? '$formatted left to assign' : 'Over by $formatted'
        );
      }
    }

    if (_splitMode == SplitMode.percent) {
      int totalBp = 0;
      for (final id in _selectedMemberIds) {
        final pctDouble =
            double.tryParse(_percentControllers[id]?.text ?? '') ?? 0.0;
        totalBp += (pctDouble * 100).round();
      }
      if (totalBp != 10000) {
        final diffBp = 10000 - totalBp;
        final diffStr = (diffBp.abs() / 100.0).toStringAsFixed(2);
        return (
          isValid: false,
          errorMessage: diffBp > 0
              ? '$diffStr% left to assign'
              : 'Over by $diffStr%'
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
  // Date and Paid By Pickers
  // ---------------------------------------------------------------------------

  void _openDatePickerSheet() {
    final now = DateTime.now();
    final dates = List.generate(
      7,
      (i) =>
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i)),
    );

    GlassSheetScaffold.show(
      context: context,
      title: 'Select expense date',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final d in dates) ...[
            ListTile(
              title: Text(
                DateFormatter.formatFull(d),
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: _selectedDate.day == d.day &&
                          _selectedDate.month == d.month &&
                          _selectedDate.year == d.year
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              trailing: _selectedDate.day == d.day &&
                      _selectedDate.month == d.month &&
                      _selectedDate.year == d.year
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.sapphire)
                  : null,
              onTap: () {
                setState(() => _selectedDate = d);
                Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }

  void _openPaidByPickerSheet(List<Person> people) {
    GlassSheetScaffold.show(
      context: context,
      title: 'Who paid for this?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in people) ...[
            ListTile(
              leading: PersonAvatar(person: p, size: 32),
              title: Text(
                p.id == SeedData.currentUserId ? '${p.name} (You)' : p.name,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: _paidById == p.id
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              trailing: _paidById == p.id
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppColors.sapphire)
                  : null,
              onTap: () {
                setState(() => _paidById = p.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}
