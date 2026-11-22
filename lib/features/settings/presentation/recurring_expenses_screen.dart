import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/category_badge.dart';
import '../../../core/widgets/glass_sheet_scaffold.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../data/models/expense.dart';
import '../../../data/models/recurring_template.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class RecurringExpensesScreen extends ConsumerStatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  ConsumerState<RecurringExpensesScreen> createState() =>
      _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState
    extends ConsumerState<RecurringExpensesScreen> {
  bool _isProcessing = false;

  Future<void> _processDue() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 250));

    final count = ref
        .read(appStateProvider.notifier)
        .processDueRecurringExpenses();

    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'All recurring expenses are up to date'
                : 'Generated $count new recurring expense${count > 1 ? 's' : ''}!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddTemplateSheet(BuildContext context) {
    GlassSheetScaffold.show(
      context: context,
      title: 'New recurring expense',
      isScrollControlled: true,
      child: const _AddRecurringTemplateSheet(),
    );
  }

  void _confirmDelete(BuildContext context, RecurringTemplate template) {
    final theme = context.settliv;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        title: Text(
          'Delete recurring rule?',
          style: TextStyle(color: theme.ink),
        ),
        content: Text(
          'Are you sure you want to stop repeating "${template.description}"? Past expenses will not be deleted.',
          style: TextStyle(color: theme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: theme.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(appStateProvider.notifier)
                  .deleteRecurringTemplate(template.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recurring rule removed'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Delete',
              style: TextStyle(
                color: theme.coral,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final templates = ref.watch(allRecurringTemplatesProvider);
    final groups = ref.watch(allGroupsProvider);
    final groupMap = {for (final g in groups) g.id: g.name};

    return ScreenScaffold(
      hasBottomBar: false,
      floatingActionButton: templates.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: theme.primaryButtonBg,
              foregroundColor: theme.primaryButtonText,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New recurring'),
              onPressed: () => _showAddTemplateSheet(context),
            )
          : null,
      header: ScreenHeader(
        title: 'Recurring Expenses',
        onBack: () => context.pop(),
        actions: [
          if (templates.isNotEmpty)
            IconButton(
              tooltip: 'Process due now',
              onPressed: _isProcessing ? null : _processDue,
              icon: _isProcessing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.navy,
                      ),
                    )
                  : Icon(Icons.sync_rounded, color: theme.ink),
            ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: templates.isEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: theme.navy.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.repeat_rounded,
                          size: 36,
                          color: theme.navy,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'No recurring expenses',
                        style: AppTypography.titleLarge.copyWith(
                          color: theme.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set up repeating bills, monthly rent, and subscriptions. Settliv will automatically log and split them when due.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: theme.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Add recurring expense',
                        onPressed: () => _showAddTemplateSheet(context),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                children: [
                  // Action Banner
                  GlassSurface(
                    level: GlassLevel.level1,
                    borderRadius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.emerald.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_mode_rounded,
                            color: theme.textEmerald,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Engine Active',
                                style: AppTypography.caption.copyWith(
                                  color: theme.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${templates.where((t) => !t.isPaused).length} active recurring rules',
                                style: AppTypography.caption.copyWith(
                                  color: theme.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _isProcessing ? null : _processDue,
                          child: _isProcessing
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.navy,
                                  ),
                                )
                              : Text(
                                  'Check due',
                                  style: AppTypography.caption.copyWith(
                                    color: theme.navy,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'RECURRING RULES',
                    style: AppTypography.caption.copyWith(
                      color: theme.muted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  for (final template in templates) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassSurface(
                        level: GlassLevel.level1,
                        borderRadius: 20,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CategoryTile(
                                  category: template.category,
                                  size: 42,
                                  iconSize: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        template.description,
                                        style: AppTypography.body.copyWith(
                                          color: theme.ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        groupMap[template.groupId] ?? 'Group',
                                        style: AppTypography.caption.copyWith(
                                          color: theme.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: !template.isPaused,
                                  activeColor: theme.navy,
                                  onChanged: (val) {
                                    ref
                                        .read(appStateProvider.notifier)
                                        .updateRecurringTemplate(
                                          template.copyWith(isPaused: !val),
                                        );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Divider(color: theme.hairline, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      CurrencyFormatter.formatPaise(
                                        template.totalPaise,
                                        absolute: true,
                                      ),
                                      style: AppTypography.heroMoney.copyWith(
                                        color: theme.ink,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      'Repeats ${template.frequency.label.toLowerCase()}',
                                      style: AppTypography.caption.copyWith(
                                        color: theme.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: template.isPaused
                                            ? theme.coral.withValues(alpha: 0.12)
                                            : theme.emerald
                                                .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        template.isPaused ? 'Paused' : 'Active',
                                        style: AppTypography.caption.copyWith(
                                          color: template.isPaused
                                              ? theme.textCoral
                                              : theme.textEmerald,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () =>
                                          _confirmDelete(context, template),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                          color: theme.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (template.lastGeneratedDate != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Last logged: ${DateFormatter.formatRelative(template.lastGeneratedDate!)}',
                                style: AppTypography.caption.copyWith(
                                  color: theme.secondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
        ),
      ],
    );
  }
}

class _AddRecurringTemplateSheet extends ConsumerStatefulWidget {
  const _AddRecurringTemplateSheet();

  @override
  ConsumerState<_AddRecurringTemplateSheet> createState() =>
      _AddRecurringTemplateSheetState();
}

class _AddRecurringTemplateSheetState
    extends ConsumerState<_AddRecurringTemplateSheet> {
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.bills;
  RecurringFrequency _frequency = RecurringFrequency.monthly;
  String? _selectedGroupId;
  String? _error;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onCreate() {
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      setState(() => _error = 'Please enter a description');
      return;
    }

    final paise = CurrencyFormatter.parseToPaise(_amountController.text) ?? 0;
    if (paise <= 0) {
      setState(() => _error = 'Please enter a valid amount');
      return;
    }

    final groups = ref.read(allGroupsProvider);
    final group = groups.firstWhere(
      (g) => g.id == _selectedGroupId,
      orElse: () => groups.first,
    );

    final repo = ref.read(appRepositoryProvider);
    final currentUserId = repo.currentUserId;

    final template = RecurringTemplate(
      id: 'rec_tmpl_${DateTime.now().millisecondsSinceEpoch}',
      groupId: group.id,
      description: desc,
      category: _category,
      totalPaise: paise,
      payers: [PayerShare(personId: currentUserId, paise: paise)],
      splitMode: SplitMode.equal,
      participants: group.memberIds,
      frequency: _frequency,
      startDate: DateTime.now(),
    );

    ref.read(appStateProvider.notifier).addRecurringTemplate(template);
    // Auto-process to log immediately if due
    ref.read(appStateProvider.notifier).processDueRecurringExpenses();

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Recurring expense "${template.description}" created'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final groups = ref.watch(allGroupsProvider);
    if (_selectedGroupId == null && groups.isNotEmpty) {
      _selectedGroupId = groups.first.id;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Description
          Text(
            'DESCRIPTION',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            autofocus: true,
            style: TextStyle(color: theme.ink),
            decoration: InputDecoration(
              hintText: 'e.g. House Rent, WiFi, Netflix',
              hintStyle: TextStyle(color: theme.muted),
              filled: true,
              fillColor: theme.raised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Amount
          Text(
            'AMOUNT',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: theme.ink, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: TextStyle(color: theme.muted),
              hintText: '0',
              hintStyle: TextStyle(color: theme.muted),
              filled: true,
              fillColor: theme.raised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Group Picker
          Text(
            'GROUP',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g.isPersonal ? 'Personal' : g.name),
                      selected: _selectedGroupId == g.id,
                      selectedColor: theme.navy.withValues(alpha: 0.15),
                      backgroundColor: theme.raised,
                      labelStyle: TextStyle(
                        color: _selectedGroupId == g.id ? theme.ink : theme.muted,
                        fontWeight: _selectedGroupId == g.id
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedGroupId = g.id);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Frequency Picker
          Text(
            'FREQUENCY',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final freq in RecurringFrequency.values) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text(
                        freq.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _frequency == freq
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: _frequency == freq ? theme.ink : theme.muted,
                        ),
                      ),
                      selected: _frequency == freq,
                      selectedColor: theme.navy.withValues(alpha: 0.15),
                      backgroundColor: theme.raised,
                      onSelected: (val) {
                        if (val) setState(() => _frequency = freq);
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Category Picker
          Text(
            'CATEGORY',
            style: AppTypography.caption.copyWith(
              color: theme.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final cat in ExpenseCategory.values) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: CategoryTile(category: cat, size: 20, iconSize: 11),
                      label: Text(cat.label, style: const TextStyle(fontSize: 12)),
                      selected: _category == cat,
                      selectedColor: theme.navy.withValues(alpha: 0.15),
                      backgroundColor: theme.raised,
                      labelStyle: TextStyle(
                        color: _category == cat ? theme.ink : theme.muted,
                        fontWeight:
                            _category == cat ? FontWeight.w700 : FontWeight.w500,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _category = cat);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(color: theme.textCoral, fontSize: 12),
            ),
          ],

          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Save recurring rule',
            onPressed: _onCreate,
          ),
        ],
      ),
    );
  }
}
