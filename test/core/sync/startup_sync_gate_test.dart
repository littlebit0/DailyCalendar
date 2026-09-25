import 'dart:async';
import 'dart:io';

import 'package:daily/core/sync/google_drive_auth_service.dart';
import 'package:daily/core/sync/google_drive_sync_service.dart';
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
    expect(find.text('최신 데이터를 확인하지 못했습니다.'), findsNothing);
    expect(find.text('계속 기다리기'), findsOneWidget);
    await tester.tap(find.text('계속 기다리기'));
    await tester.pump();
    expect(calls, 1);
    operation.complete();
    await tester.pump();
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('slow synchronization opens calendar when it succeeds later', (
    tester,
  ) async {
    var calls = 0;
    var entered = 0;
    final operation = Completer<void>();
    await tester.pumpWidget(
      app(() {
        calls++;
        return operation.future;
      }, onContinue: () => entered++),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('최신 데이터를 확인하는 데 시간이 걸리고 있습니다.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('calendar'), findsNothing);
    operation.complete();
    await tester.pump();
    expect(find.text('calendar'), findsOneWidget);
    expect(calls, 1);
    expect(entered, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failure after UI deadline replaces waiting state and retries', (
    tester,
  ) async {
    var calls = 0;
    final operation = Completer<void>();
    await tester.pumpWidget(
      app(() {
        calls++;
        return calls == 1 ? operation.future : Future<void>.value();
      }),
    );
    await tester.pump(const Duration(seconds: 2));
    operation.completeError(const SocketException('private.example.test'));
    await tester.pump();
    expect(find.text('최신 데이터를 확인하지 못했습니다.'), findsOneWidget);
    expect(find.text('네트워크 연결을 확인한 뒤 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('private.example.test'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(calls, 2);
    expect(find.text('calendar'), findsOneWidget);
  });

  testWidgets('transport timeout is an actual failure, not a live operation', (
    tester,
  ) async {
    await tester.pumpWidget(app(() async => throw TimeoutException('private')));
    await tester.pump();
    expect(find.text('최신 데이터를 확인하지 못했습니다.'), findsOneWidget);
    expect(find.text('네트워크 연결을 확인한 뒤 다시 시도해 주세요.'), findsOneWidget);
    expect(find.text('계속 기다리기'), findsNothing);
  });

  final categorizedErrors = <String, (Object, String)>{
    'expired authorization': (
      const GoogleDriveAuthException('Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.'),
      'Google Drive 연결이 만료되었습니다. 다시 연결해 주세요.',
    ),
    'malformed data': (
      const FormatException('private source', 'private calendar JSON'),
      '동기화 데이터의 형식을 확인하지 못했습니다. 다시 시도해 주세요.',
    ),
    'malformed timetable': (
      const GoogleDriveSyncException(
        'Google Drive 시간표 데이터가 손상되었거나 지원하지 않는 형식입니다. 기존 데이터는 보존됩니다.',
      ),
      '동기화 데이터의 형식을 확인하지 못했습니다. 다시 시도해 주세요.',
    ),
    'unknown auth detail': (
      const GoogleDriveAuthException('private account@example.test'),
      'Google Drive 연결을 확인해야 합니다. 기기에 저장된 데이터로 계속한 뒤 설정에서 연결 상태를 확인해 주세요.',
    ),
    'unknown error detail': (
      StateError('private event title'),
      '요청을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    ),
  };
  for (final entry in categorizedErrors.entries) {
    testWidgets('shows safe diagnostic for ${entry.key}', (tester) async {
      await tester.pumpWidget(app(() async => throw entry.value.$1));
      await tester.pump();
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      expect(find.text('calendar'), findsNothing);
    });
  }

  testWidgets(
    'continue is called only once if a slow operation later succeeds',
    (tester) async {
      final operation = Completer<void>();
      var entered = 0;
      await tester.pumpWidget(
        app(() => operation.future, onContinue: () => entered++),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('기기에 저장된 데이터로 계속'));
      await tester.pump();
      operation.complete();
      await tester.pump();
      expect(find.text('calendar'), findsOneWidget);
      expect(entered, 1);
      expect(tester.takeException(), isNull);
    },
  );

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
