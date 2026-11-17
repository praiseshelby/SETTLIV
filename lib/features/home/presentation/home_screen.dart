import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/balance_hero_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/expense_tile.dart';
import '../../../core/widgets/floating_add_pill.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/group_card.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/phone_frame.dart';
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
    )..forward();
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
    final isDesktop = MediaQuery.of(context).size.width > 600;

    // Latest 8 active expenses
    final recentExpenses = allExpenses.take(8).toList();

    // Date line: "Tuesday, 17 November"
    final dateLine = DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
            children: [
              // 1. Header: Greeting + Date line + 44px Glass Avatar Button
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
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateLine,
                          style: AppTypography.caption.copyWith(
                            color: theme.secondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 44px glass avatar button
                  Semantics(
                    button: true,
                    label: 'User profile and theme settings',
                    child: GlassSurface(
                      level: GlassLevel.level1,
                      borderRadius: 999,
                      padding: const EdgeInsets.all(4),
                      onTap: () {
                        if (currentUser != null) {
                          UserProfileSheet.show(context, currentUser);
                        }
                      },
                      child: PersonAvatar(
                        person: currentUser,
                        size: 36,
                        showRing: false,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 2. Hero Card (Glass Level 3)
              BalanceHeroCard(
                netPaise: overall.netBalance,
                totalOwedToUserPaise: overall.totalOwedToUser,
                totalUserOwesPaise: overall.totalUserOwes,
              ),
              const SizedBox(height: 32),

              // 3. Quick-Add Button + Example Chips
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
              const SizedBox(height: 32),

              // 4. "Your groups" Section
              const SectionHeader(title: 'Your groups'),
              const SizedBox(height: 12),
              for (final group in groups) ...[
                GroupCard(
                  group: group,
                  members: people
                      .where((p) => group.memberIds.contains(p.id))
                      .toList(),
                  userNetPaise: repo
                          .getGroupSummary(group.id)
                          .netBalances[repo.currentUserId] ??
                      0,
                  onTap: () => context.push('/group/${group.id}'),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),

              // 5. "Recent activity" Section
              const SectionHeader(title: 'Recent activity'),
              const SizedBox(height: 12),
              if (recentExpenses.isEmpty) ...[
                EmptyState(
                  title: 'No recent activity',
                  subtitle:
                      'Split bills with flatmates or trips to track balances.',
                  action: ElevatedButton.icon(
                    onPressed: () => context.push('/add'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add an expense'),
                  ),
                ),
              ] else ...[
                // ONE unified grouped glass container
                _buildGroupedGlassActivity(recentExpenses, repo),
              ],

              // On phones (no desktop frame), show prototype note at end of scroll
              if (!isDesktop) ...[
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    PhoneFrame.prototypeNote,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(
                      color: theme.secondary.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FloatingAddPill(
          label: 'Add',
          onTap: () async {
            final result = await context.push<String?>('/add');
            if (result != null) {
              _triggerHighlight(result);
            }
          },
        ),
      ),
    );
  }

  Widget _buildGroupedGlassActivity(
    List<Expense> expenses,
    AppRepository repo,
  ) {
    final theme = context.settliv;

    // Group expenses by day header ("Today", "Yesterday", "Sat, 14 Nov", etc.)
    final Map<String, List<Expense>> grouped = {};
    for (final exp in expenses) {
      final header = DateFormatter.formatDayHeader(exp.date);
      grouped.putIfAbsent(header, () => []).add(exp);
    }

    return GlassSurface(
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
                style: AppTypography.sectionLabel.copyWith(
                  color: theme.secondary,
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
                currentUserId: repo.currentUserId,
                isHighlighted: entry.value[i].id == _highlightedExpenseId,
                showDivider: i < entry.value.length - 1,
                onTap: () {
                  ExpenseDetailSheet.show(
                    context: context,
                    expense: entry.value[i],
                    onEdit: () {
                      context.push('/add', extra: {'initialExpense': entry.value[i]});
                    },
                    onDelete: () {
                      final repoNotifier =
                          ref.read(appStateProvider.notifier);
                      repoNotifier.deleteExpense(entry.value[i].id);
                      UndoSnackbar.show(
                        context: context,
                        message: 'Deleted ${entry.value[i].title}',
                        onUndo: () =>
                            repoNotifier.restoreExpense(entry.value[i].id),
                      );
                    },
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
