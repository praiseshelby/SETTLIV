import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/in_memory_app_repository.dart';
import '../../supabase_config.dart';
import 'auth_repository.dart';
import 'oauth_web_helper_stub.dart'
    if (dart.library.js_interop) 'oauth_web_helper_web.dart';
import 'supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!SupabaseConfig.isSupabaseConfigured || !SupabaseConfig.isInitialized) {
    return null;
  }
  final repo = SupabaseAuthRepository(Supabase.instance.client);
  ref.onDispose(repo.dispose);
  return repo;
});

final authStateProvider = NotifierProvider<AuthStateNotifier, AuthStatus>(
  AuthStateNotifier.new,
);

final onboardingPendingProvider =
    NotifierProvider<OnboardingPendingNotifier, bool>(
  OnboardingPendingNotifier.new,
);

class OnboardingPendingNotifier extends Notifier<bool> {
  static String keyForUid(String uid) => 'settliv_onboarding_pending_$uid';
  static const String guestOfferShownKey = 'settliv_guest_tour_offered';
  static const String guestTourPendingKey = 'settliv_onboarding_pending_guest';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authStatus = ref.watch(authStateProvider);
    if (authStatus is AuthSignedIn) {
      final key = keyForUid(authStatus.user.id);
      if (authStatus.user.isNewProfile) {
        prefs?.setBool(key, true);
        return true;
      }
      return prefs?.getBool(key) ?? false;
    }
    if (authStatus is AuthGuest) {
      return prefs?.getBool(guestTourPendingKey) ?? false;
    }
    return false;
  }

  Future<void> startGuestTour() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(guestOfferShownKey, true);
    await prefs?.setBool(guestTourPendingKey, true);
    state = true;
  }

  Future<void> markGuestTourOffered() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(guestOfferShownKey, true);
  }

  Future<void> completeOnboarding() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final authStatus = ref.read(authStateProvider);
    if (authStatus is AuthSignedIn) {
      await prefs?.remove(keyForUid(authStatus.user.id));
    }
    await prefs?.remove(guestTourPendingKey);
    state = false;
    if (authStatus is AuthSignedIn) {
      final repo = ref.read(authRepositoryProvider);
      if (repo != null) {
        unawaited(repo.markOnboarded());
      }
    }
  }
}

class AuthStateNotifier extends Notifier<AuthStatus> {
  static const String _guestPrefKey = 'settliv_guest_mode';
  StreamSubscription<AuthStatus>? _sub;

  @override
  AuthStatus build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final repo = ref.watch(authRepositoryProvider);

    _sub?.cancel();
    if (repo != null) {
      _sub = repo.authStateChanges.listen((next) {
        print('[AUTH] AuthStateNotifier state -> $next');
        if (next is AuthSignedIn) {
          prefs?.setBool(_guestPrefKey, false);
          if (next.user.isNewProfile) {
            prefs?.setBool(
              OnboardingPendingNotifier.keyForUid(next.user.id),
              true,
            );
          }
        }
        state = next;
      });
      ref.onDispose(() => _sub?.cancel());
    }

    if (repo != null && repo.currentStatus is AuthSignedIn) {
      final signedIn = repo.currentStatus as AuthSignedIn;
      prefs?.setBool(_guestPrefKey, false);
      if (signedIn.user.isNewProfile) {
        prefs?.setBool(
          OnboardingPendingNotifier.keyForUid(signedIn.user.id),
          true,
        );
      }
      return signedIn;
    }
    if (prefs?.getBool(_guestPrefKey) == true) {
      return const AuthGuest();
    }
    if (repo != null) {
      return repo.currentStatus;
    }
    return const AuthSignedOut();
  }

  Future<void> enterGuestMode() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_guestPrefKey, true);
    state = const AuthGuest();
  }

  Future<void> exitGuestMode() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_guestPrefKey, false);
    state = const AuthSignedOut();
  }

  void clearConfirmationPending() {
    if (state is AuthConfirmationPending) {
      state = const AuthSignedOut();
    }
  }

  Future<void> signUpWithUsername({
    required String fullName,
    required String username,
    required String password,
    required String layout,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      throw const AuthFriendlyException(
        'Cloud accounts are not set up in this build',
      );
    }
    await repo.signUpWithUsername(
      fullName: fullName,
      username: username,
      password: password,
      layout: layout,
    );
  }

  Future<void> signUpWithEmail({
    required String fullName,
    required String email,
    required String password,
    required String layout,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      throw const AuthFriendlyException(
        'Cloud accounts are not set up in this build',
      );
    }
    await repo.signUpWithEmail(
      fullName: fullName,
      email: email,
      password: password,
      layout: layout,
    );
  }

  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      throw const AuthFriendlyException(
        'Cloud accounts are not set up in this build',
      );
    }
    await repo.signInWithUsername(username: username, password: password);
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      throw const AuthFriendlyException(
        'Cloud accounts are not set up in this build',
      );
    }
    await repo.signInWithEmail(email: email, password: password);
  }

  Future<void> signInWithGoogle({required String layout}) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      throw const AuthFriendlyException(
        'Cloud accounts are not set up in this build',
      );
    }
    await repo.signInWithGoogle(layout: layout);
  }

  Future<void> sendPasswordReset({required String email}) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      throw const AuthFriendlyException(
        'Cloud accounts are not set up in this build',
      );
    }
    await repo.sendPasswordReset(email: email);
  }

  void forceSignedOut() {
    print('[AUTH] AuthStateNotifier.forceSignedOut');
    final prefs = ref.read(sharedPreferencesProvider);
    prefs?.setBool(_guestPrefKey, false);
    prefs?.remove(OnboardingPendingNotifier.guestTourPendingKey);
    clearOAuthCodeFromUrl();
    state = const AuthSignedOut();
  }

  Future<void> signOut() async {
    print('[AUTH] AuthStateNotifier.signOut called');
    final current = state;
    final String? uid = current is AuthSignedIn ? current.user.id : null;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_guestPrefKey, false);
    if (uid != null) {
      await prefs?.remove(OnboardingPendingNotifier.keyForUid(uid));
    }
    await prefs?.remove(OnboardingPendingNotifier.guestTourPendingKey);
    final repo = ref.read(authRepositoryProvider);
    if (repo != null) {
      try {
        await repo.signOut();
      } catch (e, st) {
        print('[AUTH] AuthStateNotifier.signOut error: $e\n$st');
      }
    }
    state = const AuthSignedOut();
    replaceUrlToWelcome();
  }

  Future<void> deleteAccount({String? password}) async {
    print('[AUTH] AuthStateNotifier.deleteAccount called');
    final current = state;
    final String? uid = current is AuthSignedIn ? current.user.id : null;
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      throw const AuthFriendlyException(
        'Cloud accounts are not set up in this build',
      );
    }
    await repo.deleteAccount(password: password);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_guestPrefKey, false);
    if (uid != null) {
      await prefs?.remove('settliv_ledger_uid_$uid');
      await prefs?.remove(OnboardingPendingNotifier.keyForUid(uid));
    }
    await prefs?.remove(OnboardingPendingNotifier.guestTourPendingKey);
    state = const AuthSignedOut();
    replaceUrlToWelcome();
  }
}
