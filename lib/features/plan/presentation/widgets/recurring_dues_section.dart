import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/models/expense.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';

class RecurringDuesSection extends ConsumerWidget {
  const RecurringDuesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final templates = ref.watch(allRecurringTemplatesProvider);
    final activeTemplates = templates.where((t) => !t.isPaused).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'UPCOMING & DUE RECURRING',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/settings/recurring'),
              child: Text(
                'Manage',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.accent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (activeTemplates.isEmpty)
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'No upcoming recurring bills.',
                    style: AppTypography.caption.copyWith(color: theme.muted),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/settings/recurring'),
                  child: Text(
                    'Add bill',
                    style: TextStyle(color: theme.accent, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeTemplates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final t = activeTemplates[index];
              final dateStr = '${t.startDate.day}/${t.startDate.month}';

              return GlassSurface(
                level: GlassLevel.level1,
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.repeat_rounded, color: theme.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.description,
                            style: AppTypography.bodySemiBold.copyWith(
                              color: theme.ink,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Due $dateStr · ${t.frequency.name}',
                            style: AppTypography.caption.copyWith(color: theme.muted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatPaise(t.totalPaise),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                // Add to ledger
                                final exp = Expense(
                                  id: 'exp_rec_${DateTime.now().millisecondsSinceEpoch}',
                                  groupId: t.groupId,
                                  description: t.description,
                                  totalPaise: t.totalPaise,
                                  payers: t.payers,
                                  computedShares: {
                                    for (final p in t.participants)
                                      p: (t.totalPaise / t.participants.length).round()
                                  },
                                  category: t.category,
                                  splitMode: SplitMode.equal,
                                  date: DateTime.now(),
                                  createdAt: DateTime.now(),
                                );
                                ref.read(appStateProvider.notifier).addExpense(exp);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Logged ${t.description} to expenses')),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.textEmerald.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textEmerald,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Skipped ${t.description} for this cycle')),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme.hairline,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.muted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
