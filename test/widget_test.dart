import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dock_panel/dock_panel.dart';

void main() {
  testWidgets('DockArea renders empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DockTheme(
              data: DockThemeData(),
              child: DockArea(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('No panels'), findsOneWidget);
  });

  testWidgets('DockArea renders a panel after adding', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DockTheme(
              data: const DockThemeData(),
              child: Consumer(
                builder: (context, ref, _) {
                  // Add a panel on first build.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(dockManagerProvider.notifier).addPanel(
                      DockPanel(
                        id: 'test',
                        title: 'Test Panel',
                        builder: (_) => const Text('Hello Dock'),
                      ),
                    );
                  });
                  return const DockArea();
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Test Panel'), findsOneWidget);
    expect(find.text('Hello Dock'), findsOneWidget);
  });
}
