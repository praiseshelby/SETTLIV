import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/balance_hero_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/floating_add_button.dart';
import '../../../core/widgets/group_card.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/models/expense.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../group_detail/sheets/expense_detail_sheet.dart';
import 'widgets/quick_add_bar.dart';
import 'widgets/user_profile_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;
  String? _highlightedExpenseId;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  String _getTimeGreeting(String name) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning, $name';
    } else if (hour < 17) {
      return 'Good afternoon, $name';
    } else {
      return 'Good evening, $name';
    }
  }

  void _triggerHighlight(String id) {
    setState(() => _highlightedExpenseId = id);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _highlightedExpenseId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final overall = ref.watch(userOverallBalanceProvider);
    final groups = ref.watch(allGroupsProvider);
    final people = ref.watch(allPeopleProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final currentUser = repo.currentUser;

    // Latest 8 active expenses grouped by day
    final recentExpenses = allExpenses.take(8).toList();

    return Scaffold(
      backgroundColor: theme.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. Header: Greeting + User Avatar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getTimeGreeting(currentUser?.name ?? 'Arjun'),
                        style: AppTypography.titleLarge.copyWith(
                          color: theme.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Here's where you stand",
                        style: AppTypography.caption.copyWith(
                          color: theme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'User profile and theme settings',
                  child: InkWell(
                    onTap: () {
                      if (currentUser != null) {
                        UserProfileSheet.show(context, currentUser);
                      }
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      child: Center(
                        child: PersonAvatar(
                          person: currentUser,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. BalanceHeroCard
            BalanceHeroCard(
              netPaise: overall.netBalance,
              totalOwedToUserPaise: overall.totalOwedToUser,
              totalUserOwesPaise: overall.totalUserOwes,
            ),
            const SizedBox(height: 20),

            // 3. Quick-add bar
            QuickAddBar(
              onQuickAddTapped: (initialText) async {
                final result = await context.push<String?>(
                  '/add',
                  extra: {'initialText': initialText},
                );
                if (result != null) {
                  _triggerHighlight(result);
                }
              },
            ),
            const SizedBox(height: 24),

            // 4. "Your groups" Section
            const SectionHeader(title: 'Your groups'),
            const SizedBox(height: 4),
            for (final group in groups) ...[
              GroupCard(
                group: group,
                members: people
                    .where((p) => group.memberIds.contains(p.id))
                    .toList(),
                userNetPaise:
                    repo.getGroupSummary(group.id).netBalances[repo.currentUserId] ?? 0,
                onTap: () => context.push('/group/${group.id}'),
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 14),

            // 5. "Recent activity" Section
            const SectionHeader(title: 'Recent activity'),
            const SizedBox(height: 6),
            if (recentExpenses.isEmpty) ...[
              EmptyState(
                title: 'No recent activity',
                subtitle: 'Split bills with flatmates or trips to track balances.',
                action: ElevatedButton.icon(
                  onPressed: () => context.push('/add'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add your first expense'),
                ),
              ),
            ] else ...[
              _buildGroupedExpensesList(recentExpenses, repo),
            ],

            const SizedBox(height: 90), // Bottom padding for FAB
          ],
        ),
      ),
      floatingActionButton: FloatingAddButton(
        onTap: () async {
          final result = await context.push<String?>('/add');
          if (result != null) {
            _triggerHighlight(result);
          }
        },
      ),
    );
  }

  Widget _buildGroupedExpensesList(
    List<Expense> expenses,
    AppRepository repo,
  ) {
    // Group expenses by day header ("Today", "Yesterday", "Sat, 14 Nov", etc.)
    final Map<String, List<Expense>> grouped = {};
    for (final exp in expenses) {
      final header = DateFormatter.formatDayHeader(exp.date);
      grouped.putIfAbsent(header, () => []).add(exp);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Text(
              entry.key,
              style: AppTypography.caption.copyWith(
                color: context.settliv.secondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          for (final exp in entry.value) ...[
            ExpenseTile(
              expense: exp,
              payer: repo.getPerson(exp.paidBy),
              group: repo.getGroup(exp.groupId),
              currentUserId: repo.currentUserId,
              isHighlighted: exp.id == _highlightedExpenseId,
              onTap: () {
                ExpenseDetailSheet.show(
                  context: context,
                  expense: exp,
                  onEdit: () {
                    context.push('/add', extra: {'initialExpense': exp});
                  },
                  onDelete: () {
                    final repoNotifier = ref.read(appStateProvider.notifier);
                    repoNotifier.deleteExpense(exp.id);
                    UndoSnackbar.show(
                      context: context,
                      message: 'Deleted ${exp.title}',
                      onUndo: () => repoNotifier.restoreExpense(exp.id),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ],
    );
  }
}
