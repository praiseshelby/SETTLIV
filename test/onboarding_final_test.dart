import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/auth/auth_provider.dart';
import 'package:settliv/core/auth/fake_auth_repository.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/repositories/persistent_app_repository.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Onboarding Final Stage 3: Full 6-Step Real-Screen Tour & Guest End Sheet', () {
    testWidgets('Full 6-step signed-up tour traverses real screens with zero real repo writes and finishes on /', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      final realRepo = PersistentAppRepository(prefs: prefs, storageKey: 'real_stage3_test');
      await realRepo.startFresh();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
          appRepositoryProvider.overrideWithValue(realRepo),
          effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
        ],
      );
      addTearDown(container.dispose);

      await fakeAuth.signUpWithUsername(
        fullName: 'Riya',
        username: 'riya_3',
        password: 'password123',
        layout: 'app',
      );
      await Future<void>.delayed(Duration.zero);

      final refresh = ChangeNotifier();
      container.listen<bool>(onboardingPendingProvider, (_, __) {
        refresh.notifyListeners();
      });

      final router = createAppRouter(
        initialLocation: '/',
        readAuthStatus: () => container.read(authStateProvider),
        refreshListenable: refresh,
        isOnboardingPending: () => container.read(onboardingPendingProvider),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/tour');
      expect(find.text('Hi Riya.'), findsOneWidget);

      // Step 1 -> 2a -> 2b -> 3a -> 3b -> 4a -> 4b -> 5a -> 5b -> 6
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('Your whole position, one number.'), findsOneWidget);

      while (find.text('Your account is empty and ready.').evaluate().isEmpty) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      expect(find.text('Add first expense'), findsOneWidget);
      expect(find.text('Go to Home'), findsOneWidget);
      expect(realRepo.getAllExpenses(), isEmpty);

      await tester.tap(find.text('Go to Home'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(container.read(onboardingPendingProvider), isFalse);
      expect(realRepo.getAllExpenses(), isEmpty);
    });

    testWidgets('Guest Finish shows Keep what you build end sheet and Continue exploring lands on /', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
        ],
      );
      addTearDown(container.dispose);

      await container.read(onboardingPendingProvider.notifier).startGuestTour();
      await container.read(authStateProvider.notifier).enterGuestMode();

      final refresh = ChangeNotifier();
      container.listen<bool>(onboardingPendingProvider, (_, __) {
        refresh.notifyListeners();
      });

      final router = createAppRouter(
        initialLocation: '/tour',
        readAuthStatus: () => container.read(authStateProvider),
        refreshListenable: refresh,
        isOnboardingPending: () => container.read(onboardingPendingProvider),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hi there.'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      while (find.text('Your account is empty and ready.').evaluate().isEmpty) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Keep what you build.'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Continue exploring'), findsOneWidget);

      await tester.tap(find.text('Continue exploring'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(container.read(onboardingPendingProvider), isFalse);
    });
  });
}
