import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/in_memory_app_repository.dart';
import 'auth_provider.dart';
import 'auth_repository.dart';

class GuestLimits {
  GuestLimits._();

  static const int softLimit = 5;
  static const int hardLimit = 12;
  static const String prefsKey = 'settliv_guest_write_count';
}

enum GuestLimitOutcome {
  allowed,
  softPrompt,
  hardReached,
  hardBlocked,
}

final guestWriteCountProvider =
    NotifierProvider<GuestWriteCountNotifier, int>(GuestWriteCountNotifier.new);

class GuestWriteCountNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authStatus = ref.watch(authStateProvider);
    if (authStatus is AuthSignedIn) {
      return 0;
    }
    final saved = prefs?.getInt(GuestLimits.prefsKey) ?? 0;
    return saved < 0 ? 0 : saved;
  }

  bool isHardBlocked() {
    final authStatus = ref.read(authStateProvider);
    if (authStatus is! AuthGuest) return false;
    return state >= GuestLimits.hardLimit;
  }

  GuestLimitOutcome recordWriteAttempt({bool inTour = false}) {
    if (inTour) return GuestLimitOutcome.allowed;
    final authStatus = ref.read(authStateProvider);
    if (authStatus is! AuthGuest) return GuestLimitOutcome.allowed;
    if (state >= GuestLimits.hardLimit) {
      return GuestLimitOutcome.hardBlocked;
    }
    final next = state + 1;
    state = next;
    ref.read(sharedPreferencesProvider)?.setInt(GuestLimits.prefsKey, next);
    if (next == GuestLimits.softLimit) {
      return GuestLimitOutcome.softPrompt;
    }
    if (next >= GuestLimits.hardLimit) {
      return GuestLimitOutcome.hardReached;
    }
    return GuestLimitOutcome.allowed;
  }

  Future<void> reset() async {
    state = 0;
    await ref.read(sharedPreferencesProvider)?.remove(GuestLimits.prefsKey);
  }
}
