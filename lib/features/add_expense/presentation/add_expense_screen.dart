import '../../../core/layout/adaptive_layout.dart';
import '../../../core/navigation/back_navigation.dart';
import '../../../core/profile/experience_mode.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/engine/repeat_suggestion_engine.dart';
import '../../../data/engine/split_calculator.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/group.dart';
import '../../../data/models/person.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../../data/seed/seed_data.dart';
import '../logic/quick_expense_parser.dart';
import 'widgets/scan_sheet.dart';

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
  final GlobalKey _amountFieldKey = GlobalKey();
  final GlobalKey _quickFieldKey = GlobalKey();

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

    // Auto-focus Quick tab keyboard on open (when not editing an existing expense)
    if (widget.initialExpense == null && _selectedTab == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _quickFocusNode.requestFocus();
      });
    }

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
      if (_selectedGroupId == 'group_personal') {
        _selectedMemberIds = {SeedData.currentUserId};
      } else if (_selectedGroupId == 'group_flatmates') {
        _selectedMemberIds = {'person_arjun', 'person_meera', 'person_kabir'};
      } else {
        _selectedMemberIds = {
          'person_arjun',
          'person_nisha',
          'person_rohan',
          'person_tara',
        };
      }
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
      // Per spec: typewriter keeps cycling while empty even when focused/tapped
      if (_quickTextController.text.isNotEmpty || reduceMotion) {
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
    final repo = ref.read(appRepositoryProvider);
    final group = repo.getGroup(_selectedGroupId);
    if (group == null) return;
    if (group.isPersonal) {
      // Personal space: only the current user, no split
      _selectedMemberIds = {SeedData.currentUserId};
      _paidById = SeedData.currentUserId;
    } else {
      _selectedMemberIds = group.memberIds.toSet();
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
    final theme = context.settliv;

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
              backgroundColor: theme.textCoral,
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

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.trim().isNotEmpty) {
        setState(() {
          _quickTextController.text = data.text!.trim();
        });
      }
    } catch (_) {}
  }

  void _showGroupSelectorSheet(BuildContext context, List<Group> groups) {
    final theme = context.settliv;
    final personalGroup = groups.firstWhere((g) => g.isPersonal, orElse: () => groups.first);
    final sharedGroups = groups.where((g) => !g.isPersonal).toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.transparent,
      isScrollControlled: true,
      builder: (ctx) => GlassSheetScaffold(
        title: 'Select space',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PERSONAL', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    _selectedGroupId = personalGroup.id;
                    _initMembersForGroup();
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: GlassSurface(
                  level: _selectedGroupId == personalGroup.id ? GlassLevel.level2 : GlassLevel.level1,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.person_rounded, size: 20, color: theme.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Personal space', style: AppTypography.bodySemiBold.copyWith(color: theme.ink)),
                      ),
                      if (_selectedGroupId == personalGroup.id)
                        Icon(Icons.check_rounded, size: 18, color: theme.accent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.hairline),
              const SizedBox(height: 16),
              Text('GROUPS', style: AppTypography.sectionLabel.copyWith(color: theme.secondary, letterSpacing: 0.8, fontSize: 11)),
              const SizedBox(height: 8),
              for (final g in sharedGroups) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _selectedGroupId = g.id;
                        _initMembersForGroup();
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: GlassSurface(
                      level: _selectedGroupId == g.id ? GlassLevel.level2 : GlassLevel.level1,
                      borderRadius: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            g.type == GroupType.trip
                                ? Icons.flight_takeoff_rounded
                                : (g.type == GroupType.home ? Icons.home_rounded : Icons.group_rounded),
                            size: 20,
                            color: theme.ink,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: AppTypography.bodySemiBold.copyWith(color: theme.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${g.memberIds.length} members · ${g.type.label}', style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11)),
                              ],
                            ),
                          ),
                          if (_selectedGroupId == g.id)
                            Icon(Icons.check_rounded, size: 18, color: theme.accent),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
      final theme = context.settliv;
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
                backgroundColor: theme.navy,
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

  String _quickCtaLabel(QuickParseResult parseResult, Group currentGroup) {
    if (_showSavedSuccess) return 'Saved!';
    if (!parseResult.isValid || parseResult.amountPaise == null) {
      return 'Add expense';
    }
    final formatted =
        CurrencyFormatter.formatPaise(parseResult.amountPaise!, absolute: true);
    final targetGroup = parseResult.inferredGroup ?? currentGroup;
    if (targetGroup.isPersonal) return 'Add $formatted · Personal';
    return 'Add $formatted to ${targetGroup.name}';
  }

  String _manualCtaLabel(int amountPaise, Group currentGroup) {
    if (_showSavedSuccess) return 'Saved!';
    if (amountPaise <= 0) {
      return widget.initialExpense != null ? 'Update expense' : 'Add expense';
    }
    final formatted = CurrencyFormatter.formatPaise(amountPaise, absolute: true);
    if (widget.initialExpense != null) return 'Update $formatted';
    if (currentGroup.isPersonal) return 'Add $formatted · Personal';
    return 'Add $formatted to ${currentGroup.name}';
  }

  void _submitQuick(QuickParseResult parseResult) {
    if (_isSaving) return;
    if (!parseResult.isValid || parseResult.amountPaise == null) {
      setState(() => _attemptedSave = true);
      _quickFocusNode.requestFocus();
      final ctx = _quickFieldKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    final memberIds = parseResult.participants.map((p) => p.id).toList();
    final payerId = parseResult.payerId ?? SeedData.currentUserId;
    final shares = SplitCalculator.splitEqual(
      totalPaise: parseResult.amountPaise!,
      memberIds: memberIds,
      paidBy: payerId,
    );
    final newExp = Expense(
      id: widget.initialExpense?.id ??
          'exp_${DateTime.now().millisecondsSinceEpoch}',
      groupId: parseResult.inferredGroup?.id ?? _selectedGroupId,
      title: parseResult.description,
      category: parseResult.category,
      amount: parseResult.amountPaise!,
      date: DateTime.now(),
      paidBy: payerId,
      splitMode: SplitMode.equal,
      shares: shares,
    );
    _checkAndSaveExpense(newExp);
  }

  void _submitManual(
    int amountPaise,
    ({bool isValid, String? errorMessage}) validation,
  ) {
    if (_isSaving) return;
    if (!validation.isValid) {
      setState(() => _attemptedSave = true);
      if (amountPaise <= 0) {
        _amountFocusNode.requestFocus();
        final ctx = _amountFieldKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      }
      return;
    }
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
  }

  Widget _buildPinnedFooter({
    required SettlivThemeExtension theme,
    required String ctaLabel,
    required VoidCallback onPrimaryTap,
    String? validationCaption,
    bool showTopHairline = true,
  }) {
    return Container(
      padding: showTopHairline
          ? const EdgeInsets.only(top: 14)
          : const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (validationCaption != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                validationCaption,
                style: AppTypography.caption.copyWith(
                  color: theme.textCoral,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: TextButton(
                  onPressed: () async {
                    final shouldPop = await _onWillPop();
                    if (shouldPop && mounted) {
                      BackNavigation.handleBack(context, currentPath: '/add');
                    }
                  },
                  child: Text(
                    'Cancel',
                    style: AppTypography.button.copyWith(color: theme.muted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360, minHeight: 48),
                  child: GradientPrimaryButton(
                    height: 48,
                    label: ctaLabel,
                    isLoading: _isSaving && !_showSavedSuccess,
                    icon: _showSavedSuccess
                        ? Icon(Icons.check_circle_rounded,
                            color: theme.onNavy, size: 20)
                        : null,
                    onPressed: _isSaving ? null : onPrimaryTap,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
    final effective = ref.watch(effectiveExperienceProvider);
    final profile = ref.watch(deviceProfileProvider);
    final layout = AdaptiveLayout.of(context);
    final isDesktopWeb = effective == EffectiveExperience.web && layout != LayoutClass.compact;
    final hideScanReceipt = profile.isDesktop && effective == EffectiveExperience.web;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final double desktopDialogMaxHeight = math.max(320.0, viewportHeight - 48.0);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () async {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            BackNavigation.handleBack(context, currentPath: '/add');
          }
        },
      },
      child: PopScope(
      canPop: !_hasUnsavedChanges(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          BackNavigation.handleBack(context, currentPath: '/add');
        }
      },
      child: Scaffold(
        backgroundColor: theme.transparent,
        resizeToAvoidBottomInset: true,
        body: AuroraBackground(
          child: SafeArea(
            child: isDesktopWeb
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: 960,
                          maxHeight: desktopDialogMaxHeight,
                        ),
                        child: GlassSurface(
                          level: GlassLevel.level2,
                          borderRadius: 24,
                          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Header Row: title left + close button right
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    widget.initialExpense != null ? 'Edit expense' : 'New expense',
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontBrand,
                                      fontFamilyFallback: AppTypography.brandFallback,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: theme.ink,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    color: theme.muted,
                                    tooltip: 'Close (Esc)',
                                    onPressed: () async {
                                      final shouldPop = await _onWillPop();
                                      if (shouldPop && context.mounted) {
                                        BackNavigation.handleBack(context, currentPath: '/add');
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // GlassSegmented: Quick | Manual
                              GlassSegmented<int>(
                                values: const [0, 1],
                                labels: const ['Quick', 'Manual'],
                                selectedValue: _selectedTab,
                                onValueChanged: (idx) {
                                  setState(() {
                                    _selectedTab = idx;
                                    _attemptedSave = false;
                                  });
                                  if (idx == 0) {
                                    _quickFocusNode.requestFocus();
                                  } else {
                                    _amountFocusNode.requestFocus();
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              Flexible(
                                child: _selectedTab == 0
                                    ? _buildQuickDesktopTwoPane(people, groups, allExpenses, currentGroup, hideScanReceipt: hideScanReceipt)
                                    : _buildManualDesktopTwoPane(people, groups, currentGroup, hideScanReceipt: hideScanReceipt),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Top Bar: Glass circular close button + title via ScreenHeader
                      ScreenHeader(
                        title: widget.initialExpense != null
                            ? 'Edit expense'
                            : 'New expense',
                        leading: Semantics(
                          button: true,
                          label: 'Close',
                          child: GlassSurface(
                            level: GlassLevel.level1,
                            borderRadius: 999,
                            padding: const EdgeInsets.all(8),
                            onTap: () async {
                              final shouldPop = await _onWillPop();
                              if (shouldPop && context.mounted) {
                                BackNavigation.handleBack(context, currentPath: '/add');
                              }
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: theme.ink,
                              size: 20,
                            ),
                          ),
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
                            setState(() {
                              _selectedTab = idx;
                              _attemptedSave = false;
                            });
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
                            ? _buildQuickTab(people, groups, allExpenses, currentGroup, hideScanReceipt: hideScanReceipt)
                            : _buildManualTab(people, groups, currentGroup, hideScanReceipt: hideScanReceipt),
                      ),
                    ],
                  ),
          ),
    ),
  ),
),
);
  }

  Widget _buildQuickDesktopTwoPane(
    List<Person> people,
    List<Group> groups,
    List<Expense> allExpenses,
    Group currentGroup, {
    required bool hideScanReceipt,
  }) {
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
    final String ctaLabel = _quickCtaLabel(parseResult, currentGroup);

    final repeatSuggestions = RepeatSuggestionEngine.getRepeatSuggestions(
      expenses: allExpenses,
      currentUserId: SeedData.currentUserId,
    );

    final currentExample = _placeholderExamples[_exampleIndex];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Composer + Suggestions
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassSurface(
                        key: _quickFieldKey,
                        level: GlassLevel.level2,
                        borderRadius: 20,
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
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 100),
                              child: Stack(
                                children: [
                                  if (_quickTextController.text.isEmpty)
                                    IgnorePointer(
                                      child: Text(
                                        currentExample,
                                        style: AppTypography.titleLarge.copyWith(
                                          color: theme.tertiary.withValues(alpha: 0.5),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  TextField(
                                    controller: _quickTextController,
                                    focusNode: _quickFocusNode,
                                    maxLines: 4,
                                    minLines: 3,
                                    style: AppTypography.titleLarge.copyWith(
                                      color: theme.ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
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
                            Divider(height: 16, color: theme.hairline),
                            Row(
                              children: [
                                if (!hideScanReceipt) ...[
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => ScanSheet.show(
                                        context,
                                        onPasteSms: _pasteFromClipboard,
                                        onTypeInstead: () {
                                          setState(() => _selectedTab = 1);
                                          _amountFocusNode.requestFocus();
                                        },
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(minHeight: 44),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.document_scanner_outlined, size: 18, color: theme.ink),
                                            const SizedBox(width: 8),
                                            Text('Scan receipt', style: AppTypography.caption.copyWith(color: theme.ink, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(width: 1, height: 24, color: theme.hairline),
                                ],
                                Expanded(
                                  child: InkWell(
                                    onTap: _pasteFromClipboard,
                                    borderRadius: BorderRadius.circular(12),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(minHeight: 44),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.content_paste_rounded, size: 18, color: theme.ink),
                                          const SizedBox(width: 8),
                                          Text('Paste SMS', style: AppTypography.caption.copyWith(color: theme.ink, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (repeatSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'REPEAT RECENT EXPENSES',
                          style: AppTypography.sectionLabel.copyWith(
                            color: theme.secondary,
                            letterSpacing: 0.8,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: repeatSuggestions.map((item) {
                            return InkWell(
                              onTap: () {
                                _quickTextController.text = item.displayTitle;
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.hairline),
                                ),
                                child: Text(item.displayTitle, style: AppTypography.caption.copyWith(color: theme.ink, fontWeight: FontWeight.w600)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Right Pane: Draft Card Preview
              Expanded(
                flex: 5,
                child: GlassSurface(
                  level: GlassLevel.level1,
                  borderRadius: 20,
                  padding: const EdgeInsets.all(20),
                  child: hasValidExpense
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DRAFT EXPENSE',
                              style: AppTypography.sectionLabel.copyWith(
                                color: theme.muted,
                                letterSpacing: 0.8,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              CurrencyFormatter.formatPaise(parseResult.amountPaise!, absolute: true),
                              style: TextStyle(
                                fontFamily: AppTypography.fontFamily,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: theme.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              parseResult.description,
                              style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
                            ),
                            const SizedBox(height: 16),
                            _buildLiveParsePreview(parseResult, theme, groups),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 40, color: theme.muted.withValues(alpha: 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'Type what you spent\non the left',
                                textAlign: TextAlign.center,
                                style: AppTypography.body.copyWith(color: theme.muted),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),

        // Footer Actions separated by hairline
        const SizedBox(height: 12),
        _buildPinnedFooter(
          theme: theme,
          ctaLabel: ctaLabel,
          validationCaption: (_attemptedSave && !hasValidExpense)
              ? 'Add an amount to continue'
              : null,
          onPrimaryTap: () => _submitQuick(parseResult),
        ),
      ],
    );
  }

  Widget _buildManualDesktopTwoPane(
    List<Person> people,
    List<Group> groups,
    Group currentGroup, {
    required bool hideScanReceipt,
  }) {
    final theme = context.settliv;
    final bool isPersonalMode = currentGroup.isPersonal;
    final sharedGroups = groups.where((g) => !g.isPersonal).toList();
    final int? enteredPaise = CurrencyFormatter.parseToPaise(_amountController.text);
    final int amountPaise = enteredPaise ?? 0;
    final validation = _validateManualSplit(amountPaise);

    final String buttonLabel = _manualCtaLabel(amountPaise, currentGroup);

    final payer = people.firstWhere(
      (p) => p.id == _paidById,
      orElse: () => people.first,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Amount hero, Description, Date, Category
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount Hero
                      Center(
                        key: _amountFieldKey,
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
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                                ],
                                style: AppTypography.heroMoney.copyWith(
                                  fontSize: 48,
                                  color: theme.ink,
                                  letterSpacing: -1.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: '0',
                                  hintStyle: AppTypography.heroMoney.copyWith(
                                    fontSize: 48,
                                    color: theme.tertiary.withValues(alpha: 0.35),
                                    letterSpacing: -1.5,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _submitManual(amountPaise, validation),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description
                      GlassSurface(
                        level: GlassLevel.level1,
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: TextField(
                          controller: _descriptionController,
                          focusNode: _descFocusNode,
                          maxLength: 60,
                          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                          style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
                          decoration: InputDecoration(
                            hintText: 'What was this for? (optional)',
                            hintStyle: AppTypography.body.copyWith(color: theme.tertiary),
                            border: InputBorder.none,
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submitManual(amountPaise, validation),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Category Grid
                      _buildCategoryGrid(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),

              // Right Pane: Group, Payer, Participants, Split Mode
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Shared | Personal toggle
                      GlassSegmented<String>(
                        values: const ['shared', 'personal'],
                        labels: const ['Shared', 'Personal'],
                        selectedValue: isPersonalMode ? 'personal' : 'shared',
                        onValueChanged: (mode) {
                          if (mode == 'personal') {
                            final personalGroup = groups.firstWhere((g) => g.isPersonal, orElse: () => groups.first);
                            setState(() {
                              _selectedGroupId = personalGroup.id;
                              _initMembersForGroup();
                            });
                          } else {
                            final firstShared = sharedGroups.isNotEmpty ? sharedGroups.first : groups.first;
                            setState(() {
                              _selectedGroupId = firstShared.id;
                              _initMembersForGroup();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Group selector
                      if (!isPersonalMode) ...[
                        InkWell(
                          onTap: () => _showGroupSelectorSheet(context, sharedGroups),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.hairline),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.group_work_outlined, size: 18, color: theme.accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    currentGroup.name,
                                    style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 18, color: theme.muted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Paid by
                        InkWell(
                          onTap: () => _openPaidByPickerSheet(people),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: theme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: theme.hairline),
                            ),
                            child: Row(
                              children: [
                                PersonAvatar(person: payer, size: 24, showRing: false),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Paid by ${payer.id == SeedData.currentUserId ? "you" : payer.name}',
                                    style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, size: 18, color: theme.muted),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Split mode: Equal | Exact | Percent
                        GlassSegmented<int>(
                          values: const [0, 1, 2],
                          labels: const ['Equal', 'Exact', 'Percent'],
                          selectedValue: _splitMode.index,
                          onValueChanged: (idx) => setState(() => _splitMode = SplitMode.values[idx]),
                        ),
                        const SizedBox(height: 12),
                        _buildSplitModeContent(people, amountPaise),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Footer Actions separated by hairline
        const SizedBox(height: 12),
        _buildPinnedFooter(
          theme: theme,
          ctaLabel: buttonLabel,
          validationCaption: (_attemptedSave && !validation.isValid)
              ? validation.errorMessage
              : null,
          onPrimaryTap: () => _submitManual(amountPaise, validation),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 1. QUICK TAB
  // ---------------------------------------------------------------------------

  Widget _buildQuickTab(
    List<Person> people,
    List<Group> groups,
    List<Expense> allExpenses,
    Group currentGroup, {
    required bool hideScanReceipt,
  }) {
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
    final String ctaLabel = _quickCtaLabel(parseResult, currentGroup);

    // Repeat suggestions for descriptions logged 3+ times
    final repeatSuggestions = RepeatSuggestionEngine.getRepeatSuggestions(
      expenses: allExpenses,
      currentUserId: SeedData.currentUserId,
    );

    final currentExample = _placeholderExamples[_exampleIndex];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              // Composer Card with cycling placeholder and "Use this" button
              GlassSurface(
                key: _quickFieldKey,
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
                    _buildLiveParsePreview(parseResult, theme, groups),
                  ],

                  // Slim input-tools row inside composer card separated by hairline
                  Divider(height: 16, color: theme.hairline),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        if (!hideScanReceipt) ...[
                          Expanded(
                            child: InkWell(
                              onTap: () => ScanSheet.show(
                                context,
                                onPasteSms: _pasteFromClipboard,
                                onTypeInstead: () {
                                  setState(() => _selectedTab = 1);
                                  _amountFocusNode.requestFocus();
                                },
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 48),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.document_scanner_outlined, size: 18, color: theme.ink),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Scan receipt',
                                          style: AppTypography.caption.copyWith(
                                            color: theme.ink,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 24, color: theme.hairline),
                        ],
                        Expanded(
                          child: InkWell(
                            onTap: _pasteFromClipboard,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.content_paste_rounded, size: 18, color: theme.ink),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Paste SMS',
                                        style: AppTypography.caption.copyWith(
                                          color: theme.ink,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
        ),
        _buildPinnedFooter(
          theme: theme,
          ctaLabel: ctaLabel,
          showTopHairline: false,
          validationCaption: (_attemptedSave && !hasValidExpense)
              ? 'Add an amount to continue'
              : null,
          onPrimaryTap: () => _submitQuick(parseResult),
        ),
      ],
    );
  }

  /// Live parse preview under the quick input field: plain small text rows, not capsules.
  Widget _buildLiveParsePreview(
      QuickParseResult result, SettlivThemeExtension theme, List<Group> groups) {
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
        InkWell(
          onTap: () => _showGroupSelectorSheet(context, groups),
          borderRadius: BorderRadius.circular(8),
          child: _buildPreviewRow(
            icon: Icons.group_work_outlined,
            label: 'Group',
            value: result.inferredGroup != null
                ? '${result.inferredGroup!.name} (tap to change)'
                : 'Select space ›',
            theme: theme,
          ),
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
          Icon(icon, size: 14, color: theme.navy),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontFamily: AppTypography.fontBody,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.secondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: AppTypography.fontBody,
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
                    Icon(Icons.replay_rounded,
                        size: 16, color: theme.navy),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${s.displayTitle} (${CurrencyFormatter.formatPaise(s.latestAmountPaise, absolute: true)})',
                        style: TextStyle(
                          fontFamily: AppTypography.fontBody,
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
                        fontFamily: AppTypography.fontBody,
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
              icon: Icon(Icons.tune_rounded,
                  size: 16, color: theme.navy),
              label: Text(
                'Edit details in Manual',
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  color: theme.navy,
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
    Group currentGroup, {
    required bool hideScanReceipt,
  }) {
    final theme = context.settliv;
    final bool isPersonalMode = currentGroup.isPersonal;
    final sharedGroups = groups.where((g) => !g.isPersonal).toList();

    // Parse current entered amount
    final int? enteredPaise =
        CurrencyFormatter.parseToPaise(_amountController.text);
    final int amountPaise = enteredPaise ?? 0;

    // Validate manual split
    final validation = _validateManualSplit(amountPaise);
    final String buttonLabel = _manualCtaLabel(amountPaise, currentGroup);

    final payer = people.firstWhere(
      (p) => p.id == _paidById,
      orElse: () => people.first,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
            // 0. Shared | Personal toggle
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassSegmented<String>(
                values: const ['shared', 'personal'],
                labels: const ['Shared', 'Personal'],
                selectedValue: isPersonalMode ? 'personal' : 'shared',
                onValueChanged: (mode) {
                  if (mode == 'personal') {
                    final personalGroup = groups.firstWhere(
                      (g) => g.isPersonal,
                      orElse: () => groups.first,
                    );
                    setState(() {
                      _selectedGroupId = personalGroup.id;
                      _initMembersForGroup();
                    });
                  } else {
                    final firstShared = sharedGroups.isNotEmpty
                        ? sharedGroups.first
                        : groups.first;
                    setState(() {
                      _selectedGroupId = firstShared.id;
                      _initMembersForGroup();
                    });
                  }
                },
              ),
            ),

            // 1. Amount hero: digits only, max 2 decimals, live grouping + scan button
            Center(
              key: _amountFieldKey,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submitManual(amountPaise, validation),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (!hideScanReceipt) ...[
                      const SizedBox(width: 12),
                      Semantics(
                        button: true,
                        label: 'Scan receipt',
                        child: GlassSurface(
                          level: GlassLevel.level1,
                          borderRadius: 999,
                          padding: const EdgeInsets.all(10),
                          onTap: () => ScanSheet.show(context),
                          child: Icon(
                            Icons.document_scanner_rounded,
                            size: 20,
                            color: theme.navy,
                          ),
                        ),
                      ),
                    ],
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
                      fontFamily: AppTypography.fontBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textCoral,
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
                    fontFamily: AppTypography.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.textCoral,
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

            if (!isPersonalMode) ...[
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
              if (sharedGroups.length <= 3)
                GlassSegmented<String>(
                  values: sharedGroups.map((g) => g.id).toList(),
                  labels: sharedGroups.map((g) => g.name).toList(),
                  selectedValue: _selectedGroupId,
                  onValueChanged: (newId) {
                    if (_selectedGroupId != newId) {
                      setState(() {
                        _selectedGroupId = newId;
                        _initMembersForGroup();
                      });
                    }
                  },
                )
              else
                GlassSurface(
                  level: GlassLevel.level1,
                  borderRadius: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  onTap: () => _showGroupSelectorSheet(context, groups),
                  child: Row(
                    children: [
                      Icon(Icons.group_rounded, size: 20, color: theme.navy),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Group',
                              style: AppTypography.caption.copyWith(
                                color: theme.secondary,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              currentGroup.name,
                              style: AppTypography.bodySemiBold.copyWith(
                                color: theme.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: theme.secondary),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
            ],

            // Date & Paid by Row
            if (isPersonalMode)
              GlassSurface(
                level: GlassLevel.level1,
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                onTap: _openDatePickerSheet,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: theme.navy),
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
              )
            else
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
                          Icon(Icons.calendar_today_rounded,
                              size: 18, color: theme.navy),
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

            // Split with + Split mode: hidden for Personal (just me) group
            if (!currentGroup.isPersonal) ...[ 
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
                          fontFamily: AppTypography.fontBody,
                          color: theme.navy,
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
          ],
        ),
        ),
        _buildPinnedFooter(
          theme: theme,
          ctaLabel: buttonLabel,
          showTopHairline: false,
          validationCaption: (_attemptedSave && !validation.isValid)
              ? validation.errorMessage
              : null,
          onPrimaryTap: () => _submitManual(amountPaise, validation),
        ),
      ],
    );
  }

  Widget _buildCategoryGrid() {
    final theme = context.settliv;
    const categories = ExpenseCategory.values;

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
              ? theme.navy.withValues(alpha: 0.15)
              : theme.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected
              ? Border.all(color: theme.navy, width: 1.5)
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
                fontFamily: AppTypography.fontBody,
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
                    fontFamily: AppTypography.fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: diff == 0 ? theme.textEmerald : theme.secondary,
                  ),
                ),
                Text(
                  'Total: ${CurrencyFormatter.formatPaise(totalAssigned, absolute: true)} / ${CurrencyFormatter.formatPaise(totalPaise, absolute: true)}',
                  style: TextStyle(
                    fontFamily: AppTypography.fontBody,
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
                        fontFamily: AppTypography.fontBody,
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
                  fontFamily: AppTypography.fontBody,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: (diffPct.abs() < 0.01)
                      ? theme.textEmerald
                      : theme.secondary,
                ),
              ),
              Text(
                'Total: ${totalPct.toStringAsFixed(1)}% / 100%',
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
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
    final theme = context.settliv;
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
                  fontFamily: AppTypography.fontBody,
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
                  ? Icon(Icons.check_circle_rounded,
                      color: theme.navy)
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
    final theme = context.settliv;
    final repo = ref.read(appRepositoryProvider);
    final group = repo.getGroup(_selectedGroupId);
    final available = group != null
        ? people.where((p) => group.memberIds.contains(p.id)).toList()
        : people;

    GlassSheetScaffold.show(
      context: context,
      title: 'Who paid for this?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in available) ...[
            ListTile(
              leading: PersonAvatar(person: p, size: 32),
              title: Text(
                p.id == SeedData.currentUserId ? '${p.name} (You)' : p.name,
                style: TextStyle(
                  fontFamily: AppTypography.fontBody,
                  fontWeight: _paidById == p.id
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
              trailing: _paidById == p.id
                  ? Icon(Icons.check_circle_rounded,
                      color: theme.navy)
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
