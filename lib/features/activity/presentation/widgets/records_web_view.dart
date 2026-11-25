import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/layout/adaptive_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/category_palette.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/name_normalizer.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/expense_tile.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/expense.dart';
import '../../../../data/models/group.dart';
import '../../../../data/models/settlement.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../../../group_detail/sheets/expense_detail_sheet.dart';

class RecordsWebView extends ConsumerStatefulWidget {
  const RecordsWebView({super.key});

  @override
  ConsumerState<RecordsWebView> createState() => _RecordsWebViewState();
}

class _RecordsWebViewState extends ConsumerState<RecordsWebView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedGroupId = 'all';
  ExpenseCategory? _selectedCategory;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilterDialog(BuildContext context, List<Group> groups, SettlivThemeExtension theme) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        String tempGroupId = _selectedGroupId;
        ExpenseCategory? tempCategory = _selectedCategory;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Dialog(
                  backgroundColor: theme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: theme.hairline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Filter Records',
                              style: AppTypography.titleLarge.copyWith(color: theme.ink, fontSize: 18),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              color: theme.muted,
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Group filter
                        Text('GROUP', style: AppTypography.eyebrow.copyWith(color: theme.muted)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip(
                              label: 'All groups',
                              isSelected: tempGroupId == 'all',
                              onTap: () => setDialogState(() => tempGroupId = 'all'),
                              theme: theme,
                            ),
                            ...groups.map((g) => _buildFilterChip(
                                  label: g.name,
                                  isSelected: tempGroupId == g.id,
                                  onTap: () => setDialogState(() => tempGroupId = g.id),
                                  theme: theme,
                                )),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Category filter
                        Text('CATEGORY', style: AppTypography.eyebrow.copyWith(color: theme.muted)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip(
                              label: 'All categories',
                              isSelected: tempCategory == null,
                              onTap: () => setDialogState(() => tempCategory = null),
                              theme: theme,
                            ),
                            ...ExpenseCategory.values.map((cat) => _buildFilterChip(
                                  label: cat.displayName,
                                  isSelected: tempCategory == cat,
                                  onTap: () => setDialogState(() => tempCategory = cat),
                                  theme: theme,
                                )),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedGroupId = 'all';
                                  _selectedCategory = null;
                                });
                                Navigator.pop(ctx);
                              },
                              child: Text('Reset', style: TextStyle(color: theme.muted)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.primaryButtonBg,
                                foregroundColor: theme.primaryButtonText,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedGroupId = tempGroupId;
                                  _selectedCategory = tempCategory;
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required SettlivThemeExtension theme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.accent.withValues(alpha: 0.15) : theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.accent : theme.hairline,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? theme.accent : theme.ink,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final layout = AdaptiveLayout.of(context);
    final isCompact = layout == LayoutClass.compact;

    final repo = ref.watch(appRepositoryProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final allSettlements = ref.watch(allSettlementsProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final sharedGroups = allGroups.where((g) => !g.isPersonal && !g.isArchived).toList();
    final currentUserId = repo.currentUserId;

    // Filter
    final filtered = allExpenses.where((e) {
      if (e.isDeleted) return false;
      if (_selectedGroupId != 'all' && e.groupId != _selectedGroupId) return false;
      if (_selectedCategory != null && e.category != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final titleMatch = e.title.toLowerCase().contains(q);
        final payer = repo.getPerson(e.paidBy);
        final payerMatch = payer != null && payer.name.toLowerCase().contains(q);
        if (!titleMatch && !payerMatch) return false;
      }
      return true;
    }).toList();

    final filteredSettlements = _selectedCategory != null
        ? <Settlement>[]
        : allSettlements.where((s) {
            if (s.isDeleted) return false;
            if (_selectedGroupId != 'all' && s.groupId != _selectedGroupId) return false;
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final payer = repo.getPerson(s.from)?.name.toLowerCase() ?? '';
              final payee = repo.getPerson(s.to)?.name.toLowerCase() ?? '';
              if (!payer.contains(q) && !payee.contains(q) && !'paid'.contains(q)) {
                return false;
              }
            }
            return true;
          }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final hasActiveFilter = _selectedGroupId != 'all' || _selectedCategory != null || _searchQuery.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16 : 32,
        vertical: 24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Toolbar (Search, Filter Button)
              _buildToolbar(context, theme, sharedGroups),
              const SizedBox(height: 12),

              // 2. Summary line with Clear filters
              _buildSummaryLine(context, theme, filtered.length + filteredSettlements.length, hasActiveFilter),
              const SizedBox(height: 16),

              if (filteredSettlements.isNotEmpty) ...[
                _buildSettlementsCard(theme, filteredSettlements, repo, currentUserId),
                const SizedBox(height: 16),
              ],

              // 3. Table or Cards
              if (filtered.isEmpty && filteredSettlements.isEmpty)
                _buildEmptyState(theme, hasActiveFilter)
              else if (isCompact)
                // Compact Web: Card list
                _buildCompactCards(context, theme, filtered, currentUserId)
              else
                // Expanded / Medium: Full-width Table
                _buildFullWidthTable(context, theme, filtered, repo, currentUserId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, SettlivThemeExtension theme, List<Group> groups) {
    return Row(
      children: [
        // Search Box
        Expanded(
          child: TextField(
            controller: _searchController,
            style: TextStyle(fontFamily: AppTypography.fontBody, fontSize: 14, color: theme.ink),
            decoration: InputDecoration(
              hintText: 'Search by description or person...',
              hintStyle: TextStyle(fontFamily: AppTypography.fontBody, color: theme.muted, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: theme.muted, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18, color: theme.muted),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: theme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.hairline)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.hairline)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.accent)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
          ),
        ),
        const SizedBox(width: 12),
        // Filter button
        ElevatedButton.icon(
          onPressed: () => _openFilterDialog(context, groups, theme),
          icon: Icon(Icons.tune_rounded, size: 18, color: theme.ink),
          label: Text('Filters', style: TextStyle(color: theme.ink, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.surface,
            elevation: 0,
            side: BorderSide(color: theme.hairline),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryLine(BuildContext context, SettlivThemeExtension theme, int count, bool hasActiveFilter) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing $count ${count == 1 ? 'record' : 'records'}',
          style: AppTypography.caption.copyWith(color: theme.muted, fontWeight: FontWeight.w500),
        ),
        if (hasActiveFilter)
          InkWell(
            onTap: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _selectedGroupId = 'all';
                _selectedCategory = null;
              });
            },
            child: Text(
              'Clear filters',
              style: AppTypography.caption.copyWith(color: theme.accent, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(SettlivThemeExtension theme, bool hasActiveFilter) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: EmptyState(
        title: hasActiveFilter ? 'No matching records' : 'No records yet',
        subtitle: hasActiveFilter
            ? 'Try adjusting your search query or filter options.'
            : 'Expenses logged in groups or personal space will appear here.',
        action: hasActiveFilter
            ? TextButton(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _searchQuery = '';
                    _selectedGroupId = 'all';
                    _selectedCategory = null;
                  });
                },
                child: Text('Reset all filters', style: TextStyle(color: theme.accent, fontWeight: FontWeight.w700)),
              )
            : null,
      ),
    );
  }

  Widget _buildFullWidthTable(
    BuildContext context,
    SettlivThemeExtension theme,
    List<Expense> expenses,
    dynamic repo,
    String currentUserId,
  ) {
    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3.5), // Description
          1: FlexColumnWidth(2.2), // Group
          2: FlexColumnWidth(2.2), // Paid by
          3: FlexColumnWidth(1.8), // Date
          4: FlexColumnWidth(2.0), // Category
          5: FlexColumnWidth(2.2), // Total
          6: FlexColumnWidth(2.2), // Your share
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          // Sticky header
          TableRow(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.hairline, width: 1)),
            ),
            children: [
              _buildHeaderCell('Description', theme),
              _buildHeaderCell('Group', theme),
              _buildHeaderCell('Paid by', theme),
              _buildHeaderCell('Date', theme),
              _buildHeaderCell('Category', theme),
              _buildHeaderCell('Total', theme, alignRight: true),
              _buildHeaderCell('Your share', theme, alignRight: true),
            ],
          ),
          ...expenses.map((exp) {
            final group = repo.getGroup(exp.groupId);
            final yourShare = exp.shares[currentUserId] ?? 0;
            final payer = repo.getPerson(exp.paidBy);
            final payerName = NameNormalizer.formatPayer(
              payerId: exp.paidBy,
              currentUserId: currentUserId,
              fallbackName: payer?.name ?? 'Unknown',
            );
            final colors = CategoryPalette.getColors(exp.category, isDark: theme.isDark);

            return TableRow(
              children: [
                // Description with icon
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => ExpenseDetailSheet.show(
                      context: context,
                      expense: exp,
                      onEdit: () {},
                      onDelete: () {},
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.tile,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(CategoryPalette.getIcon(exp.category), size: 16, color: colors.icon),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            exp.title,
                            style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Group
                Text(group?.name ?? 'Direct', style: AppTypography.body.copyWith(color: theme.muted)),
                // Paid by
                Text(payerName, style: AppTypography.body.copyWith(color: theme.ink)),
                // Date
                Text(DateFormat('d MMM yyyy').format(exp.date), style: AppTypography.caption.copyWith(color: theme.muted)),
                // Category
                Text(exp.category.displayName, style: AppTypography.caption.copyWith(color: colors.icon, fontWeight: FontWeight.w600)),
                // Total
                Text(
                  CurrencyFormatter.formatPaise(exp.totalPaise),
                  style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w700, color: theme.ink),
                  textAlign: TextAlign.right,
                ),
                // Your share
                Text(
                  CurrencyFormatter.formatPaise(yourShare),
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontWeight: FontWeight.w700,
                    color: yourShare > 0 ? theme.ink : theme.muted,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactCards(BuildContext context, SettlivThemeExtension theme, List<Expense> expenses, String currentUserId) {
    return Column(
      children: expenses.map((exp) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ExpenseTile(
            expense: exp,
            currentUserId: currentUserId,
            onTap: () => ExpenseDetailSheet.show(
              context: context,
              expense: exp,
              onEdit: () {},
              onDelete: () {},
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettlementsCard(
    SettlivThemeExtension theme,
    List<Settlement> settlements,
    dynamic repo,
    String currentUserId,
  ) {
    return GlassSurface(
      level: GlassLevel.level2,
      borderRadius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SETTLEMENTS', style: AppTypography.eyebrow.copyWith(color: theme.muted)),
          const SizedBox(height: 10),
          for (int i = 0; i < settlements.length; i++) ...[
            Builder(builder: (context) {
              final s = settlements[i];
              final payer = s.from == currentUserId
                  ? 'You'
                  : (repo.getPerson(s.from)?.name ?? 'Someone');
              final payee = s.to == currentUserId
                  ? 'you'
                  : (repo.getPerson(s.to)?.name ?? 'Someone');
              final group = repo.getGroup(s.groupId);
              final amountStr = CurrencyFormatter.formatPaise(s.paise, absolute: true);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.emerald.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_rounded, size: 16, color: theme.textEmerald),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$payer paid $payee $amountStr · ${s.method.label}',
                        style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
                      ),
                    ),
                    Text(
                      '${group?.name ?? 'Group'} · ${DateFormat('d MMM').format(s.date)}',
                      style: AppTypography.caption.copyWith(color: theme.muted),
                    ),
                  ],
                ),
              );
            }),
            if (i < settlements.length - 1) Divider(height: 1, color: theme.hairline),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, SettlivThemeExtension theme, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: theme.muted,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
      ),
    );
  }
}
