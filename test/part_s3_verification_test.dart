import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:settliv/core/auth/device_auth.dart';
import 'package:settliv/core/auth/device_auth_fake.dart';
import 'package:settliv/core/auth/lock_screen.dart';
import 'package:settliv/core/auth/screen_lock_provider.dart';
import 'package:settliv/core/config/app_config.dart';
import 'package:settliv/core/profile/experience_mode.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/data/models/feedback_report.dart';
import 'package:settliv/data/models/savings_goal.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/features/insights/presentation/insights_screen.dart';
import 'package:settliv/features/insights/presentation/widgets/month_recap_card.dart';
import 'package:settliv/features/insights/presentation/widgets/spending_calendar.dart';
import 'package:settliv/features/plan/presentation/plan_screen.dart';
import 'package:settliv/features/settings/presentation/settings_screen.dart';
import 'package:settliv/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part S3: Savings Goals Unit Tests', () {
    late InMemoryAppRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = InMemoryAppRepository();
    });

    test('Initial seeded savings goals exist', () {
      final goals = repo.getSavingsGoals();
      expect(goals.length, greaterThanOrEqualTo(2));
      expect(goals.any((g) => g.name == 'Emergency Fund'), isTrue);
      expect(goals.any((g) => g.name == 'Goa Next Trip'), isTrue);
    });

    test('Add, contribute, withdraw and achieve savings goal', () {
      final goal = SavingsGoal(
        id: 'test_goal',
        name: 'New Laptop',
        targetPaise: 8000000, // ₹80,000
        savedPaise: 2000000,  // ₹20,000
        createdAt: DateTime.now(),
      );
      repo.addSavingsGoal(goal);

      expect(repo.getSavingsGoal('test_goal'), isNotNull);
      expect(repo.getSavingsGoal('test_goal')!.isAchieved, isFalse);
      expect(repo.getSavingsGoal('test_goal')!.progress, 0.25);

      // Contribute ₹40,000
      repo.contributeToSavingsGoal('test_goal', 4000000);
      expect(repo.getSavingsGoal('test_goal')!.savedPaise, 6000000);
      expect(repo.getSavingsGoal('test_goal')!.progress, 0.75);

      // Contribute ₹30,000 (exceeding target -> achieved)
      repo.contributeToSavingsGoal('test_goal', 3000000);
      expect(repo.getSavingsGoal('test_goal')!.savedPaise, 9000000);
      expect(repo.getSavingsGoal('test_goal')!.isAchieved, isTrue);
      expect(repo.getSavingsGoal('test_goal')!.progress, 1.0);

      // Withdraw ₹20,000
      repo.withdrawFromSavingsGoal('test_goal', 2000000);
      expect(repo.getSavingsGoal('test_goal')!.savedPaise, 7000000);
      expect(repo.getSavingsGoal('test_goal')!.isAchieved, isFalse);

      // Delete goal
      repo.deleteSavingsGoal('test_goal');
      expect(repo.getSavingsGoal('test_goal'), isNull);
    });

    test('Savings goals are included in JSON backup and restored', () {
      final jsonStr = repo.exportLedgerJson();
      expect(jsonStr.contains('savingsGoals'), isTrue);
      expect(jsonStr.contains('Emergency Fund'), isTrue);

      final newRepo = InMemoryAppRepository();
      final ok = newRepo.restoreFromJson(jsonStr);
      expect(ok, isTrue);
      expect(newRepo.getSavingsGoals().length, greaterThanOrEqualTo(2));
    });
  });

  group('Part S3: Help & Feedback Unit Tests', () {
    late InMemoryAppRepository repo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = InMemoryAppRepository();
    });

    test('Feedback report formatting and local queue management', () {
      final report = FeedbackReport(
        id: 'fb_1',
        type: FeedbackType.problem,
        category: 'Calculation / Ledger',
        description: 'Settlement calculation discrepancy on trip expense',
        contactEmail: 'user@example.com',
        deviceInfo: {
          'App Version': AppConfig.versionString,
          'Platform': 'web',
        },
        createdAt: DateTime.now(),
      );

      final text = report.formatAsText();
      expect(text.contains('Settliv Feedback Report'), isTrue);
      expect(text.contains('Problem report'), isTrue);
      expect(text.contains('Calculation / Ledger'), isTrue);
      expect(text.contains('user@example.com'), isTrue);
      expect(text.contains('Saved on this device'), isTrue);

      repo.addFeedbackReport(report);
      expect(repo.getFeedbackReports().length, 1);
      expect(repo.getFeedbackReports().first.id, 'fb_1');

      repo.deleteFeedbackReport('fb_1');
      expect(repo.getFeedbackReports().isEmpty, isTrue);
    });
  });

  group('Part S3: DeviceAuth & Screen Lock Logic', () {
    test('Screen lock enable, authenticate, timeout, and unlock with FakeDeviceAuth', () async {
      SharedPreferences.setMockInitialValues({});
      final fakeAuth = FakeDeviceAuth(isAvailable: true, shouldSucceed: true);

      final container = ProviderContainer(
        overrides: [
          deviceAuthProvider.overrideWithValue(fakeAuth),
        ],
      );

      final notifier = container.read(screenLockProvider.notifier);
      final initial = container.read(screenLockProvider);
      expect(initial.isEnabled, isFalse);
      expect(initial.isLocked, isFalse);

      // Enable lock
      final enabled = await notifier.enableLock();
      expect(enabled, isTrue);
      expect(container.read(screenLockProvider).isEnabled, isTrue);
      expect(container.read(screenLockProvider).credentialId, isNotNull);

      // Simulate app backgrounding past timeout
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(container.read(screenLockProvider).isLocked, isTrue);

      // Unlock with auth success
      final unlocked = await notifier.unlock();
      expect(unlocked, isTrue);
      expect(container.read(screenLockProvider).isLocked, isFalse);

      // Disable lock
      final disabled = await notifier.disableLock();
      expect(disabled, isTrue);
      expect(container.read(screenLockProvider).isEnabled, isFalse);
    });

    test('Screen lock stays locked on authentication cancellation or failure', () async {
      SharedPreferences.setMockInitialValues({});
      final fakeAuth = FakeDeviceAuth(isAvailable: true, shouldSucceed: true);

      final container = ProviderContainer(
        overrides: [
          deviceAuthProvider.overrideWithValue(fakeAuth),
        ],
      );

      final notifier = container.read(screenLockProvider.notifier);
      await notifier.enableLock();

      // Lock app
      notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(container.read(screenLockProvider).isLocked, isTrue);

      // Switch fake to fail auth
      fakeAuth.shouldSucceed = false;
      final success = await notifier.unlock();
      expect(success, isFalse);
      expect(container.read(screenLockProvider).isLocked, isTrue);
      expect(container.read(screenLockProvider).errorMessage, isNotNull);
    });

    test('Screen lock unavailable on unsupported devices shows explanation', () async {
      SharedPreferences.setMockInitialValues({});
      final fakeAuth = FakeDeviceAuth(isAvailable: false);

      final container = ProviderContainer(
        overrides: [
          deviceAuthProvider.overrideWithValue(fakeAuth),
        ],
      );

      final isAvail = await fakeAuth.isPlatformAuthenticatorAvailable();
      expect(isAvail, isFalse);

      final notifier = container.read(screenLockProvider.notifier);
      final enabled = await notifier.enableLock();
      expect(enabled, isFalse);
      expect(container.read(screenLockProvider).isEnabled, isFalse);
    });
  });

  group('Part S3: Insights & Budgets Widget & Segmented Tests', () {
    testWidgets('App Insights renders segmented control Overview | Budgets and switches views', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.app),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const InsightsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overview tab is default
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Month in Review'), findsOneWidget);
      expect(find.text('Spending Calendar'), findsOneWidget);

      // Tap Budgets tab
      await tester.tap(find.text('Budgets'));
      await tester.pumpAndSettle();

      // Budgets view is now active
      expect(find.text('MONTHLY BUDGET'), findsOneWidget);
      expect(find.text('CATEGORY LIMITS'), findsOneWidget);
      expect(find.text('SAVINGS GOALS'), findsOneWidget);
    });

    testWidgets('Budgets / PlanScreen renders savings goals and recurring dues', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280 * 1.0, 800 * 1.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PlanScreen(showScaffold: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MONTHLY BUDGET'), findsOneWidget);
      expect(find.text('MONTH-END PROJECTION'), findsOneWidget);
      expect(find.text('CATEGORY LIMITS'), findsOneWidget);
      expect(find.text('UPCOMING & DUE RECURRING'), findsOneWidget);
      expect(find.text('SAVINGS GOALS'), findsOneWidget);
      expect(find.text('Emergency Fund'), findsOneWidget);
      expect(find.text('Goa Next Trip'), findsOneWidget);
    });

    testWidgets('Settings screen contains Security, Help & Feedback, and Brand watermark', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280 * 1.0, 900 * 1.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveExperienceProvider.overrideWithValue(EffectiveExperience.web),
            deviceAuthProvider.overrideWithValue(FakeDeviceAuth(isAvailable: true)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PRIVACY & SECURITY'), findsOneWidget);
      expect(find.text('Screen lock'), findsOneWidget);
      expect(find.text('HELP & FEEDBACK'), findsOneWidget);
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.text('Request a feature'), findsOneWidget);
      expect(find.text('Your reports'), findsOneWidget);
      expect(find.text('COMPATIBILITY PREVIEW'), findsOneWidget);
      expect(find.text(AppConfig.versionString), findsOneWidget);
      expect(find.text('Built with Flutter · Local-first preview'), findsOneWidget);
    });
  });
}
