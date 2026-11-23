import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_profile.dart';

enum ExperienceMode {
  auto,
  app,
  web,
}

enum EffectiveExperience {
  app,
  web,
}

final deviceProfileProvider = Provider<DeviceProfile>((ref) {
  return DeviceProfile.detect();
});

class ExperienceModeNotifier extends StateNotifier<ExperienceMode> {
  static const String prefKey = 'settliv_experience_mode';
  final SharedPreferences? _prefs;

  ExperienceModeNotifier(this._prefs) : super(_resolveInitial(_prefs));

  static ExperienceMode _resolveInitial(SharedPreferences? prefs) {
    if (prefs == null) return ExperienceMode.auto;
    final saved = prefs.getString(prefKey);
    if (saved == 'app') return ExperienceMode.app;
    if (saved == 'web') return ExperienceMode.web;
    return ExperienceMode.auto;
  }

  Future<void> setMode(ExperienceMode mode) async {
    state = mode;
    if (_prefs != null) {
      if (mode == ExperienceMode.auto) {
        await _prefs.remove(prefKey);
      } else {
        await _prefs.setString(prefKey, mode.name);
      }
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  // Override in main.dart or tests with initialized instance
  return null;
});

final experienceModeProvider =
    StateNotifierProvider<ExperienceModeNotifier, ExperienceMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ExperienceModeNotifier(prefs);
});

EffectiveExperience resolveEffectiveExperience({
  required DeviceProfile profile,
  required ExperienceMode mode,
}) {
  // Resolution table:
  // desktop + none (auto) -> Web
  // desktop + app        -> App
  // desktop + web        -> Web
  // touch   + none (auto) -> App
  // touch   + app        -> App
  // touch   + web        -> Web
  if (mode == ExperienceMode.app) {
    return EffectiveExperience.app;
  }
  if (mode == ExperienceMode.web) {
    return EffectiveExperience.web;
  }

  // mode == ExperienceMode.auto (none chosen)
  if (profile.isDesktop) {
    return EffectiveExperience.web;
  }
  return EffectiveExperience.app;
}

final effectiveExperienceProvider = Provider<EffectiveExperience>((ref) {
  final profile = ref.watch(deviceProfileProvider);
  final mode = ref.watch(experienceModeProvider);

  return resolveEffectiveExperience(profile: profile, mode: mode);
});
