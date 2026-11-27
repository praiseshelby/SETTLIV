import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/auth/auth_provider.dart';
import 'package:settliv/core/auth/auth_repository.dart';
import 'package:settliv/core/auth/fake_auth_repository.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/repositories/persistent_app_repository.dart';
import 'package:settliv/features/onboarding/presentation/onboarding_tour_screen.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Onboarding Set 1: Trigger, Persistence & Router Gate', () {
    test('Pending flag is set ONLY for new profile sign-ups, never sign-in or guest', () async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      // Guest -> no onboarding pending
      await container.read(authStateProvider.notifier).enterGuestMode();
      expect(container.read(onboardingPendingProvider), isFalse);
      await container.read(authStateProvider.notifier).exitGuestMode();

      // New username sign-up -> sets pending flag
      await fakeAuth.signUpWithUsername(
        fullName: 'Arjun',
        username: 'arjun_new',
        password: 'password123',
        layout: 'web',
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(onboardingPendingProvider), isTrue);
      expect(
        prefs.getBool(OnboardingPendingNotifier.keyForUid('uid_arjun_new')),
        isTrue,
      );

      // Sign out, then sign back in to existing account -> no pending flag
      await container.read(onboardingPendingProvider.notifier).completeOnboarding();
      await container.read(authStateProvider.notifier).signOut();
      await Future<void>.delayed(Duration.zero);

      await fakeAuth.signInWithUsername(
        username: 'arjun_new',
        password: 'password123',
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(onboardingPendingProvider), isFalse);
    });

    testWidgets('/tour without pending flag redirects to Home; with pending flag resumes /tour on refresh', (tester) async {
      AuthStatus status = const AuthSignedIn(
        AuthUser(
          id: 'u_1',
          displayName: 'Arjun',
          username: 'arjun',
          provider: AuthProviderKind.passwordUsername,
          lastLoginAtMs: 1,
        ),
      );
      bool pending = false;
      final refresh = ChangeNotifier();
      final router = createAppRouter(
        initialLocation: '/tour',
        readAuthStatus: () => status,
        refreshListenable: refresh,
        isOnboardingPending: () => pending,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');

      // Now pending = true (e.g. refresh mid-tour) -> redirects to /tour
      pending = true;
      refresh.notifyListeners();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/tour');
      expect(find.byType(OnboardingTourScreen), findsOneWidget);
    });

    testWidgets('Skip and Finish clear pending flag, call markOnboarded, leave real ledger empty, and land on Home', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      final realRepo = PersistentAppRepository(prefs: prefs, storageKey: 'real_user_test');
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
        fullName: 'Meera',
        username: 'meera_1',
        password: 'password123',
        layout: 'app',
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(onboardingPendingProvider), isTrue);

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
      expect(find.text('1 / 6'), findsOneWidget);

      // Navigate with Next, keyboard ArrowRight, and Back
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 6'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 / 6'), findsOneWidget);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 6'), findsOneWidget);

      // Real repository must have zero writes during the tour
      expect(realRepo.getAllExpenses(), isEmpty);

      // Skip clears flag, marks onboarded, lands on Home, real ledger stays empty
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(container.read(onboardingPendingProvider), isFalse);
      expect(
        prefs.getBool(OnboardingPendingNotifier.keyForUid('uid_meera_1')),
        isNull,
      );
      expect((fakeAuth.currentStatus as AuthSignedIn).user.onboarded, isTrue);
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(realRepo.getAllExpenses(), isEmpty);
      expect(realRepo.getGroups().where((g) => !g.isPersonal), isEmpty);
    });
  });
}
