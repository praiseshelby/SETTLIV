import '../../../../core/profile/experience_mode.dart';
import '../../../../core/widgets/web_balance_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/avatar_stack.dart';
import '../../../../core/widgets/balance_pill.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../core/widgets/group_cover_art.dart';
import '../../../../core/widgets/undo_snackbar.dart';
import '../../../../data/engine/balance_engine.dart';
import '../../../../data/models/expense.dart';
import '../../../../data/models/group.dart';
import '../../../../data/models/person.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../../../group_detail/sheets/nudge_sheet.dart';
import '../../../group_detail/sheets/settle_sheet.dart';
import 'create_edit_group_sheet.dart';

class GroupHubCard extends ConsumerWidget {
  final Group group;
  final List<Person> members;
  final GroupBalanceSummary summary;
  final List<Expense> expenses;

  const GroupHubCard({
    super.key,
    required this.group,
    required this.members,
    required this.summary,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final repo = ref.watch(appRepositoryProvider);
    final currentUserId = repo.currentUserId;
    final netPaise = summary.netBalances[currentUserId] ?? 0;
    final isOwedToUser = netPaise > 0;
    final isUserOwes = netPaise < 0;
    final isSettled = netPaise == 0;

    // 1. Balance sentence
    final String balanceSentence;
    if (isOwedToUser) {
      balanceSentence = 'You are owed ${CurrencyFormatter.formatPaise(netPaise)}';
    } else if (isUserOwes) {
      balanceSentence = 'You owe ${CurrencyFormatter.formatPaise(netPaise.abs())}';
    } else {
      balanceSentence = 'All settled up in this group';
    }

    // 2. This month spend & last activity
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final activeExpenses = expenses.where((e) => !e.isDeleted).toList();

    final int thisMonthSpend = activeExpenses
        .where((e) => e.date.isAfter(firstDayOfMonth) || e.date.isAtSameMomentAs(firstDayOfMonth))
        .fold(0, (sum, e) => sum + e.totalPaise);

    DateTime? lastActivity;
    if (activeExpenses.isNotEmpty) {
      lastActivity = activeExpenses.map((e) => e.date).reduce((a, b) => a.isAfter(b) ? a : b);
    }

    final String activityText;
    if (lastActivity == null) {
      activityText = 'No activity yet';
    } else {
      final daysAgo = now.difference(lastActivity).inDays;
      if (daysAgo == 0) {
        activityText = 'last activity today';
      } else if (daysAgo == 1) {
        activityText = 'last activity yesterday';
      } else {
        activityText = 'last activity ${daysAgo}d ago';
      }
    }

    final String sublineText =
        '${CurrencyFormatter.formatPaise(thisMonthSpend)} this month · $activityText';

    // 3. Biggest balance in group
    String? biggestBalanceText;
    if (summary.debts.isNotEmpty) {
      final biggestDebt = summary.debts.reduce((a, b) => a.amount > b.amount ? a : b);
      if (biggestDebt.amount > 0) {
        final debtor = members.firstWhere(
          (m) => m.id == biggestDebt.fromPersonId,
          orElse: () => Person(id: biggestDebt.fromPersonId, name: 'Someone'),
        );
        biggestBalanceText =
            'Biggest balance: ${debtor.name} (${CurrencyFormatter.formatPaise(biggestDebt.amount)})';
      }
    }

    // 4. Sparkline 6-week data points
    final sparklinePoints = _computeWeeklySpend(activeExpenses, now);

    return Semantics(
      button: true,
      label: '${group.name} group card',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GlassSurface(
          level: GlassLevel.level2,
          borderRadius: 24,
          padding: EdgeInsets.zero,
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/group/${group.id}');
          },
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cover Art Header with Pinned Badge & Overflow Menu
            Stack(
              children: [
                GroupCoverArt(
                  group: group,
                  height: 110,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (group.isPinned)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.surface.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: theme.hairline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.push_pin_rounded, size: 12, color: theme.accent),
                              const SizedBox(width: 4),
                              Text('Pinned', style: AppTypography.caption.copyWith(color: theme.ink, fontSize: 10, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      const SizedBox(width: 6),
                      // Overflow Menu
                      Container(
                        decoration: BoxDecoration(
                          color: theme.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: theme.hairline),
                        ),
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, size: 18, color: theme.ink),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: theme.raised,
                          onSelected: (val) {
                            final notifier = ref.read(appStateProvider.notifier);
                            if (val == 'pin') {
                              notifier.updateGroup(group.copyWith(isPinned: !group.isPinned));
                            } else if (val == 'archive') {
                              notifier.updateGroup(group.copyWith(isArchived: !group.isArchived));
                              UndoSnackbar.show(
                                context: context,
                                message: group.isArchived ? '${group.name} unarchived' : '${group.name} archived',
                                onUndo: () {
                                  notifier.updateGroup(group.copyWith(isArchived: group.isArchived));
                                },
                              );
                            } else if (val == 'edit') {
                              CreateEditGroupSheet.show(context, initialGroup: group);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(group.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 18, color: theme.ink),
                                  const SizedBox(width: 8),
                                  Text(group.isPinned ? 'Unpin group' : 'Pin group', style: TextStyle(color: theme.ink, fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18, color: theme.ink),
                                  const SizedBox(width: 8),
                                  Text('Edit group', style: TextStyle(color: theme.ink, fontSize: 13)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(group.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 18, color: theme.ink),
                                  const SizedBox(width: 8),
                                  Text(group.isArchived ? 'Unarchive group' : 'Archive group', style: TextStyle(color: theme.ink, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Card Body
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Balance badge / quiet tick
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: TextStyle(
                            fontFamily: AppTypography.fontBrand,
                            fontFamilyFallback: AppTypography.brandFallback,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: theme.ink,
                            letterSpacing: -0.4,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (ref.watch(effectiveExperienceProvider) == EffectiveExperience.web)
                        WebBalanceBadge(paise: netPaise)
                      else if (isSettled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.textEmerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded, size: 14, color: theme.textEmerald),
                              const SizedBox(width: 4),
                              Text(
                                'Settled',
                                style: AppTypography.caption.copyWith(
                                  color: theme.textEmerald,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        BalancePill(paise: netPaise, compact: false),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Full balance sentence
                  Text(
                    balanceSentence,
                    style: AppTypography.caption.copyWith(
                      color: isSettled
                          ? theme.muted
                          : (isOwedToUser ? theme.textEmerald : theme.textCoral),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Avatars + Type label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AvatarStack(people: members, avatarSize: 28, overlap: 8),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${members.length} people · ${group.type.label}',
                          style: AppTypography.caption.copyWith(
                            color: theme.muted,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 6-week spend sparkline
                  SizedBox(
                    height: 36,
                    child: CustomPaint(
                      painter: SpendSparklinePainter(
                        dataPoints: sparklinePoints,
                        lineColor: theme.accent,
                        fillColor: theme.accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subline: spend this month & last activity
                  Text(
                    sublineText,
                    style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (biggestBalanceText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      biggestBalanceText,
                      style: AppTypography.caption.copyWith(
                        color: theme.secondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 14),

                  Divider(height: 1, color: theme.hairline),
                  const SizedBox(height: 10),

                  // Inline actions row
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Add Expense Button
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/add', extra: {'preselectedGroupId': group.id});
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 16, color: theme.ink),
                              const SizedBox(width: 4),
                              Text('Add expense', style: AppTypography.caption.copyWith(color: theme.ink, fontWeight: FontWeight.w600, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),

                      // Settle button if user owes
                      if (isUserOwes)
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            SettleSheet.show(context: context, group: group);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.handshake_outlined, size: 16, color: theme.textCoral),
                                const SizedBox(width: 4),
                                Text('Settle', style: AppTypography.caption.copyWith(color: theme.textCoral, fontWeight: FontWeight.w600, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),

                      // Nudge button if user is owed
                      if (isOwedToUser)
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            final debtorDebt = summary.debts.cast<SimplifiedDebt?>().firstWhere(
                              (d) => d?.toPersonId == currentUserId,
                              orElse: () => null,
                            );
                            final debtor = debtorDebt != null
                                ? members.firstWhere((m) => m.id == debtorDebt.fromPersonId, orElse: () => members.first)
                                : members.first;

                            NudgeSheet.show(
                              context: context,
                              group: group,
                              debtor: debtor,
                              amountPaise: debtorDebt?.amount ?? netPaise,
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_none_rounded, size: 16, color: theme.accent),
                                const SizedBox(width: 4),
                                Text('Nudge', style: AppTypography.caption.copyWith(color: theme.accent, fontWeight: FontWeight.w600, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),

                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  List<double> _computeWeeklySpend(List<Expense> expenses, DateTime now) {
    final points = List<double>.filled(6, 0.0);
    for (int i = 0; i < 6; i++) {
      final weekStart = now.subtract(Duration(days: (5 - i) * 7 + 7));
      final weekEnd = now.subtract(Duration(days: (5 - i) * 7));
      final spend = expenses
          .where((e) => e.date.isAfter(weekStart) && e.date.isBefore(weekEnd))
          .fold<int>(0, (sum, e) => sum + e.totalPaise);
      points[i] = (spend / 100.0).clamp(0.0, 1000000.0);
    }
    // If all zero, give a small wave
    if (points.every((p) => p == 0)) {
      return [10.0, 25.0, 15.0, 40.0, 30.0, 20.0];
    }
    return points;
  }
}

class SpendSparklinePainter extends CustomPainter {
  final List<double> dataPoints;
  final Color lineColor;
  final Color fillColor;

  const SpendSparklinePainter({
    required this.dataPoints,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final maxVal = dataPoints.reduce((a, b) => a > b ? a : b);
    final minVal = dataPoints.reduce((a, b) => a < b ? a : b);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (dataPoints.length - 1);
    for (int i = 0; i < dataPoints.length; i++) {
      final normalized = (dataPoints[i] - minVal) / range;
      final x = i * stepX;
      final y = size.height - (normalized * (size.height - 8)) - 4;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevNorm = (dataPoints[i - 1] - minVal) / range;
        final prevY = size.height - (prevNorm * (size.height - 8)) - 4;
        final cx = (prevX + x) / 2;
        path.cubicTo(cx, prevY, cx, y, x, y);
        fillPath.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Draw stroke
    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(SpendSparklinePainter oldDelegate) =>
      oldDelegate.dataPoints != dataPoints ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.fillColor != fillColor;
}
