import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:settliv/core/theme/app_theme.dart';
import 'package:settliv/core/widgets/screen_scaffold.dart';
import 'package:settliv/data/repositories/in_memory_app_repository.dart';
import 'package:settliv/data/repositories/sharing_repository.dart';

void main() {
  testWidgets('ScreenScaffold pull-to-refresh bumps sharingVersionProvider',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ScreenScaffold(
            children: [
              SizedBox(height: 200, child: Center(child: Text('Item 1'))),
            ],
          ),
        ),
      ),
    );

    final initialVersion = container.read(sharingVersionProvider);
    await tester.fling(find.text('Item 1'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(container.read(sharingVersionProvider), greaterThan(initialVersion));
  });

  test('refreshFromRemoteIfSupported increments sharingVersionProvider',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final before = container.read(sharingVersionProvider);
    await container
        .read(appStateProvider.notifier)
        .refreshFromRemoteIfSupported();
    expect(container.read(sharingVersionProvider), before + 1);
  });
}
