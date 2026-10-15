import 'dart:async';
import 'dart:io';

import 'package:daily/app/startup_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final failure in [
    const FormatException('private settings contents'),
    const FileSystemException('private path'),
  ]) {
    testWidgets(
      'startup failure is contained and retry succeeds: ${failure.runtimeType}',
      (tester) async {
        var attempts = 0;
        final pending = Completer<Widget>();
        await tester.pumpWidget(
          StartupGate(
            initialize: () async {
              attempts++;
              if (attempts == 1) throw failure;
              return pending.future;
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('protected application'), findsNothing);
        expect(find.textContaining('private'), findsNothing);
        expect(find.byType(FilledButton), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        expect(attempts, 2);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text('protected application'), findsNothing);
        pending.complete(
          const MaterialApp(home: Text('protected application')),
        );
        await tester.pumpAndSettle();
        expect(find.text('protected application'), findsOneWidget);
      },
    );
  }

  testWidgets('late startup completion cannot update disposed gate', (
    tester,
  ) async {
    final pending = Completer<Widget>();
    await tester.pumpWidget(StartupGate(initialize: () => pending.future));
    await tester.pumpWidget(const SizedBox());
    pending.complete(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
