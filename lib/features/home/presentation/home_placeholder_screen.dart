import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/balance_hero_card.dart';
import '../../../core/widgets/group_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/floating_add_button.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class HomePlaceholderScreen extends ConsumerWidget {
  const HomePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final overall = ref.watch(userOverallBalanceProvider);
    final groups = ref.watch(allGroupsProvider);
    final people = ref.watch(allPeopleProvider);
    final repo = ref.watch(appRepositoryProvider);

    return Scaffold(
      backgroundColor: theme.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settliv',
                        style: AppTypography.titleLarge.copyWith(color: theme.ink),
                      ),
                      Text(
                        'Part 1 Prototype Foundation',
                        style: AppTypography.caption.copyWith(color: theme.secondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PersonAvatar(
                  person: repo.currentUser,
                  size: 40,
                ),
              ],
            ),
            const SizedBox(height: 20),
            BalanceHeroCard(
              netPaise: overall.netBalance,
              totalOwedToUserPaise: overall.totalOwedToUser,
              totalUserOwesPaise: overall.totalUserOwes,
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Your groups'),
            for (final group in groups) ...[
              GroupCard(
                group: group,
                members: people.where((p) => group.memberIds.contains(p.id)).toList(),
                userNetPaise: repo.getGroupSummary(group.id).netBalances[repo.currentUserId] ?? 0,
                onTap: () => context.push('/group/${group.id}'),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingAddButton(
        onTap: () => context.push('/add'),
      ),
    );
  }
}
