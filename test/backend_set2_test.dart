import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/auth/auth_provider.dart';
import 'package:settliv/core/auth/auth_repository.dart';
import 'package:settliv/core/auth/fake_auth_repository.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/phone_frame.dart';
import 'package:settliv/data/models/group.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/repositories/supabase_ledger_repository.dart';
import 'package:settliv/features/auth/presentation/auth_screens.dart';
import 'package:settliv/features/settings/presentation/widgets/account_settings_section.dart';
import 'package:settliv/routes/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Backend Set 2: Data isolation & account switching', () {
    test('Two users and guest mode have isolated UID-namespaced caches and sign-out clears state', () async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      // 1) Guest adds a group
      await container.read(authStateProvider.notifier).enterGuestMode();
      container.read(appStateProvider.notifier).addGroup(
            const Group(
              id: 'grp_guest_only',
              name: 'Guest Group',
              type: GroupType.other,
              coverThemeIndex: 2,
              memberIds: ['u_arjun', 'u_kabir'],
            ),
          );
      expect(
        container.read(allGroupsProvider).any((g) => g.id == 'grp_guest_only'),
        isTrue,
      );

      // 2) User A signs in -> guest data does not leak into User A
      await fakeAuth.signUpWithUsername(
        fullName: 'Alice',
        username: 'alice_1',
        password: 'password123',
        layout: 'web',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(allGroupsProvider).any((g) => g.id == 'grp_guest_only'),
        isFalse,
      );
      container.read(appStateProvider.notifier).addGroup(
            const Group(
              id: 'grp_alice',
              name: 'Alice Trip',
              type: GroupType.trip,
              coverThemeIndex: 1,
              memberIds: ['u_arjun', 'u_kabir'],
            ),
          );
      expect(
        container.read(allGroupsProvider).any((g) => g.id == 'grp_alice'),
        isTrue,
      );

      // 3) Sign out clears User A's in-memory state
      await container.read(authStateProvider.notifier).signOut();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(allGroupsProvider).any((g) => g.id == 'grp_alice'),
        isFalse,
      );

      // 4) User B signs in -> never sees User A's data
      await fakeAuth.signUpWithUsername(
        fullName: 'Bob',
        username: 'bob_2',
        password: 'password123',
        layout: 'web',
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(allGroupsProvider).any((g) => g.id == 'grp_alice'),
        isFalse,
      );
    });

    test('SQL migration enables RLS on all 9 ledger tables and defines atomic RPCs', () {
      final sql = File('supabase/migrations/202611260002_ledger_schema.sql')
          .readAsStringSync();
      for (final tbl in [
        'people',
        'groups',
        'expenses',
        'settlements',
        'ious',
        'recurring',
        'budgets',
        'goals',
        'user_settings',
      ]) {
        expect(sql.contains("'$tbl'"), isTrue);
      }
      expect(sql, contains('enable row level security'));
      expect(sql, contains('auth.uid() = user_id'));
      expect(sql, contains('rpc_insert_settlements'));
      expect(sql, contains('rpc_delete_settlements'));
    });

    test('Ledger initialize failure falls back to offline mode and never signs user out', () async {
      final prefs = await SharedPreferences.getInstance();
      final client = sb.SupabaseClient(
        'https://invalid.local.invalid',
        'anon_key_placeholder_for_unit_test_only',
      );
      addTearDown(client.dispose);

      LedgerSyncState? latestSync;
      final repo = SupabaseLedgerRepository(
        client: client,
        uid: 'uid_offline_test',
        prefs: prefs,
        onSyncStateChanged: (s) => latestSync = s,
      );
      addTearDown(repo.dispose);

      await repo.initialize();
      expect(latestSync?.isOffline, isTrue);
      expect(repo.getGroups().isNotEmpty, isTrue);
    });
  });

  group('Backend Set 2: Settings Account section UI', () {
    testWidgets('Offline state shows honest status, fits 320px at 1.3x, and stays inside PhoneFrame', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final fakeAuth = FakeAuthRepository();
      await fakeAuth.signUpWithUsername(
        fullName: 'Kabir',
        username: 'kabir_7',
        password: 'password123',
        layout: 'app',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuth),
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
            ledgerSyncStateProvider.overrideWith(
              (ref) => const LedgerSyncState(isOffline: true),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: PhoneFrame(
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 740),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: AccountSettingsSection(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kabir'), findsOneWidget);
      expect(find.text('@kabir_7'), findsOneWidget);
      expect(find.text('Offline — showing cached data'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Delete account and data'), findsOneWidget);

      final phoneBox = tester.getRect(find.byType(PhoneFrame));
      final delBox = tester.getRect(find.text('Delete account and data'));
      expect(delBox.left, greaterThanOrEqualTo(phoneBox.left));
      expect(delBox.right, lessThanOrEqualTo(phoneBox.right));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Delete account flow navigates cleanly to /welcome with no blank tree or exception', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.signUpWithUsername(
        fullName: 'Disposable User',
        username: 'disp_user_1',
        password: 'password123',
        layout: 'web',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
          effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
        ],
      );
      addTearDown(container.dispose);

      final refresh = ChangeNotifier();
      container.listen<AuthStatus>(authStateProvider, (_, __) {
        refresh.notifyListeners();
      });

      final router = createAppRouter(
        initialLocation: '/settings',
        readAuthStatus: () => container.read(authStateProvider),
        refreshListenable: refresh,
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

      await tester.tap(find.text('Delete account and data'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'DELETE');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      await tester.tap(find.text('Delete permanently'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/welcome');
      expect(find.byType(WelcomeAuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sign out flow navigates cleanly to /welcome with no blank tree or exception', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.signUpWithUsername(
        fullName: 'Signout User',
        username: 'signout_user_1',
        password: 'password123',
        layout: 'web',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
          effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
        ],
      );
      addTearDown(container.dispose);

      final refresh = ChangeNotifier();
      container.listen<AuthStatus>(authStateProvider, (_, __) {
        refresh.notifyListeners();
      });

      final router = createAppRouter(
        initialLocation: '/settings',
        readAuthStatus: () => container.read(authStateProvider),
        refreshListenable: refresh,
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

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/welcome');
      expect(find.byType(WelcomeAuthScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
