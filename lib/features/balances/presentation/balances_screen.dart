import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/undo_snackbar.dart';
import '../../../data/engine/balance_engine.dart';
import '../../../data/engine/person_balance_engine.dart';
import '../../../data/models/person.dart';
import '../../../data/models/settlement.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../group_detail/sheets/nudge_sheet.dart';
import '../../group_detail/sheets/settle_sheet.dart';

enum BalanceTab { owedToUser, userOwes }
enum BalanceSort { byAmount, byName }

class BalancesScreen extends ConsumerStatefulWidget {
  const BalancesScreen({super.key});

  @override
  ConsumerState<BalancesScreen> createState() => _BalancesScreenState();
}

class _BalancesScreenState extends ConsumerState<BalancesScreen> {
  BalanceTab _selectedTab = BalanceTab.owedToUser;
  BalanceSort _sort = BalanceSort.byAmount;
  final Set<String> _expandedPersonIds = {};

  // Track settlements made in this session for "Settled recently"
  final List<Settlement> _sessionSettlements = [];

  void _toggleExpanded(String personId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedPersonIds.contains(personId)) {
        _expandedPersonIds.remove(personId);
      } else {
        _expandedPersonIds.add(personId);
      }
    });
  }

  void _onSettleAll(PersonDebtSummary summary) {
    HapticFeedback.selectionClick();
    final repo = ref.read(appRepositoryProvider);
    final now = DateTime.now();

    final createdIds = PersonBalanceEngine.settleAllForPerson(
      repo: repo,
      summary: summary,
      timestamp: now,
    );

    // Track in session settlements
    final newSettlements = repo.getAllSettlements().where((s) => createdIds.contains(s.id)).toList();
    setState(() {
      _sessionSettlements.insertAll(0, newSettlements);
    });

    UndoSnackbar.show(
      context: context,
      message: 'Settled all with ${summary.person.name}',
      onUndo: () {
        for (final id in createdIds) {
          repo.deleteSettlement(id);
        }
        setState(() {
          _sessionSettlements.removeWhere((s) => createdIds.contains(s.id));
        });
      },
    );
  }

  void _onNudge(Person person, int amountPaise, List<GroupDebtLine> lines) {
    HapticFeedback.selectionClick();
    final repo = ref.read(appRepositoryProvider);
    final firstLine = lines.firstOrNull;
    final group = firstLine != null
        ? repo.getGroup(firstLine.groupId)
        : repo.getGroups().firstWhere((g) => !g.isPersonal);

    if (group != null) {
      NudgeSheet.show(
        context: context,
        group: group,
        debtor: person,
        amountPaise: amountPaise,
      );
    }
  }

  void _onSettleGroupLine(Person person, GroupDebtLine line) {
    HapticFeedback.selectionClick();
    final repo = ref.read(appRepositoryProvider);
    final group = repo.getGroup(line.groupId);
    if (group == null) return;

    final summary = repo.getGroupSummary(line.groupId);
    final currentUserId = repo.currentUserId;
    final debt = summary.debts.cast<SimplifiedDebt?>().firstWhere(
          (d) =>
              (d?.fromPersonId == currentUserId && d?.toPersonId == person.id) ||
              (d?.fromPersonId == person.id && d?.toPersonId == currentUserId),
          orElse: () => null,
        );

    SettleSheet.show(
      context: context,
      group: group,
      preselectedDebt: debt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final overall = ref.watch(userOverallBalanceProvider);
    final allSummaries = PersonBalanceEngine.computePersonSummaries(repo);

    final owedToUserList = allSummaries.where((s) => s.personOwesUser).toList();
    final userOwesList = allSummaries.where((s) => s.userOwesPerson).toList();

    // Sort items
    void sortList(List<PersonDebtSummary> list) {
      if (_sort == BalanceSort.byAmount) {
        list.sort((a, b) => b.amountPaise.compareTo(a.amountPaise));
      } else {
        list.sort((a, b) => a.person.name.compareTo(b.person.name));
      }
    }

    sortList(owedToUserList);
    sortList(userOwesList);

    final currentList = _selectedTab == BalanceTab.owedToUser ? owedToUserList : userOwesList;

    final String netSentence;
    if (overall.netBalance > 0) {
      netSentence = "You're owed ${CurrencyFormatter.formatPaise(overall.netBalance)} overall across groups";
    } else if (overall.netBalance < 0) {
      netSentence = "You owe ${CurrencyFormatter.formatPaise(overall.netBalance.abs())} overall across groups";
    } else {
      netSentence = "All settled up across all groups";
    }

    return Scaffold(
      backgroundColor: theme.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded, color: theme.ink),
                      onPressed: () => context.pop(),
                      tooltip: 'Back',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Balances',
                            style: AppTypography.titleLarge.copyWith(
                              color: theme.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            netSentence,
                            style: AppTypography.caption.copyWith(
                              color: theme.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
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

              // Segmented Control & Sort Row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    // Segmented Control
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.hairline, width: 1.0),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSegmentButton(
                                label: 'Owed to you (${owedToUserList.length})',
                                isSelected: _selectedTab == BalanceTab.owedToUser,
                                onTap: () => setState(() => _selectedTab = BalanceTab.owedToUser),
                                theme: theme,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildSegmentButton(
                                label: 'You owe (${userOwesList.length})',
                                isSelected: _selectedTab == BalanceTab.userOwes,
                                onTap: () => setState(() => _selectedTab = BalanceTab.userOwes),
                                theme: theme,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Sort toggle button
                    IconButton(
                      icon: Icon(
                        _sort == BalanceSort.byAmount ? Icons.sort_rounded : Icons.sort_by_alpha_rounded,
                        color: theme.muted,
                      ),
                      tooltip: _sort == BalanceSort.byAmount ? 'Sorted by amount' : 'Sorted by name',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _sort = _sort == BalanceSort.byAmount ? BalanceSort.byName : BalanceSort.byAmount;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Main List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    if (currentList.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 48),
                        child: EmptyState(
                          title: _selectedTab == BalanceTab.owedToUser
                              ? 'No one owes you right now'
                              : "You don't owe anyone right now",
                          subtitle: _selectedTab == BalanceTab.owedToUser
                              ? 'When friends owe you their share of group expenses, they will appear here.'
                              : 'All your group debts are cleared and settled up!',
                        ),
                      ),
                    ] else ...[
                      for (final summary in currentList) ...[
                        _buildPersonRow(summary, theme),
                        const SizedBox(height: 12),
                      ],
                    ],

                    // Settled Recently Section
                    if (_sessionSettlements.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'SETTLED RECENTLY',
                        style: AppTypography.eyebrow.copyWith(
                          color: theme.muted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SectionCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (int i = 0; i < _sessionSettlements.length; i++) ...[
                              _buildRecentSettlementRow(_sessionSettlements[i], repo, theme),
                              if (i < _sessionSettlements.length - 1)
                                Divider(height: 1, color: theme.hairline),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required SettlivThemeExtension theme,
  }) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? (theme.isDark ? theme.raised : theme.navy) : theme.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected
                  ? (theme.isDark ? theme.ink : theme.white)
                  : theme.muted,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildPersonRow(PersonDebtSummary summary, SettlivThemeExtension theme) {
    final isExpanded = _expandedPersonIds.contains(summary.person.id);
    final isOwedToUser = summary.personOwesUser;
    final amountText = CurrencyFormatter.formatPaise(summary.amountPaise);
    final statusText = isOwedToUser ? 'owes you $amountText' : 'you owe $amountText';

    return SectionCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleExpanded(summary.person.id),
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  PersonAvatar(person: summary.person, size: 40),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.person.name,
                          style: AppTypography.sectionTitle.copyWith(
                            color: theme.ink,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: AppTypography.caption.copyWith(
                            color: isOwedToUser ? theme.textEmerald : theme.textCoral,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (summary.lines.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            summary.breakdownText,
                            style: AppTypography.caption.copyWith(
                              color: theme.muted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Primary action button (Nudge / Settle)
                  if (isOwedToUser)
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.hairline),
                        foregroundColor: theme.ink,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () => _onNudge(summary.person, summary.amountPaise, summary.lines),
                      child: const Text('Nudge', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryButtonBg,
                        foregroundColor: theme.primaryButtonText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        if (summary.lines.length == 1) {
                          _onSettleGroupLine(summary.person, summary.lines.first);
                        } else {
                          _onSettleAll(summary);
                        }
                      },
                      child: const Text('Settle', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: theme.muted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Breakdown Section
          if (isExpanded) ...[
            Divider(height: 1, color: theme.hairline),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.surface.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final line in summary.lines) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.groupName,
                                style: AppTypography.bodySemiBold.copyWith(
                                  color: theme.ink,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                line.personOwesUser
                                    ? 'Owes you ${CurrencyFormatter.formatPaise(line.amountPaise)}'
                                    : 'You owe ${CurrencyFormatter.formatPaise(line.amountPaise)}',
                                style: AppTypography.caption.copyWith(
                                  color: line.personOwesUser ? theme.textEmerald : theme.textCoral,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () {
                              if (line.personOwesUser) {
                                final repo = ref.read(appRepositoryProvider);
                                final grp = repo.getGroup(line.groupId);
                                if (grp != null) {
                                  NudgeSheet.show(
                                    context: context,
                                    group: grp,
                                    debtor: summary.person,
                                    amountPaise: line.amountPaise,
                                  );
                                }
                              } else {
                                _onSettleGroupLine(summary.person, line);
                              }
                            },
                            child: Text(
                              line.personOwesUser ? 'Nudge' : 'Settle',
                              style: TextStyle(
                                color: theme.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (summary.lines.length > 1) ...[
                    const SizedBox(height: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryButtonBg,
                        foregroundColor: theme.primaryButtonText,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () => _onSettleAll(summary),
                      child: Text(
                        'Settle all with ${summary.person.name} (${CurrencyFormatter.formatPaise(summary.amountPaise)})',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentSettlementRow(Settlement settlement, dynamic repo, SettlivThemeExtension theme) {
    final payer = repo.getPerson(settlement.from);
    final payee = repo.getPerson(settlement.to);
    final group = repo.getGroup(settlement.groupId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.emeraldTint,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, color: theme.emerald, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payer?.name ?? "Someone"} paid ${payee?.name ?? "Someone"} ${CurrencyFormatter.formatPaise(settlement.paise)}',
                  style: AppTypography.caption.copyWith(
                    color: theme.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  group?.name ?? 'Group',
                  style: AppTypography.caption.copyWith(
                    color: theme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              repo.deleteSettlement(settlement.id);
              setState(() {
                _sessionSettlements.removeWhere((s) => s.id == settlement.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settlement undone')),
              );
            },
            child: Text(
              'Undo',
              style: TextStyle(
                color: theme.coral,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
