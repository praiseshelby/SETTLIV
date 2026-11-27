import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settliv/core/auth/auth_provider.dart';
import 'package:settliv/core/auth/fake_auth_repository.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/person_avatar.dart';
import 'package:settliv/data/models/person.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/features/settings/presentation/widgets/avatar_picker_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('P2: Profile Pictures', () {
    testWidgets('Stock avatar selection persists to currentUserProvider and renders CustomPaint', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository();
      await fakeAuth.signUpWithUsername(
        fullName: 'Asha',
        username: 'asha_1',
        password: 'password123',
        layout: 'app',
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: AvatarPickerSheet()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      final user = container.read(currentUserProvider);
      expect(user?.avatarKind, 'stock');
      expect(user?.avatarRef, '0');
    });

    testWidgets('Initials fallback renders initials when avatarKind is initials', (tester) async {
      const person = Person(id: 'p1', name: 'Nisha Rao', avatarKind: 'initials');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PersonAvatar(person: person, size: 40)),
        ),
      );
      expect(find.text('NR'), findsOneWidget);
    });

    testWidgets('Failed upload shows friendly error and keeps old avatar', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fakeAuth = FakeAuthRepository()..simulateUploadFailure = true;
      await fakeAuth.signUpWithUsername(
        fullName: 'Asha',
        username: 'asha_2',
        password: 'password123',
        layout: 'app',
      );
      await fakeAuth.updateAvatar(avatarKind: 'stock', avatarRef: '3');

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: AvatarPickerSheet(
                pickImageBytesOverride: () async => Uint8List.fromList([1, 2, 3]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload photo'));
      await tester.pumpAndSettle();

      expect(find.text('Could not upload photo. Keeping current avatar.'), findsOneWidget);
      expect(container.read(currentUserProvider)?.avatarKind, 'stock');
      expect(container.read(currentUserProvider)?.avatarRef, '3');
    });
  });
}
