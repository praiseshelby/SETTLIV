import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/onboarding/domain/tour_scope.dart';
import '../../routes/app_router.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/glass_sheet_scaffold.dart';
import '../widgets/primary_button.dart';
import 'auth_provider.dart';
import 'guest_limits.dart';

class GuestLimitSheet extends ConsumerWidget {
  final bool isHard;

  const GuestLimitSheet({
    super.key,
    required this.isHard,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isHard,
  }) {
    final targetContext = rootNavigatorKey.currentContext ?? context;
    return GlassSheetScaffold.show<void>(
      context: targetContext,
      title: isHard ? 'Guest limit reached' : 'Keep your ledger safe',
      isScrollControlled: true,
      child: GuestLimitSheet(isHard: isHard),
    );
  }

  Future<void> _navigateToAuth(
    BuildContext context,
    WidgetRef ref,
    String route,
  ) async {
    final router = GoRouter.maybeOf(context);
    Navigator.of(context, rootNavigator: true).pop();
    await ref.read(authStateProvider.notifier).exitGuestMode();
    router?.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Create an account to keep going.',
          style: AppTypography.titleLarge.copyWith(
            color: theme.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isHard
              ? 'You\'ve reached the guest preview limit (${GuestLimits.hardLimit} changes). Viewing still works, and creating an account unlocks unlimited edits.'
              : 'You\'ve made ${GuestLimits.softLimit} changes in guest mode. Create a free account or sign in to keep your own ledger.',
          style: AppTypography.body.copyWith(
            color: theme.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Create account',
          onPressed: () => _navigateToAuth(context, ref, '/signup'),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: OutlinedButton(
            onPressed: () => _navigateToAuth(context, ref, '/signin'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.ink,
              side: BorderSide(color: theme.hairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Sign in',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (!isHard) ...[
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(),
              child: Text(
                'Not now',
                style: AppTypography.button.copyWith(color: theme.muted),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Checks guest write limits before performing a meaningful write action.
/// Returns `true` if the write may proceed, or `false` if hard-blocked.
/// Also returns the [GuestLimitOutcome] so callers can display the prompt
/// after closing any active form/navigation if needed.
class GuestWriteGuard {
  GuestWriteGuard._();

  static GuestLimitOutcome checkAndRecord(
    BuildContext context,
    WidgetRef ref,
  ) {
    final inTour = TourScope.maybeOf(context) != null;
    final outcome = ref
        .read(guestWriteCountProvider.notifier)
        .recordWriteAttempt(inTour: inTour);
    if (outcome == GuestLimitOutcome.hardBlocked && context.mounted) {
      GuestLimitSheet.show(context, isHard: true);
    }
    return outcome;
  }

  static void showPromptIfNeeded(
    BuildContext context,
    GuestLimitOutcome outcome,
  ) {
    if (!context.mounted) return;
    if (outcome == GuestLimitOutcome.softPrompt) {
      GuestLimitSheet.show(context, isHard: false);
    } else if (outcome == GuestLimitOutcome.hardReached) {
      GuestLimitSheet.show(context, isHard: true);
    }
  }
}
