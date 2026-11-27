import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../core/profile/experience_mode.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/adaptive_presenter.dart';
import '../../../core/widgets/aurora_background.dart';
import '../../../core/widgets/glass_segmented.dart';
import '../../../core/widgets/glass_surface.dart';
import '../../../core/widgets/settliv_wordmark.dart';
import '../../../data/repositories/in_memory_app_repository.dart';
import '../../../supabase_config.dart';

enum AuthFormMode { signIn, signUp }
enum _AuthIdentifierTab { username, email }

class WelcomeAuthScreen extends StatelessWidget {
  final String? fromLocation;
  const WelcomeAuthScreen({super.key, this.fromLocation});

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      initialMode: AuthFormMode.signIn,
      fromLocation: fromLocation,
    );
  }
}

class AuthScreen extends ConsumerStatefulWidget {
  final AuthFormMode initialMode;
  final String? fromLocation;

  const AuthScreen({
    super.key,
    required this.initialMode,
    this.fromLocation,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthFormMode _mode;
  _AuthIdentifierTab _tab = _AuthIdentifierTab.username;

  final _nameController = TextEditingController();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _consentChecked = false;
  bool _hasAttempted = false;
  bool _isSubmitting = false;
  String? _formError;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    if (SupabaseConfig.pendingOAuthError != null) {
      _formError = SupabaseConfig.pendingOAuthError;
      SupabaseConfig.pendingOAuthError = null;
    }
  }

  @override
  void didUpdateWidget(covariant AuthScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMode != widget.initialMode) {
      setState(() {
        _mode = widget.initialMode;
        _hasAttempted = false;
        _formError = null;
        _infoMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _currentLayoutValue(WidgetRef ref) {
    final eff = ref.read(effectiveExperienceProvider);
    return eff == EffectiveExperience.app ? 'app' : 'web';
  }

  String? get _nameError {
    if (!_hasAttempted || _mode != AuthFormMode.signUp) return null;
    if (_nameController.text.trim().isEmpty) return 'Enter your full name';
    return null;
  }

  String? get _identifierError {
    if (!_hasAttempted) return null;
    final raw = _identifierController.text.trim();
    if (_tab == _AuthIdentifierTab.username) {
      return UsernameHelper.validate(raw);
    }
    if (raw.isEmpty) return 'Enter your email address';
    if (!raw.contains('@') || !raw.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? get _passwordError {
    if (!_hasAttempted) return null;
    final pw = _passwordController.text;
    if (pw.isEmpty) return 'Enter a password';
    if (pw.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  String? get _consentError {
    if (!_hasAttempted || _mode != AuthFormMode.signUp) return null;
    if (!_consentChecked) {
      return 'Agree to the Privacy policy to create an account';
    }
    return null;
  }

  Future<void> _submitPrimary() async {
    if (_isSubmitting) return;
    setState(() {
      _hasAttempted = true;
      _formError = null;
      _infoMessage = null;
    });

    if (_nameError != null ||
        _identifierError != null ||
        _passwordError != null ||
        _consentError != null) {
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();
    try {
      final notifier = ref.read(authStateProvider.notifier);
      final layout = _currentLayoutValue(ref);
      final identifier = _identifierController.text.trim();
      final password = _passwordController.text;

      if (_mode == AuthFormMode.signUp) {
        if (_tab == _AuthIdentifierTab.username) {
          await notifier.signUpWithUsername(
            fullName: _nameController.text.trim(),
            username: identifier,
            password: password,
            layout: layout,
          );
        } else {
          await notifier.signUpWithEmail(
            fullName: _nameController.text.trim(),
            email: identifier,
            password: password,
            layout: layout,
          );
        }
      } else {
        if (_tab == _AuthIdentifierTab.username) {
          await notifier.signInWithUsername(
            username: identifier,
            password: password,
          );
        } else {
          await notifier.signInWithEmail(
            email: identifier,
            password: password,
          );
        }
      }
    } catch (e) {
      final msg = AuthErrorMapper.map(
        e,
        isUsernameFlow: _tab == _AuthIdentifierTab.username,
      );
      if (mounted && msg != null) {
        setState(() => _formError = msg);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitGoogle() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _formError = null;
      _infoMessage = null;
    });
    try {
      await ref
          .read(authStateProvider.notifier)
          .signInWithGoogle(layout: _currentLayoutValue(ref));
    } catch (e) {
      final msg = AuthErrorMapper.map(e);
      if (mounted && msg != null) {
        setState(() => _formError = msg);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitForgotPassword() async {
    if (_isSubmitting) return;
    final email = _identifierController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _hasAttempted = true;
        _formError = 'Enter your email address above first';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _formError = null;
      _infoMessage = null;
    });
    try {
      await ref.read(authStateProvider.notifier).sendPasswordReset(email: email);
      if (mounted) {
        setState(() {
          _infoMessage =
              'If an account exists for $email, a password reset link has been sent.';
        });
      }
    } catch (e) {
      final msg = AuthErrorMapper.map(e);
      if (mounted && msg != null) {
        setState(() => _formError = msg);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _exploreAsGuest() async {
    if (_isSubmitting) return;
    final prefs = ref.read(sharedPreferencesProvider);
    final alreadyOffered =
        prefs?.getBool(OnboardingPendingNotifier.guestOfferShownKey) ?? false;

    if (!alreadyOffered && mounted) {
      final choice = await AdaptivePresenter.show<String>(
        context: context,
        title: 'Want a one-minute tour?',
        maxWidth: 420,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'See how Settliv works before you dive in.',
                style: AppTypography.body.copyWith(
                  color: context.settliv.muted,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.settliv.primaryButtonBg,
                    foregroundColor: context.settliv.primaryButtonText,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(context).pop('tour'),
                  child: const Text(
                    'Take the tour',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop('skip'),
                  child: Text(
                    'Skip to app',
                    style: AppTypography.bodySemiBold.copyWith(
                      color: context.settliv.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      if (!mounted) return;
      if (choice == 'tour') {
        await ref.read(onboardingPendingProvider.notifier).startGuestTour();
        await ref.read(authStateProvider.notifier).enterGuestMode();
        if (mounted) context.go('/tour');
        return;
      }
      await ref.read(onboardingPendingProvider.notifier).markGuestTourOffered();
    }

    await ref.read(authStateProvider.notifier).enterGuestMode();
    if (mounted) {
      final dest = widget.fromLocation;
      if (dest != null &&
          dest.startsWith('/') &&
          !dest.startsWith('/welcome') &&
          !dest.startsWith('/signin') &&
          !dest.startsWith('/signup')) {
        context.go(dest);
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.settliv;
    final authStatus = ref.watch(authStateProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final layoutClass = AdaptiveLayout.of(context);
    final effectiveExp = ref.watch(effectiveExperienceProvider);
    final isExpandedWeb =
        effectiveExp == EffectiveExperience.web && layoutClass == LayoutClass.expanded;
    final showUnconfiguredNote =
        !SupabaseConfig.isSupabaseConfigured && authRepo == null;

    if (authStatus is AuthConfirmationPending) {
      return _buildConfirmationPendingScaffold(context, theme, authStatus);
    }

    final formCard = _buildFormBody(
      context: context,
      theme: theme,
      showUnconfiguredNote: showUnconfiguredNote,
      isAppLayout: effectiveExp == EffectiveExperience.app,
    );

    return Scaffold(
      backgroundColor: theme.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: isExpandedWeb
              ? Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RepaintBoundary(
                                child: SizedBox(
                                  width: 220,
                                  height: 220,
                                  child: CustomPaint(
                                    painter: _AuthOrbitMotifPainter(
                                      ringColor: theme.hairline,
                                      accentColor: theme.accent,
                                      emeraldColor: theme.emerald,
                                      coralColor: theme.coral,
                                    ),
                                    child: const Center(
                                      child: SettlivWordmark(
                                        fontSize: 22,
                                        trackingFactor: 0.24,
                                        opticallyCenter: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 6,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(32),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: GlassSurface(
                              level: GlassLevel.level2,
                              borderRadius: 24,
                              padding: const EdgeInsets.all(24),
                              child: formCard,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: effectiveExp == EffectiveExperience.app
                          ? formCard
                          : GlassSurface(
                              level: GlassLevel.level2,
                              borderRadius: 24,
                              padding: const EdgeInsets.all(24),
                              child: formCard,
                            ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildConfirmationPendingScaffold(
    BuildContext context,
    SettlivThemeExtension theme,
    AuthConfirmationPending pending,
  ) {
    return Scaffold(
      backgroundColor: theme.transparent,
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: GlassSurface(
                  level: GlassLevel.level2,
                  borderRadius: 24,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: SettlivWordmark(fontSize: 22)),
                      const SizedBox(height: 20),
                      Icon(
                        Icons.mark_email_read_outlined,
                        size: 40,
                        color: theme.textEmerald,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Confirm your email',
                        textAlign: TextAlign.center,
                        style: AppTypography.titleLarge.copyWith(
                          color: theme.ink,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pending.message,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(color: theme.muted),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryButtonBg,
                            foregroundColor: theme.primaryButtonText,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            ref
                                .read(authStateProvider.notifier)
                                .clearConfirmationPending();
                            setState(() => _mode = AuthFormMode.signIn);
                          },
                          child: const Text(
                            'Back to sign in',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormBody({
    required BuildContext context,
    required SettlivThemeExtension theme,
    required bool showUnconfiguredNote,
    required bool isAppLayout,
  }) {
    final isSignUp = _mode == AuthFormMode.signUp;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isAppLayout || AdaptiveLayout.of(context) != LayoutClass.expanded) ...[
          const Center(
            child: SettlivWordmark(fontSize: 22, trackingFactor: 0.24, opticallyCenter: true),
          ),
          const SizedBox(height: 18),
        ],
        Text(
          isSignUp ? 'Create your account' : 'Sign in to Settliv',
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(
            color: theme.ink,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 16),

        if (showUnconfiguredNote) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: theme.raised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.hairline),
            ),
            child: Text(
              'Cloud accounts are not set up in this build',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                color: theme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Continue with Google
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: theme.surface,
              foregroundColor: theme.ink,
              side: BorderSide(color: theme.hairline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isSubmitting ? null : _submitGoogle,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CustomPaint(
                    painter: _GoogleGMarkPainter(
                      blue: theme.accent,
                      red: theme.coral,
                      yellow: theme.saffron,
                      green: theme.emerald,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Continue with Google',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // "or" divider
        Row(
          children: [
            Expanded(child: Divider(color: theme.hairline, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: AppTypography.caption.copyWith(color: theme.muted),
              ),
            ),
            Expanded(child: Divider(color: theme.hairline, height: 1)),
          ],
        ),
        const SizedBox(height: 14),

        // Segmented control: Username | Email
        GlassSegmented<_AuthIdentifierTab>(
          values: const [_AuthIdentifierTab.username, _AuthIdentifierTab.email],
          labels: const ['Username', 'Email'],
          selectedValue: _tab,
          onValueChanged: (next) {
            setState(() {
              _tab = next;
              _hasAttempted = false;
              _formError = null;
              _infoMessage = null;
            });
          },
        ),
        const SizedBox(height: 14),

        if (isSignUp) ...[
          TextField(
            controller: _nameController,
            autofocus: true,
            textInputAction: TextInputAction.next,
            style: AppTypography.body.copyWith(color: theme.ink),
            decoration: InputDecoration(
              labelText: 'Full name',
              errorText: _nameError,
              filled: true,
              fillColor: theme.raised,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: theme.hairline),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Username or Email field
        TextField(
          controller: _identifierController,
          autofocus: !isSignUp,
          keyboardType: _tab == _AuthIdentifierTab.email
              ? TextInputType.emailAddress
              : TextInputType.text,
          textInputAction: TextInputAction.next,
          style: AppTypography.body.copyWith(color: theme.ink),
          decoration: InputDecoration(
            labelText: _tab == _AuthIdentifierTab.username ? 'Username' : 'Email',
            hintText: _tab == _AuthIdentifierTab.username
                ? 'e.g. arjun_99'
                : 'you@example.com',
            errorText: _identifierError,
            filled: true,
            fillColor: theme.raised,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.hairline),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Password field
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitPrimary(),
          style: AppTypography.body.copyWith(color: theme.ink),
          decoration: InputDecoration(
            labelText: 'Password',
            errorText: _passwordError,
            filled: true,
            fillColor: theme.raised,
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: theme.muted,
              ),
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.hairline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: theme.hairline),
            ),
          ),
        ),

        if (!isSignUp) ...[
          const SizedBox(height: 8),
          if (_tab == _AuthIdentifierTab.email)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSubmitting ? null : _submitForgotPassword,
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                child: Text(
                  'Forgot password?',
                  style: AppTypography.caption.copyWith(
                    color: theme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Username accounts have no email, so passwords cannot be reset. Use Google or email if you want recovery.',
                style: AppTypography.caption.copyWith(
                  color: theme.muted,
                  fontSize: 12,
                ),
              ),
            ),
        ],

        if (isSignUp) ...[
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _consentChecked = !_consentChecked),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Checkbox(
                      value: _consentChecked,
                      onChanged: (v) =>
                          setState(() => _consentChecked = v ?? false),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        children: [
                          Text(
                            'I agree to the ',
                            style: AppTypography.caption.copyWith(color: theme.muted),
                          ),
                          GestureDetector(
                            onTap: () => context.push('/privacy'),
                            child: Text(
                              'Privacy policy',
                              style: AppTypography.caption.copyWith(
                                color: theme.accent,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            ' and let Settliv store my account and ledger data',
                            style: AppTypography.caption.copyWith(color: theme.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_consentError != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Text(
                _consentError!,
                style: AppTypography.caption.copyWith(color: theme.textCoral),
              ),
            ),
        ],

        if (_formError != null) ...[
          const SizedBox(height: 8),
          Text(
            _formError!,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: theme.textCoral,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_infoMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _infoMessage!,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: theme.textEmerald,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Primary Submit Button
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryButtonBg,
              foregroundColor: theme.primaryButtonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: _isSubmitting ? null : _submitPrimary,
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.primaryButtonText,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isSignUp ? 'Create account' : 'Sign in',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),

        // Toggle Sign in / Sign up
        Center(
          child: TextButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    setState(() {
                      _mode = isSignUp
                          ? AuthFormMode.signIn
                          : AuthFormMode.signUp;
                      _hasAttempted = false;
                      _formError = null;
                      _infoMessage = null;
                    });
                  },
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(
              isSignUp
                  ? 'Already have an account? Sign in'
                  : 'New to Settliv? Create account',
              style: AppTypography.caption.copyWith(
                color: theme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Quiet Explore without an account
        SizedBox(
          height: 48,
          child: TextButton(
            onPressed: _isSubmitting ? null : _exploreAsGuest,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Explore without an account',
                style: AppTypography.bodySemiBold.copyWith(color: theme.ink),
              ),
            ),
          ),
        ),
        Text(
          'Demo data stays on this device.',
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(
            color: theme.muted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _GoogleGMarkPainter extends CustomPainter {
  final Color blue;
  final Color red;
  final Color yellow;
  final Color green;

  const _GoogleGMarkPainter({
    required this.blue,
    required this.red,
    required this.yellow,
    required this.green,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.18;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, -0.35, 1.45, false, paint..color = blue);
    canvas.drawArc(rect, 1.10, 1.35, false, paint..color = green);
    canvas.drawArc(rect, 2.45, 1.15, false, paint..color = yellow);
    canvas.drawArc(rect, 3.60, 2.00, false, paint..color = red);

    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.50),
      Offset(size.width * 0.92, size.height * 0.50),
      Paint()
        ..color = blue
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGMarkPainter oldDelegate) =>
      blue != oldDelegate.blue ||
      red != oldDelegate.red ||
      yellow != oldDelegate.yellow ||
      green != oldDelegate.green;
}

class _AuthOrbitMotifPainter extends CustomPainter {
  final Color ringColor;
  final Color accentColor;
  final Color emeraldColor;
  final Color coralColor;

  const _AuthOrbitMotifPainter({
    required this.ringColor,
    required this.accentColor,
    required this.emeraldColor,
    required this.coralColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r1 = size.width * 0.46;
    final r2 = size.width * 0.34;

    canvas.drawCircle(
      center,
      r1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = ringColor,
    );
    canvas.drawCircle(
      center,
      r2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accentColor.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      center + Offset(r1 * math.cos(-0.6), r1 * math.sin(-0.6)),
      5,
      Paint()..color = emeraldColor,
    );
    canvas.drawCircle(
      center + Offset(r2 * math.cos(2.5), r2 * math.sin(2.5)),
      5,
      Paint()..color = coralColor,
    );
  }

  @override
  bool shouldRepaint(covariant _AuthOrbitMotifPainter oldDelegate) =>
      ringColor != oldDelegate.ringColor ||
      accentColor != oldDelegate.accentColor ||
      emeraldColor != oldDelegate.emeraldColor ||
      coralColor != oldDelegate.coralColor;
}
