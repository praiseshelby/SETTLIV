import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/expense.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../../group_detail/presentation/widgets/category_donut_chart.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final allExpenses = ref.watch(allExpensesProvider);
    final allGroups = ref.watch(allGroupsProvider);

    // Compute category spend across all active expenses
    final Map<ExpenseCategory, int> categorySpend = {
      for (final c in ExpenseCategory.values) c: 0,
    };
    int totalSpend = 0;

    for (final exp in allExpenses) {
      if (!exp.isDeleted) {
        totalSpend += exp.totalPaise;
        categorySpend[exp.category] = (categorySpend[exp.category] ?? 0) + exp.totalPaise;
      }
    }

    final activeEntries = categorySpend.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: theme.canvas,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insights',
                      style: AppTypography.screenTitle.copyWith(color: theme.ink),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Overall spending and analytics',
                      style: AppTypography.caption.copyWith(color: theme.muted),
                    ),
                  ],
                ),
              ),
            ),
            if (allExpenses.isEmpty || totalSpend <= 0)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.insights_outlined,
                  title: 'No spending insights yet',
                  message: 'Add expenses to see category breakdowns and monthly analytics.',
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Total Spend Card
                      GlassSurface(
                        level: GlassLevel.level1,
                        borderRadius: 24,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Recorded Spend',
                              style: AppTypography.caption.copyWith(
                                color: theme.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              CurrencyFormatter.formatPaise(totalSpend),
                              style: AppTypography.moneyLarge.copyWith(
                                color: theme.ink,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Across ${allGroups.where((g) => !g.isPersonal).length} shared groups & ${allExpenses.length} transactions',
                              style: AppTypography.caption.copyWith(color: theme.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Donut Chart
                      CategoryDonutChart(
                        categorySpend: categorySpend,
                        totalSpend: totalSpend,
                      ),
                      const SizedBox(height: 20),
                      // Category Breakdown List
                      GlassSurface(
                        level: GlassLevel.level1,
                        borderRadius: 24,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Top Categories',
                              style: AppTypography.sectionHeader.copyWith(
                                color: theme.ink,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (int i = 0; i < activeEntries.length; i++) ...[
                              Builder(
                                builder: (context) {
                                  final entry = activeEntries[i];
                                  final pct = totalSpend > 0 ? (entry.value / totalSpend) : 0.0;
                                  final colors = CategoryDonutChart.buildCategoryColors(theme);
                                  final color = colors[entry.key] ?? theme.muted;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              entry.key.label,
                                              style: AppTypography.body.copyWith(
                                                color: theme.ink,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              CurrencyFormatter.formatPaise(entry.value),
                                              style: AppTypography.body.copyWith(
                                                color: theme.ink,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: pct,
                                            backgroundColor: theme.hairline,
                                            valueColor: AlwaysStoppedAnimation(color),
                                            minHeight: 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Bottom padding for docked nav bar
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
