import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'device_auth.dart';
import '../../data/repositories/in_memory_app_repository.dart';

class ScreenLockState {
  final bool isEnabled;
  final bool isLocked;
  final LockTimeout timeout;
  final String? credentialId;
  final bool isAuthenticating;
  final String? errorMessage;

  const ScreenLockState({
    required this.isEnabled,
    required this.isLocked,
    required this.timeout,
    this.credentialId,
    this.isAuthenticating = false,
    this.errorMessage,
  });

  ScreenLockState copyWith({
    bool? isEnabled,
    bool? isLocked,
    LockTimeout? timeout,
    String? credentialId,
    bool? isAuthenticating,
    String? errorMessage,
  }) {
    return ScreenLockState(
      isEnabled: isEnabled ?? this.isEnabled,
      isLocked: isLocked ?? this.isLocked,
      timeout: timeout ?? this.timeout,
      credentialId: credentialId ?? this.credentialId,
      isAuthenticating: isAuthenticating ?? this.isAuthenticating,
      errorMessage: errorMessage,
    );
  }
}

class ScreenLockNotifier extends Notifier<ScreenLockState> with WidgetsBindingObserver {
  static const String _kEnabledKey = 'settliv_screen_lock_enabled';
  static const String _kCredentialIdKey = 'settliv_screen_lock_credential_id';
  static const String _kTimeoutKey = 'settliv_screen_lock_timeout';

  DateTime? _backgroundedAt;

  @override
  ScreenLockState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
    });

    final prefs = ref.watch(sharedPreferencesProvider);
    final isEnabled = prefs?.getBool(_kEnabledKey) ?? false;
    final credId = prefs?.getString(_kCredentialIdKey);
    final timeoutStr = prefs?.getString(_kTimeoutKey);
    final timeout = LockTimeout.values.firstWhere(
      (t) => t.name == timeoutStr,
      orElse: () => LockTimeout.immediately,
    );

    // Gated before content: if enabled, start locked
    return ScreenLockState(
      isEnabled: isEnabled && credId != null,
      isLocked: isEnabled && credId != null,
      timeout: timeout,
      credentialId: credId,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!this.state.isEnabled) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      final elapsed = DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (elapsed >= this.state.timeout.duration) {
        this.state = this.state.copyWith(isLocked: true);
      }
    }
  }

  String _generateChallenge() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<bool> enableLock() async {
    final auth = ref.read(deviceAuthProvider);
    state = state.copyWith(isAuthenticating: true, errorMessage: null);

    final challenge = _generateChallenge();
    final credId = await auth.registerCredential(
      challenge: challenge,
      rpId: 'localhost',
      userId: 'settliv_user_${DateTime.now().millisecondsSinceEpoch}',
      userName: 'Settliv User',
    );

    if (credId != null) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs?.setBool(_kEnabledKey, true);
      await prefs?.setString(_kCredentialIdKey, credId);

      state = state.copyWith(
        isEnabled: true,
        isLocked: false,
        credentialId: credId,
        isAuthenticating: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: 'Device authentication could not be completed.',
      );
      return false;
    }
  }

  Future<bool> disableLock() async {
    if (!state.isEnabled || state.credentialId == null) {
      return true;
    }
    final auth = ref.read(deviceAuthProvider);
    state = state.copyWith(isAuthenticating: true, errorMessage: null);

    final challenge = _generateChallenge();
    final ok = await auth.verifyCredential(
      credentialId: state.credentialId!,
      challenge: challenge,
      rpId: 'localhost',
    );

    if (ok) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs?.setBool(_kEnabledKey, false);
      await prefs?.remove(_kCredentialIdKey);

      state = state.copyWith(
        isEnabled: false,
        isLocked: false,
        credentialId: null,
        isAuthenticating: false,
      );
      return true;
    } else {
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: 'Verification failed. Lock remains enabled.',
      );
      return false;
    }
  }

  Future<bool> unlock() async {
    if (!state.isLocked) return true;
    if (state.credentialId == null) {
      state = state.copyWith(isLocked: false);
      return true;
    }

    final auth = ref.read(deviceAuthProvider);
    state = state.copyWith(isAuthenticating: true, errorMessage: null);

    final challenge = _generateChallenge();
    final ok = await auth.verifyCredential(
      credentialId: state.credentialId!,
      challenge: challenge,
      rpId: 'localhost',
    );

    if (ok) {
      state = state.copyWith(isLocked: false, isAuthenticating: false);
      return true;
    } else {
      state = state.copyWith(
        isAuthenticating: false,
        errorMessage: 'Authentication cancelled or failed.',
      );
      return false;
    }
  }

  Future<void> setTimeout(LockTimeout timeout) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setString(_kTimeoutKey, timeout.name);
    state = state.copyWith(timeout: timeout);
  }

  Future<void> turnOffLockAndEraseAllData() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs?.setBool(_kEnabledKey, false);
    await prefs?.remove(_kCredentialIdKey);
    await prefs?.remove(_kTimeoutKey);

    await ref.read(appStateProvider.notifier).deleteAllData();

    state = const ScreenLockState(
      isEnabled: false,
      isLocked: false,
      timeout: LockTimeout.immediately,
      credentialId: null,
    );
  }
}

final screenLockProvider =
    NotifierProvider<ScreenLockNotifier, ScreenLockState>(ScreenLockNotifier.new);
