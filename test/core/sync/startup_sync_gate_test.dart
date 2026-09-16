import 'dart:async';

import 'package:daily/core/sync/startup_sync_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app(
    Future<void> Function() sync, {
    bool required = true,
    VoidCallback? onContinue,
  }) => MaterialApp(
    home: StartupSyncGate(
      requiredAtStartup: required,
      synchronize: sync,
      onContinue: onContinue ?? () {},
      timeout: const Duration(seconds: 2),
      child: const Text('calendar'),
    ),
  );

  testWidgets('local account skips synchronization entirely', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      app(() async {
        calls++;
      }, required: false),
    );
    expect(find.text('calendar'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('calendar waits for completion without a minimum delay', (
    tester,
  ) async {
    final operation = Completer<void>();
    await tester.pumpWidget(app(() => operation.future));
    expect(find.text('calendar'), findsNothing);
    operation.complete();
    await tester.pump();
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('failure stays at gate and retry waits for its own completion', (
    tester,
  ) async {
    var calls = 0;
    final retry = Completer<void>();
    await tester.pumpWidget(
      app(() {
        if (++calls == 1) throw StateError('offline');
        return retry.future;
      }),
    );
    await tester.pump();
    expect(find.text('calendar'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(calls, 2);
    expect(find.text('calendar'), findsNothing);
    retry.complete();
    await tester.pump();
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('timeout retry joins live operation instead of duplicating it', (
    tester,
  ) async {
    var calls = 0;
    final operation = Completer<void>();
    await tester.pumpWidget(
      app(() {
        calls++;
        return operation.future;
      }),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('다시 시도'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(calls, 1);
    operation.complete();
    await tester.pump();
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('continue survives late errors and rebuilds without restarting', (
    tester,
  ) async {
    final operation = Completer<void>();
    var entered = 0;
    final widget = app(() => operation.future, onContinue: () => entered++);
    await tester.pumpWidget(widget);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('기기에 저장된 데이터로 계속'));
    await tester.pump();
    operation.completeError(StateError('late network failure'));
    await tester.pump();
    await tester.pumpWidget(widget);
    expect(find.text('calendar'), findsOneWidget);
    expect(entered, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposed gate ignores old completion', (tester) async {
    final operation = Completer<void>();
    var entered = 0;
    await tester.pumpWidget(
      app(() => operation.future, onContinue: () => entered++),
    );
    await tester.pumpWidget(const SizedBox());
    operation.complete();
    await tester.pump();
    expect(entered, 0);
    expect(tester.takeException(), isNull);
  });
}
