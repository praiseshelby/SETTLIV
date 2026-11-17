import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/balance_pill.dart';
import '../../../core/widgets/group_cover_art.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/repositories/in_memory_app_repository.dart';

class GroupDetailPlaceholderScreen extends ConsumerWidget {
  final String groupId;

  const GroupDetailPlaceholderScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final group = ref.watch(groupProvider(groupId));
    final repo = ref.watch(appRepositoryProvider);

    if (group == null) {
      return Scaffold(
        backgroundColor: theme.canvas,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Group not found',
                style: AppTypography.titleLarge.copyWith(color: theme.ink),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Back to Home',
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      );
    }

    final summary = repo.getGroupSummary(group.id);
    final userNet = summary.netBalances[repo.currentUserId] ?? 0;

    return Scaffold(
      backgroundColor: theme.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Stack(
              children: [
                GroupCoverArt(
                  coverType: group.coverType,
                  height: 180,
                  borderRadius: 0,
                  heroTag: 'group-cover-${group.id}',
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        group.name,
                        style: AppTypography.titleLarge.copyWith(color: theme.ink),
                      ),
                      BalancePill(paise: userNet),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      'Group Detail screen will be built in Part 3',
                      style: AppTypography.body.copyWith(color: theme.secondary),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(
                label: 'Back to Home',
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
