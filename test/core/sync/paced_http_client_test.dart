import 'dart:async';

import 'package:daily/core/sync/paced_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  final uri = Uri.https('example.test', '/sync');

  test(
    'response bodies finish before the next request and quiet interval',
    () async {
      final body = StreamController<List<int>>();
      final entered = Completer<void>();
      final clock = Stopwatch()..start();
      final starts = <int>[];
      var firstFinished = 0;
      final transport = _Transport((request) async {
        starts.add(clock.elapsedMilliseconds);
        if (starts.length == 1) {
          entered.complete();
          return http.StreamedResponse(body.stream, 200);
        }
        return http.StreamedResponse(Stream.value([50]), 200);
      });
      final client = PacedHttpClient(
        client: transport,
        delay: const Duration(milliseconds: 40),
      );
      addTearDown(client.close);
      final first = client.get(uri);
      final second = client.get(uri);
      await entered.future;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(starts.length, 1);
      body.add([49]);
      firstFinished = clock.elapsedMilliseconds;
      await body.close();
      expect((await first).body, '1');
      expect((await second).body, '2');
      expect(starts[1] - firstFinished, greaterThanOrEqualTo(35));
    },
  );

  test(
    'timeout aborts active response and the next request can proceed',
    () async {
      var calls = 0;
      var aborted = false;
      final transport = _Transport((request) async {
        calls++;
        if (calls > 1) {
          expect(aborted, isTrue);
          return http.StreamedResponse(Stream.value([111, 107]), 200);
        }
        final body = StreamController<List<int>>();
        unawaited(
          (request as http.Abortable).abortTrigger!.then((_) async {
            aborted = true;
            body.addError(http.RequestAbortedException(request.url));
            await body.close();
          }),
        );
        return http.StreamedResponse(body.stream, 200);
      });
      final client = PacedHttpClient(
        client: transport,
        delay: const Duration(milliseconds: 10),
        requestTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(client.close);
      final first = expectLater(
        client.get(uri),
        throwsA(isA<TimeoutException>()),
      );
      final next = client.get(uri);
      await first;
      expect((await next).body, 'ok');
      expect(calls, 2);
    },
  );

  test(
    'queue wait is excluded from request timeout and failures release queue',
    () async {
      var calls = 0;
      final transport = _Transport((request) async {
        if (++calls == 1) throw http.ClientException('offline');
        return http.StreamedResponse(Stream.value([111, 107]), 200);
      });
      final client = PacedHttpClient(
        client: transport,
        delay: const Duration(milliseconds: 60),
        requestTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(client.close);
      final first = expectLater(
        client.get(uri),
        throwsA(isA<http.ClientException>()),
      );
      final second = client.get(uri);
      await first;
      expect((await second).body, 'ok');
    },
  );

  test(
    'queued request revalidates account after spacing and before send',
    () async {
      var valid = true;
      var calls = 0;
      final client = PacedHttpClient(
        client: _Transport((request) async {
          calls++;
          return http.StreamedResponse(Stream.value([49]), 200);
        }),
        delay: const Duration(milliseconds: 30),
        validateRequest: () {
          if (!valid) throw StateError('account changed');
        },
      );
      addTearDown(client.close);
      await client.get(uri);
      final queued = expectLater(client.get(uri), throwsStateError);
      valid = false;
      await queued;
      expect(calls, 1);
    },
  );

  test(
    'close cancels pending requests and preserves a borrowed client',
    () async {
      final transport = _Transport(
        (_) async => http.StreamedResponse(Stream.value([49]), 200),
      );
      final client = PacedHttpClient(client: transport);
      await client.get(uri);
      final queued = expectLater(
        client.get(uri),
        throwsA(isA<http.ClientException>()),
      );
      client.close();
      await queued;
      expect(transport.closed, isFalse);
    },
  );
}

class _Transport extends http.BaseClient {
  _Transport(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
  @override
  void close() => closed = true;
}
