import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:settliv/core/auth/auth_provider.dart';
import 'package:settliv/core/auth/auth_repository.dart';
import 'package:settliv/core/auth/fake_auth_repository.dart';
import 'package:settliv/core/auth/supabase_auth_repository.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/phone_frame.dart';
import 'package:settliv/features/auth/presentation/auth_screens.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Backend Set 1: Auth helpers & FakeAuthRepository', () {
    test('Username validation, normalisation & synthetic email', () {
      expect(UsernameHelper.normalize('  Arjun_99 '), 'arjun_99');
      expect(UsernameHelper.validate('ab'), isNotNull);
      expect(UsernameHelper.validate('a' * 21), isNotNull);
      expect(UsernameHelper.validate('bad user!'), isNotNull);
      expect(UsernameHelper.validate('Arjun_99.x'), isNull);
      expect(
        UsernameHelper.toSyntheticEmail('Arjun_99'),
        'arjun_99@u.settliv.app',
      );
      expect(UsernameHelper.isSyntheticEmail('arjun_99@u.settliv.app'), isTrue);
      expect(UsernameHelper.isSyntheticEmail('arjun@gmail.com'), isFalse);
    });

    test('AuthErrorMapper maps friendly messages & silent OAuth cancel', () {
      expect(
        AuthErrorMapper.map('Invalid login credentials'),
        'Username or password is incorrect',
      );
      expect(
        AuthErrorMapper.map('username_taken'),
        'That username is taken',
      );
      expect(
        AuthErrorMapper.map('Too many requests 429'),
        contains('Too many attempts'),
      );
      expect(
        AuthErrorMapper.map('SocketException: failed host lookup'),
        'No connection. Check your internet and try again.',
      );
      expect(
        AuthErrorMapper.map('weak_password'),
        'Password must be at least 8 characters.',
      );
      expect(
        AuthErrorMapper.map('User already registered'),
        'An account with this email already exists.',
      );
      expect(
        AuthErrorMapper.map('Email not confirmed'),
        'Please confirm your email address before signing in.',
      );
      expect(
        AuthErrorMapper.map('email_address_not_authorized'),
        contains('Email delivery is restricted'),
      );
      expect(AuthErrorMapper.map('User cancelled OAuth'), isNull);
    });

    test('FakeAuthRepository signup, duplicate username, confirmation & delete', () async {
      final repo = FakeAuthRepository();
      await repo.signUpWithUsername(
        fullName: 'Arjun',
        username: 'Arjun_1',
        password: 'password123',
        layout: 'web',
      );
      expect(repo.currentStatus, isA<AuthSignedIn>());
      final user = (repo.currentStatus as AuthSignedIn).user;
      expect(user.username, 'arjun_1');
      expect(user.email, isNull);

      expect(
        () => repo.signUpWithUsername(
          fullName: 'Other',
          username: 'arjun_1',
          password: 'password123',
          layout: 'web',
        ),
        throwsA(
          predicate((e) => e.toString() == 'That username is taken'),
        ),
      );

      await repo.signOut();
      expect(repo.currentStatus, isA<AuthSignedOut>());

      repo.requireEmailConfirmation = true;
      await repo.signUpWithEmail(
        fullName: 'Tara',
        email: 'tara@example.com',
        password: 'password123',
        layout: 'app',
      );
      expect(repo.currentStatus, isA<AuthConfirmationPending>());
      await repo.deleteAccount();
      expect(repo.currentStatus, isA<AuthSignedOut>());
    });
  });

  group('Backend Set 1: Router auth gate & UI', () {
    testWidgets('Router redirects signed out to /welcome?from=... and preserves deep link', (tester) async {
      AuthStatus status = const AuthSignedOut();
      final refresh = ChangeNotifier();
      final router = createAppRouter(
        initialLocation: '/balances',
        readAuthStatus: () => status,
        refreshListenable: refresh,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/welcome');
      expect(
        router.routeInformationProvider.value.uri.queryParameters['from'],
        '/balances',
      );

      status = const AuthGuest();
      refresh.notifyListeners();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/balances');
    });

    testWidgets('AuthLoading gates HomeScreen until resolved to signed out or signed in', (tester) async {
      AuthStatus status = const AuthLoading();
      final refresh = ChangeNotifier();
      final router = createAppRouter(
        initialLocation: '/',
        readAuthStatus: () => status,
        refreshListenable: refresh,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.path, '/auth-loading');

      status = const AuthSignedOut();
      refresh.notifyListeners();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/welcome');
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);

      status = AuthSignedIn(
        const AuthUser(
          id: 'u_1',
          displayName: 'Arjun',
          username: 'arjun',
          provider: AuthProviderKind.passwordUsername,
          lastLoginAtMs: 1,
        ),
      );
      refresh.notifyListeners();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
    });

    testWidgets('Validation shows only after attempt & fits 320px at textScale 1.3', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final fakeRepo = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const AuthScreen(initialMode: AuthFormMode.signUp),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter your full name'), findsNothing);
      expect(find.text('Enter a password'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your full name'), findsOneWidget);
      expect(find.text('Enter a password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('App-layout AuthScreen stays inside PhoneFrame bounds', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const PhoneFrame(
              child: AuthScreen(initialMode: AuthFormMode.signIn),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final phoneBox = tester.getRect(find.byType(PhoneFrame));
      final btnBox = tester.getRect(find.widgetWithText(ElevatedButton, 'Sign in'));
      expect(btnBox.left, greaterThanOrEqualTo(phoneBox.left));
      expect(btnBox.right, lessThanOrEqualTo(phoneBox.right));
      expect(tester.takeException(), isNull);
    });
  });

  group('Backend Set 1: SupabaseAuthRepository session & profile processing', () {
    sb.Session makeSession(String uid, String username) {
      return sb.Session(
        accessToken: 'tok_$uid',
        tokenType: 'bearer',
        user: sb.User(
          id: uid,
          appMetadata: const {'provider': 'email'},
          userMetadata: const {'display_name': 'New User', 'layout': 'web'},
          aud: 'authenticated',
          email: '$username@u.settliv.app',
          createdAt: '2026-11-26T00:00:00Z',
        ),
      );
    }

    test('New username account creates profile, emits AuthSignedIn, and deduplicates duplicate events', () async {
      final authStream = StreamController<sb.AuthState>.broadcast();
      addTearDown(authStream.close);

      int insertCalls = 0;
      Map<String, dynamic>? insertedRow;
      final client = sb.SupabaseClient(
        'https://example.supabase.co',
        'anon_key_placeholder_for_unit_test_only',
      );
      addTearDown(client.dispose);

      final repo = SupabaseAuthRepository(
        client,
        authStateStreamOverride: authStream.stream,
        fetchProfileOverride: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return null;
        },
        insertProfileOverride: (row) async {
          insertCalls++;
          insertedRow = row;
        },
      );
      addTearDown(repo.dispose);

      final emitted = <AuthStatus>[];
      final sub = repo.authStateChanges.listen(emitted.add);
      addTearDown(sub.cancel);

      final session = makeSession('uid_1', 'arjun_new');
      // Fire duplicate signedIn events concurrently
      authStream.add(sb.AuthState(sb.AuthChangeEvent.signedIn, session));
      authStream.add(sb.AuthState(sb.AuthChangeEvent.signedIn, session));

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(insertCalls, 1);
      expect(insertedRow?['id'], 'uid_1');
      expect(insertedRow?['username'], 'arjun_new');
      expect(insertedRow?['provider'], 'password-username');
      expect(repo.currentStatus, isA<AuthSignedIn>());
      final user = (repo.currentStatus as AuthSignedIn).user;
      expect(user.username, 'arjun_new');
      expect(emitted.whereType<AuthSignedIn>().length, 1);
    });

    test('Profile processing failure keeps user signed in with warning and does not emit AuthSignedOut', () async {
      final authStream = StreamController<sb.AuthState>.broadcast();
      addTearDown(authStream.close);

      final client = sb.SupabaseClient(
        'https://example.supabase.co',
        'anon_key_placeholder_for_unit_test_only',
      );
      addTearDown(client.dispose);

      final repo = SupabaseAuthRepository(
        client,
        authStateStreamOverride: authStream.stream,
        fetchProfileOverride: (_) async => null,
        insertProfileOverride: (_) async {
          throw const sb.PostgrestException(
            message: 'permission denied for table profiles',
            code: '42501',
          );
        },
      );
      addTearDown(repo.dispose);

      final emitted = <AuthStatus>[];
      final sub = repo.authStateChanges.listen(emitted.add);
      addTearDown(sub.cancel);

      final session = makeSession('uid_2', 'fail_user');
      await repo.processSessionForTest(session, updateLogin: true);

      expect(repo.currentStatus, isA<AuthSignedIn>());
      final user = (repo.currentStatus as AuthSignedIn).user;
      expect(user.id, 'uid_2');
      expect(user.profileWarning, 'profile_sync 42501');
      expect(emitted.whereType<AuthSignedOut>(), isEmpty);
    });

    testWidgets('Sign-in failure displays error message and re-enables submit button', (tester) async {
      final fakeRepo = _FailingSignInAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const AuthScreen(initialMode: AuthFormMode.signIn),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'arjun_1');
      await tester.enterText(find.byType(TextField).at(1), 'password123');

      final btnFinder = find.widgetWithText(ElevatedButton, 'Sign in');
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Username or password is incorrect'), findsOneWidget);
      final btn = tester.widget<ElevatedButton>(btnFinder);
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Google OAuth return with ?code= holds /auth-loading until AuthSignedIn then lands on Home', (tester) async {
      AuthStatus status = const AuthSignedOut();
      bool pendingCode = true;
      final refresh = ChangeNotifier();
      final router = createAppRouter(
        initialLocation: '/welcome',
        readAuthStatus: () => status,
        refreshListenable: refresh,
        hasPendingOAuthCode: () => pendingCode,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.path, '/auth-loading');

      pendingCode = false;
      status = const AuthSignedIn(
        AuthUser(
          id: 'uid_google_1',
          displayName: 'Google User',
          email: 'user@gmail.com',
          provider: AuthProviderKind.google,
          lastLoginAtMs: 1,
        ),
      );
      refresh.notifyListeners();
      await tester.pumpAndSettle();

      expect(router.routeInformationProvider.value.uri.path, '/');
    });

    testWidgets('AuthLoading on /auth-loading times out after 6 seconds to AuthSignedOut and /welcome', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final refresh = ChangeNotifier();
      container.listen<AuthStatus>(authStateProvider, (_, __) {
        refresh.notifyListeners();
      });

      final router = createAppRouter(
        initialLocation: '/auth-loading',
        readAuthStatus: () => const AuthLoading(),
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
      await tester.pump();
      expect(router.routeInformationProvider.value.uri.path, '/auth-loading');

      // Advance past 6s timeout -> forceSignedOut & navigate to /welcome
      await tester.pump(const Duration(seconds: 7));
      expect(container.read(authStateProvider), isA<AuthSignedOut>());
    });
  });
}

class _FailingSignInAuthRepository extends FakeAuthRepository {
  @override
  Future<void> signInWithUsername({
    required String username,
    required String password,
  }) async {
    throw const AuthFriendlyException('Username or password is incorrect');
  }
}
