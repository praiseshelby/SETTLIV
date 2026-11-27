import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/adaptive_presenter.dart';
import '../../../../core/widgets/glass_surface.dart';
import '../../../../data/repositories/in_memory_app_repository.dart';
import '../../../../data/repositories/supabase_ledger_repository.dart';
import '../../../../supabase_config.dart';

class AccountSettingsSection extends ConsumerWidget {
  const AccountSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.settliv;
    final authStatus = ref.watch(authStateProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final syncState = ref.watch(ledgerSyncStateProvider);
    final appRepo = ref.watch(appRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ACCOUNT',
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (authStatus is AuthSignedIn)
          _buildSignedInCard(
            context: context,
            ref: ref,
            theme: theme,
            user: authStatus.user,
            syncState: syncState,
            appRepo: appRepo,
          )
        else if (authStatus is AuthGuest)
          _buildGuestCard(context, ref, theme)
        else if (!SupabaseConfig.isSupabaseConfigured && authRepo == null)
          GlassSurface(
            level: GlassLevel.level1,
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Text(
              'Cloud accounts are not set up in this build',
              style: AppTypography.body.copyWith(color: theme.muted),
            ),
          )
        else
          _buildGuestCard(context, ref, theme),
      ],
    );
  }

  Widget _buildGuestCard(
    BuildContext context,
    WidgetRef ref,
    SettlivThemeExtension theme,
  ) {
    return GlassSurface(
      level: GlassLevel.level1,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are exploring without an account',
            style: AppTypography.body.copyWith(
              color: theme.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Demo data stays on this device.',
            style: AppTypography.caption.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.hairline),
                foregroundColor: theme.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                await ref.read(authStateProvider.notifier).exitGuestMode();
                if (context.mounted) context.go('/signup');
              },
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Create account',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignedInCard({
    required BuildContext context,
    required WidgetRef ref,
    required SettlivThemeExtension theme,
    required AuthUser user,
    required LedgerSyncState syncState,
    required dynamic appRepo,
  }) {
    final String syncLabel;
    if (syncState.isSettingUpAccount) {
      syncLabel = 'Setting up your account...';
    } else if (syncState.setupFailed) {
      syncLabel = 'Account setup could not complete';
    } else if (user.profileWarning != null) {
      syncLabel = 'Signed in locally (${user.profileWarning})';
    } else if (syncState.isOffline) {
      syncLabel = 'Offline — showing cached data';
    } else if (syncState.lastSyncedAt != null) {
      final t = DateFormat('h:mm a').format(syncState.lastSyncedAt!);
      syncLabel = 'Saved to your account · $t';
    } else {
      syncLabel = 'Saved to your account';
    }

    return GlassSurface(
      level: GlassLevel.level1,
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            user.displayName,
            style: AppTypography.sectionTitle.copyWith(color: theme.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (user.accountIdentifier.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              user.accountIdentifier,
              style: AppTypography.body.copyWith(color: theme.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Sign-in method: ${user.provider.displayLabel}',
            style: AppTypography.caption.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                syncState.isOffline
                    ? Icons.cloud_off_rounded
                    : Icons.cloud_done_outlined,
                size: 16,
                color: syncState.isOffline ? theme.textCoral : theme.textEmerald,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  syncLabel,
                  style: AppTypography.caption.copyWith(
                    color: syncState.isOffline
                        ? theme.textCoral
                        : theme.textEmerald,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if ((syncState.setupFailed || syncState.isOffline || user.profileWarning != null) &&
                  appRepo is SupabaseLedgerRepository)
                TextButton(
                  onPressed: () => appRepo.initialize(),
                  child: const Text('Retry'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.hairline, height: 1),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.hairline),
                foregroundColor: theme.ink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _confirmSignOut(context, ref, theme),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Sign out',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.coral),
                foregroundColor: theme.textCoral,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _confirmDeleteAccount(context, ref, user),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Delete account and data',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    SettlivThemeExtension theme,
  ) {
    AdaptivePresenter.show<void>(
      context: context,
      title: 'Sign out?',
      maxWidth: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your ledger remains saved in your account. You can sign back in anytime.',
            style: AppTypography.body.copyWith(color: theme.muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryButtonBg,
                      foregroundColor: theme.primaryButtonText,
                    ),
                    onPressed: () async {
                      final router = GoRouter.of(context);
                      final navigator = Navigator.of(context);
                      if (navigator.canPop()) navigator.pop();
                      await ref.read(authStateProvider.notifier).signOut();
                      router.go('/welcome');
                    },
                    child: const Text('Sign out'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
    AuthUser user,
  ) {
    AdaptivePresenter.show<void>(
      context: context,
      title: 'Delete account and data',
      maxWidth: 440,
      child: _DeleteAccountBody(user: user),
    );
  }
}

class _DeleteAccountBody extends ConsumerStatefulWidget {
  final AuthUser user;
  const _DeleteAccountBody({required this.user});

  @override
  ConsumerState<_DeleteAccountBody> createState() => _DeleteAccountBodyState();
}

class _DeleteAccountBodyState extends ConsumerState<_DeleteAccountBody> {
  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitDelete() async {
    if (_isDeleting) return;
    if (_confirmController.text.trim() != 'DELETE') {
      setState(() => _error = 'Type DELETE to confirm');
      return;
    }
    final needsPassword =
        widget.user.provider != AuthProviderKind.google;
    if (needsPassword && _passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your current password to continue');
      return;
    }

    setState(() {
      _isDeleting = true;
      _error = null;
    });
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(authStateProvider.notifier).deleteAccount(
            password: needsPassword ? _passwordController.text : null,
          );
      if (mounted && navigator.canPop()) {
        navigator.pop();
      }
      router.go('/welcome');
      messenger?.showSnackBar(
        const SnackBar(content: Text('Account and data deleted')),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Delete account error: $e\n$st');
      }
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _error = AuthErrorMapper.map(e) ?? 'Could not delete account.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final needsPassword = widget.user.provider != AuthProviderKind.google;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This permanently deletes your account, profile, and all ledger data from Settliv. This cannot be undone.',
          style: AppTypography.body.copyWith(color: theme.muted),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmController,
          decoration: InputDecoration(
            labelText: 'Type DELETE to confirm',
            filled: true,
            fillColor: theme.raised,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (needsPassword) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Current password',
              filled: true,
              fillColor: theme.raised,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'You will be asked to confirm with Google before deletion.',
            style: AppTypography.caption.copyWith(color: theme.muted),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: AppTypography.caption.copyWith(
              color: theme.textCoral,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.coral,
              foregroundColor: theme.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isDeleting ? null : _submitDelete,
            child: _isDeleting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.white,
                    ),
                  )
                : const Text(
                    'Delete permanently',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}
