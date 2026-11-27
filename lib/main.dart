import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/auth_provider.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/lock_screen.dart';
import 'core/auth/oauth_web_helper_stub.dart'
    if (dart.library.js_interop) 'core/auth/oauth_web_helper_web.dart';
import 'core/auth/screen_lock_provider.dart';
import 'core/config/app_config.dart';
import 'core/profile/experience_mode.dart' show effectiveExperienceProvider, EffectiveExperience;
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/experience_transition_overlay.dart';
import 'core/widgets/phone_frame.dart';
import 'data/repositories/in_memory_app_repository.dart';
import 'intro_handshake_stub.dart'
    if (dart.library.js_interop) 'intro_handshake_web.dart';
import 'routes/app_router.dart';
import 'supabase_config.dart';

const String kBuildMarker = 'p2-profile-pictures';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print(kBuildMarker);
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}
  try {
    await SupabaseConfig.initializeIfConfigured();
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('SupabaseConfig.initializeIfConfigured error: $e\n$st');
    }
  }
  if (kIsWeb && SupabaseConfig.isInitialized) {
    final code = Uri.base.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      try {
        if (Supabase.instance.client.auth.currentSession == null) {
          await Supabase.instance.client.auth.exchangeCodeForSession(code);
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('OAuth exchangeCodeForSession error: $e\n$st');
        }
        SupabaseConfig.pendingOAuthError =
            'Google sign-in could not be completed. Try again.';
      } finally {
        clearOAuthCodeFromUrl();
      }
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SettlivApp(),
    ),
  );
}

/// Custom scroll behavior that hides scrollbars and overscroll glows app-wide,
/// while supporting touch, mouse drag, trackpad, and mouse wheel scrolling.
class SettlivScrollBehavior extends MaterialScrollBehavior {
  const SettlivScrollBehavior();

  @override
  Widget buildScrollbar(
      BuildContext context, Widget child, ScrollableDetails details) {
    // Hide ALL scrollbars
    return child;
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    // No overscroll glow
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}

class SettlivApp extends ConsumerStatefulWidget {
  final GoRouter? router;
  const SettlivApp({super.key, this.router});

  @override
  ConsumerState<SettlivApp> createState() => _SettlivAppState();
}

class _SettlivAppState extends ConsumerState<SettlivApp> {
  late bool _revealReady;
  bool _postRevealLite = false;
  Timer? _liteTimer;
  final ChangeNotifier _authRefresh = ChangeNotifier();
  GoRouter? _managedRouter;

  @override
  void initState() {
    super.initState();
    _revealReady = !isIntroRevealSupported;
    if (!_revealReady) {
      listenForIntroReveal(() {
        if (mounted && !_revealReady) {
          setState(() {
            _revealReady = true;
            _postRevealLite = true;
          });
          _liteTimer?.cancel();
          _liteTimer = Timer(const Duration(milliseconds: 900), () {
            if (mounted && _postRevealLite) {
              setState(() => _postRevealLite = false);
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _liteTimer?.cancel();
    _authRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final effectiveExperience = ref.watch(effectiveExperienceProvider);
    ref.listen<AuthStatus>(authStateProvider, (_, __) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      _authRefresh.notifyListeners();
    });
    ref.listen<bool>(onboardingPendingProvider, (_, __) {
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      _authRefresh.notifyListeners();
    });
    final router = widget.router ??
        (_managedRouter ??= createAppRouter(
          readAuthStatus: () => ref.read(authStateProvider),
          refreshListenable: _authRefresh,
          isOnboardingPending: () => ref.read(onboardingPendingProvider),
        ));

    return MaterialApp.router(
      title: 'Settliv',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const SettlivScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final lockState = ref.watch(screenLockProvider);
        final Widget content = (AppConfig.kScreenLockEnabled && lockState.isLocked)
            ? const LockScreen()
            : child;

        final media = MediaQuery.of(context);
        final isWideViewport = media.size.width > 600;

        final Widget framed =
            (effectiveExperience == EffectiveExperience.app && isWideViewport)
                ? PhoneFrame(child: content)
                : content;
        return TickerMode(
          enabled: _revealReady,
          child: MediaQuery(
            data: _postRevealLite
                ? media.copyWith(disableAnimations: true)
                : media,
            child: ExperienceTransitionOverlay(child: framed),
          ),
        );
      },
    );
  }
}
