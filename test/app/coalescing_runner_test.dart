import 'dart:async';

import 'package:daily/app/coalescing_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a request during a pass triggers a rerun that sees the new work',
    () async {
      final queue = <String>['A'];
      final processed = <String>[];
      final firstPassGate = Completer<void>();
      var passes = 0;
      final runner = CoalescingRunner(() async {
        passes++;
        final batch = [...queue];
        queue.clear();
        if (passes == 1) await firstPassGate.future;
        processed.addAll(batch);
      });
      final first = runner.request();
      await Future<void>.delayed(Duration.zero);
      queue.add('B');
      final second = runner.request();
      firstPassGate.complete();
      await Future.wait([first, second]);
      expect(processed, ['A', 'B']);
      expect(passes, 2);
    },
  );

  test('requests during one pass share a single rerun', () async {
    var passes = 0;
    final gate = Completer<void>();
    final runner = CoalescingRunner(() async {
      passes++;
      if (passes == 1) await gate.future;
    });
    final first = runner.request();
    await Future<void>.delayed(Duration.zero);
    runner
      ..request()
      ..request()
      ..request();
    gate.complete();
    await first;
    expect(passes, 2);
  });

  test('a request after completion starts a new pass', () async {
    var passes = 0;
    final runner = CoalescingRunner(() async => passes++);
    await runner.request();
    await runner.request();
    expect(passes, 2);
  });

  test('a signal arriving just before the pass ends is not lost', () async {
    var passes = 0;
    late CoalescingRunner runner;
    runner = CoalescingRunner(() async {
      passes++;
      if (passes == 1) {
        // After the last read of the queue, right before the pass returns.
        scheduleMicrotask(runner.request);
      }
    });
    await runner.request();
    expect(passes, 2);
  });

  test('a failing pass releases the runner and does not loop', () async {
    var passes = 0;
    final runner = CoalescingRunner(() async {
      passes++;
      throw StateError('boom');
    });
    await expectLater(runner.request(), throwsStateError);
    expect(passes, 1);
    await expectLater(runner.request(), throwsStateError);
    expect(passes, 2);
  });
}
