import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/auth/auth_provider.dart';
import 'package:settliv/core/auth/fake_auth_repository.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/seed/seed_data.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P0: Identity & Demo Data Separation', () {
    test('Fresh signed-in account has zero demo rows and uses its own profile name', () async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      await fakeAuth.signUpWithUsername(
        fullName: 'Priya Sharma',
        username: 'priya_1',
        password: 'password123',
        layout: 'web',
      );
      await Future<void>.delayed(Duration.zero);

      final people = container.read(allPeopleProvider);
      final groups = container.read(allGroupsProvider);
      final expenses = container.read(allExpensesProvider);

      expect(people.length, 1);
      expect(people.first.name, 'Priya Sharma');
      expect(people.any((p) => p.name == 'Arjun' || p.name == 'Meera' || p.name == 'Kabir'), isFalse);
      expect(groups.where((g) => !g.isPersonal), isEmpty);
      expect(expenses, isEmpty);
    });

    test('Guest mode still gets demo data', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authStateProvider.notifier).enterGuestMode();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(allExpensesProvider).length, SeedData.expenses.length);
      expect(container.read(allGroupsProvider).length, SeedData.groups.length);
    });

    test('Renaming current user propagates to currentUserProvider and authStateProvider', () async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      await fakeAuth.signUpWithUsername(
        fullName: 'Priya',
        username: 'priya_2',
        password: 'password123',
        layout: 'web',
      );
      await Future<void>.delayed(Duration.zero);

      container.read(appStateProvider.notifier).updateCurrentUser(name: 'Priya Nair');
      await fakeAuth.updateDisplayName('Priya Nair');
      await Future<void>.delayed(Duration.zero);

      expect(container.read(currentUserProvider)?.name, 'Priya Nair');
      expect((fakeAuth.currentStatus as dynamic).user.displayName, 'Priya Nair');
    });
  });
}
