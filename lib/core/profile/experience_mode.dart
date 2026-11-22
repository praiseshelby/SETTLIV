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

  ExperienceModeNotifier(this._prefs) : super(ExperienceMode.auto) {
    _load();
  }

  void _load() {
    if (_prefs == null) return;
    final saved = _prefs.getString(prefKey);
    if (saved == 'app') {
      state = ExperienceMode.app;
    } else if (saved == 'web') {
      state = ExperienceMode.web;
    } else {
      state = ExperienceMode.auto;
    }
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

final effectiveExperienceProvider = Provider<EffectiveExperience>((ref) {
  final profile = ref.watch(deviceProfileProvider);
  final mode = ref.watch(experienceModeProvider);

  // Strict Rule: DESKTOP always gets Web, regardless of window size or saved preference.
  // The App experience is NOT reachable on desktop.
  if (profile.isDesktop) {
    return EffectiveExperience.web;
  }

  // TOUCH devices default to App, but may switch to Web.
  if (mode == ExperienceMode.web) {
    return EffectiveExperience.web;
  }
  return EffectiveExperience.app;
});
