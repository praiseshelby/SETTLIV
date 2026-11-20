import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/section_card.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  static const String _kMonthlyBudgetPrefsKey = 'settliv_plan_monthly_budget';
  static const String _kCategoryLimitsPrefsKey = 'settliv_plan_category_limits';

  int _monthlyBudgetPaise = 5000000; // Default ₹50,000
  Map<ExpenseCategory, int> _categoryLimits = {
    ExpenseCategory.food: 1500000,
    ExpenseCategory.rent: 1800000,
    ExpenseCategory.travel: 500000,
    ExpenseCategory.bills: 300000,
    ExpenseCategory.fun: 400000,
    ExpenseCategory.groceries: 500000,
  };

  @override
  void initState() {
    super.initState();
    _loadBudgets();
  }

  Future<void> _loadBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBudget = prefs.getInt(_kMonthlyBudgetPrefsKey);
    final savedCatJson = prefs.getString(_kCategoryLimitsPrefsKey);

    if (savedBudget != null && savedBudget > 0) {
      _monthlyBudgetPaise = savedBudget;
    }

    if (savedCatJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedCatJson);
        final Map<ExpenseCategory, int> parsed = {};
        for (final entry in decoded.entries) {
          final cat = ExpenseCategory.values.firstWhere(
            (c) => c.name == entry.key,
            orElse: () => ExpenseCategory.other,
          );
          parsed[cat] = (entry.value as num).toInt();
        }
        if (parsed.isNotEmpty) {
          _categoryLimits = parsed;
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kMonthlyBudgetPrefsKey, _monthlyBudgetPaise);
    final jsonMap = {
      for (final entry in _categoryLimits.entries) entry.key.name: entry.value,
    };
    await prefs.setString(_kCategoryLimitsPrefsKey, jsonEncode(jsonMap));
  }

  void _openEditBudgetSheet(SettlivThemeExtension theme) {
    final overallController = TextEditingController(
      text: (_monthlyBudgetPaise / 100).round().toString(),
    );
    final Map<ExpenseCategory, TextEditingController> catControllers = {
      for (final c in _categoryLimits.keys)
        c: TextEditingController(
          text: ((_categoryLimits[c] ?? 0) / 100).round().toString(),
        ),
    };

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: theme.surfaceSolid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Edit monthly budgets',
                      style: AppTypography.titleLarge.copyWith(color: theme.ink, fontSize: 20),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.muted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Overall Monthly Budget (₹)',
                  style: AppTypography.caption.copyWith(color: theme.muted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: overallController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Category Limits',
                  style: AppTypography.eyebrow.copyWith(color: theme.muted),
                ),
                const SizedBox(height: 12),
                for (final cat in _categoryLimits.keys) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat.displayName,
                            style: AppTypography.bodySemiBold.copyWith(color: theme.ink, fontSize: 14),
                          ),
                        ),
                        SizedBox(
                          width: 140,
                          child: TextField(
                            controller: catControllers[cat],
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryButtonBg,
                    foregroundColor: theme.primaryButtonText,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final newOverall = (int.tryParse(overallController.text) ?? 50000) * 100;
                    final Map<ExpenseCategory, int> newCatLimits = {};
                    catControllers.forEach((cat, controller) {
                      newCatLimits[cat] = (int.tryParse(controller.text) ?? 0) * 100;
                    });

                    setState(() {
                      _monthlyBudgetPaise = newOverall;
                      _categoryLimits = newCatLimits;
                    });
                    _saveBudgets();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save budgets', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final currentUserId = repo.currentUserId;
    final allExpenses = ref.watch(allExpensesProvider);

    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;

    // Calculate user's share of expenses logged in the current month
    int totalSpentSoFarPaise = 0;
    final Map<ExpenseCategory, int> categorySpentPaise = {
      for (final c in ExpenseCategory.values) c: 0,
    };

    for (final exp in allExpenses) {
      if (!exp.isDeleted && exp.date.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))) {
        final share = exp.computedShares[currentUserId] ?? 0;
        totalSpentSoFarPaise += share;
        categorySpentPaise[exp.category] = (categorySpentPaise[exp.category] ?? 0) + share;
      }
    }

    final double budgetPercent = _monthlyBudgetPaise > 0
        ? (totalSpentSoFarPaise / _monthlyBudgetPaise) * 100.0
        : 0.0;

    // Status indicator: emerald on track, saffron close >=80%, coral over 100%
    final String statusLabel;
    final Color statusColor;
    if (budgetPercent > 100) {
      statusLabel = 'Over budget';
      statusColor = theme.coral;
    } else if (budgetPercent >= 80) {
      statusLabel = 'Close to limit';
      statusColor = theme.saffron;
    } else {
      statusLabel = 'On track';
      statusColor = theme.emerald;
    }

    // Projected month-end spend based on daily rate to date
    final int dailyRatePaise = currentDay > 0 ? (totalSpentSoFarPaise ~/ currentDay) : totalSpentSoFarPaise;
    final int projectedSpendPaise = dailyRatePaise * daysInMonth;

    return ScreenScaffold(
      header: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan',
                  style: AppTypography.screenTitle.copyWith(color: theme.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  'Budgets and spending limits',
                  style: AppTypography.caption.copyWith(color: theme.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.hairline),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () => _openEditBudgetSheet(theme),
            child: Text(
              'Edit limits',
              style: TextStyle(color: theme.accent, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
        children: [
          // 1. Header with monthly budget overview
          SectionCard(
            title: 'MONTHLY BUDGET',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabel,
                style: AppTypography.caption.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      CurrencyFormatter.formatPaise(totalSpentSoFarPaise),
                      style: AppTypography.moneyHero.copyWith(
                        color: theme.ink,
                        fontSize: 34,
                      ),
                    ),
                    Text(
                      'of ${CurrencyFormatter.formatPaise(_monthlyBudgetPaise)}',
                      style: AppTypography.caption.copyWith(
                        color: theme.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your share spent so far (${budgetPercent.toStringAsFixed(1)}%)',
                  style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 13),
                ),
                const SizedBox(height: 14),
                // Progress Bar with 3 states
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (budgetPercent / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: theme.hairline,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Projected month-end spend
          SectionCard(
            title: 'MONTH-END PROJECTION',
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.navy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.trending_up_rounded, color: theme.navy, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projected: ${CurrencyFormatter.formatPaise(projectedSpendPaise)}',
                        style: AppTypography.bodySemiBold.copyWith(
                          color: theme.ink,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'At current pace (~${CurrencyFormatter.formatPaise(dailyRatePaise)}/day)',
                        style: AppTypography.caption.copyWith(
                          color: theme.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Category limits: list of categories with budget, spent, remaining
          SectionCard(
            title: 'CATEGORY LIMITS',
            child: Column(
              children: [
                for (final cat in _categoryLimits.keys) ...[
                  _buildCategoryLimitRow(
                    category: cat,
                    spentPaise: categorySpentPaise[cat] ?? 0,
                    limitPaise: _categoryLimits[cat] ?? 0,
                    theme: theme,
                  ),
                  Divider(height: 1, color: theme.hairline),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryLimitRow({
    required ExpenseCategory category,
    required int spentPaise,
    required int limitPaise,
    required SettlivThemeExtension theme,
  }) {
    final double percent = limitPaise > 0 ? (spentPaise / limitPaise) * 100 : 0;
    final int remainingPaise = limitPaise - spentPaise;
    final bool isOver = remainingPaise < 0;

    final Color barColor = isOver
        ? theme.coral
        : (percent >= 80 ? theme.saffron : theme.emerald);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  category.displayName,
                  style: AppTypography.bodySemiBold.copyWith(
                    color: theme.ink,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${CurrencyFormatter.formatPaise(spentPaise)} / ${CurrencyFormatter.formatPaise(limitPaise)}',
                style: AppTypography.caption.copyWith(
                  color: theme.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isOver
                    ? 'Over by ${CurrencyFormatter.formatPaise(remainingPaise.abs())}'
                    : '${CurrencyFormatter.formatPaise(remainingPaise)} remaining',
                style: AppTypography.caption.copyWith(
                  color: isOver ? theme.textCoral : theme.muted,
                  fontSize: 12,
                ),
              ),
              Text(
                '${percent.toStringAsFixed(0)}%',
                style: AppTypography.caption.copyWith(
                  color: barColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: theme.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
