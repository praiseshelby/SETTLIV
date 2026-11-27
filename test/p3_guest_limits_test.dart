import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/auth/auth_provider.dart';
import 'package:settliv/core/auth/auth_repository.dart';
import 'package:settliv/core/auth/guest_limit_sheet.dart';
import 'package:settliv/core/auth/guest_limits.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/features/onboarding/domain/tour_scope.dart';

class _TestGuestAuthNotifier extends AuthStateNotifier {
  final AuthStatus _status;
  _TestGuestAuthNotifier(this._status);

  @override
  AuthStatus build() => _status;
}

void main() {
  test('Guest limit constants are SOFT=5 and HARD=12', () {
    expect(GuestLimits.softLimit, 5);
    expect(GuestLimits.hardLimit, 12);
  });

  testWidgets('Soft prompt at 5, hard block at 12, and tour actions do not count',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider
            .overrideWith(() => _TestGuestAuthNotifier(const AuthGuest())),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(guestWriteCountProvider.notifier);

    // Tour actions never count
    for (int i = 0; i < 15; i++) {
      expect(
        notifier.recordWriteAttempt(inTour: true),
        GuestLimitOutcome.allowed,
      );
    }
    expect(container.read(guestWriteCountProvider), 0);

    // Writes 1..4 are allowed without prompt
    for (int i = 1; i < GuestLimits.softLimit; i++) {
      expect(notifier.recordWriteAttempt(), GuestLimitOutcome.allowed);
    }
    expect(container.read(guestWriteCountProvider), 4);

    // Write 5 triggers soft prompt
    expect(notifier.recordWriteAttempt(), GuestLimitOutcome.softPrompt);
    expect(container.read(guestWriteCountProvider), 5);
    expect(prefs.getInt(GuestLimits.prefsKey), 5);

    // Writes 6..11 are allowed
    for (int i = 6; i < GuestLimits.hardLimit; i++) {
      expect(notifier.recordWriteAttempt(), GuestLimitOutcome.allowed);
    }
    expect(container.read(guestWriteCountProvider), 11);

    // Write 12 reaches hard limit, and further writes are hardBlocked
    expect(notifier.recordWriteAttempt(), GuestLimitOutcome.hardReached);
    expect(container.read(guestWriteCountProvider), 12);
    expect(notifier.recordWriteAttempt(), GuestLimitOutcome.hardBlocked);
    expect(container.read(guestWriteCountProvider), 12);

    // Render soft sheet: has Create account, Sign in, Not now
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => GuestLimitSheet.show(context, isHard: false),
                child: const Text('Open Soft'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Soft'));
    await tester.pumpAndSettle();

    expect(find.text('Create an account to keep going.'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Render hard sheet: has Create account, Sign in, NO "Not now"
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => GuestLimitSheet.show(context, isHard: true),
                child: const Text('Open Hard'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open Hard'));
    await tester.pumpAndSettle();

    expect(find.text('Create an account to keep going.'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Not now'), findsNothing);
  });

  test('Signed-in users never hit guest limits and TourScope skips counting',
      () async {
    SharedPreferences.setMockInitialValues({GuestLimits.prefsKey: 12});
    final prefs = await SharedPreferences.getInstance();

    final signedInUser = AuthSignedIn(
      AuthUser(
        id: 'user_1',
        displayName: 'Asha',
        provider: AuthProviderKind.passwordEmail,
        lastLoginAtMs: 1,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider
            .overrideWith(() => _TestGuestAuthNotifier(signedInUser)),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(guestWriteCountProvider), 0);
    final notifier = container.read(guestWriteCountProvider.notifier);
    expect(notifier.isHardBlocked(), isFalse);
    for (int i = 0; i < 20; i++) {
      expect(notifier.recordWriteAttempt(), GuestLimitOutcome.allowed);
    }
    expect(container.read(guestWriteCountProvider), 0);
  });

  testWidgets('GuestWriteGuard ignores writes inside TourScope', (tester) async {
    SharedPreferences.setMockInitialValues({GuestLimits.prefsKey: 12});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider
            .overrideWith(() => _TestGuestAuthNotifier(const AuthGuest())),
      ],
    );
    addTearDown(container.dispose);

    GuestLimitOutcome? observed;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: TourScope(
            homeHeroKey: GlobalKey(),
            homeAttentionKey: GlobalKey(),
            addQuickInputKey: GlobalKey(),
            addSplitModesKey: GlobalKey(),
            addController: TourAddController(),
            child: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () {
                  observed = GuestWriteGuard.checkAndRecord(context, ref);
                },
                child: const Text('Tour Write'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tour Write'));
    await tester.pump();
    expect(observed, GuestLimitOutcome.allowed);
  });
}
