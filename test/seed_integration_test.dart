import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/main.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/repositories/persistent_app_repository.dart';
import 'package:settliv/routes/app_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots on fresh storage and asserts hero numbers (+₹860, Flatmates +₹1,240, Goa Trip -₹380)', (tester) async {
    // 1. Fresh SharedPreferences with no prior state
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final testRepo = PersistentAppRepository(prefs: prefs);
    final router = createAppRouter(initialLocation: '/');

    await tester.binding.setSurfaceSize(const Size(390, 844));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appRepositoryProvider.overrideWithValue(testRepo),
        ],
        child: SettlivApp(router: router),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Hero numbers
    // Net is +₹860
    expect(find.textContaining('860'), findsWidgets);
    // Headline sentence
    expect(find.textContaining("You're owed"), findsWidgets);
    // Breakdown numbers
    expect(find.textContaining('1,240'), findsWidgets);
    expect(find.textContaining('380'), findsWidgets);

    // Verify recent groups show Flatmates and Goa Trip
    final flatmatesFinder = find.text('Flatmates');
    await tester.scrollUntilVisible(flatmatesFinder, 150);
    await tester.pumpAndSettle();
    expect(flatmatesFinder, findsWidgets);

    final goaFinder = find.text('Goa Trip');
    await tester.scrollUntilVisible(goaFinder, 150);
    await tester.pumpAndSettle();
    expect(goaFinder, findsWidgets);
  });
}
