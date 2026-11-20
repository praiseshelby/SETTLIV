import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../group_detail/sheets/expense_detail_sheet.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedGroupId = 'all'; // 'all' or specific groupId
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final allGroups = ref.watch(allGroupsProvider);
    final groups = allGroups.where((g) => !g.isPersonal).toList();
    final currentUserId = repo.currentUserId;

    // Filter by group and search query
    final filteredExpenses = allExpenses.where((e) {
      if (e.isDeleted) return false;
      if (_selectedGroupId != 'all' && e.groupId != _selectedGroupId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = e.title.toLowerCase().contains(query);
        final payer = repo.getPerson(e.paidBy);
        final payerMatch = payer != null && payer.name.toLowerCase().contains(query);
        if (!titleMatch && !payerMatch) return false;
      }
      return true;
    }).toList();

    // Group expenses by date header
    final Map<String, List<Expense>> grouped = {};
    for (final exp in filteredExpenses) {
      final header = DateFormatter.formatDayHeader(exp.date);
      grouped.putIfAbsent(header, () => []).add(exp);
    }

    return Scaffold(
      backgroundColor: theme.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              // Header
              Text(
                'Records',
                style: AppTypography.screenTitle.copyWith(
                  color: theme.ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'All transaction records across your groups',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),

              // Search Bar
              TextField(
                controller: _searchController,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.ink,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by description or person...',
                  hintStyle: TextStyle(
                    fontFamily: 'Manrope',
                    color: theme.muted.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.muted,
                    size: 20,
                  ),
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
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: theme.hairline),
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
              const SizedBox(height: 14),

              // Group Filter Chips (All groups + specific groups)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: 'All groups',
                      isSelected: _selectedGroupId == 'all',
                      onTap: () => setState(() => _selectedGroupId = 'all'),
                    ),
                    for (final g in groups) ...[
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: g.name,
                        isSelected: _selectedGroupId == g.id,
                        onTap: () => setState(() => _selectedGroupId = g.id),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Content: List or Empty/No-results
              if (allExpenses.isEmpty) ...[
                EmptyState(
                  title: 'No expenses yet',
                  subtitle: 'Expenses you add will show up here.',
                  action: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryButtonBg,
                      foregroundColor: theme.primaryButtonText,
                    ),
                    onPressed: () => context.push('/add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add an expense'),
                  ),
                ),
              ] else if (filteredExpenses.isEmpty) ...[
                EmptyState(
                  title: 'No matching records',
                  subtitle: 'No records matched "$_searchQuery". Try clearing your search or filter.',
                  action: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryButtonBg,
                      foregroundColor: theme.primaryButtonText,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _selectedGroupId = 'all';
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset filters'),
                  ),
                ),
              ] else ...[
                GlassSurface(
                  level: GlassLevel.level2,
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: AppTypography.caption.copyWith(
                              color: theme.muted,
                              fontSize: 11,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        for (int i = 0; i < entry.value.length; i++) ...[
                          ExpenseTile(
                            expense: entry.value[i],
                            payer: repo.getPerson(entry.value[i].paidBy),
                            group: repo.getGroup(entry.value[i].groupId),
                            currentUserId: currentUserId,
                            showDivider: i < entry.value.length - 1,
                            onTap: () {
                              ExpenseDetailSheet.show(
                                context: context,
                                expense: entry.value[i],
                                onEdit: () {
                                  context.push(
                                    '/add',
                                    extra: {'initialExpense': entry.value[i]},
                                  );
                                },
                                onDelete: () {
                                  final repoNotifier = ref.read(appStateProvider.notifier);
                                  repoNotifier.deleteExpense(entry.value[i].id);
                                  UndoSnackbar.show(
                                    context: context,
                                    message: 'Deleted ${entry.value[i].title}',
                                    onUndo: () => repoNotifier.restoreExpense(entry.value[i].id),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = context.settliv;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.navy : theme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? theme.navy : theme.hairline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? theme.onNavy : theme.ink,
            ),
          ),
        ),
      ),
    );
  }
}
