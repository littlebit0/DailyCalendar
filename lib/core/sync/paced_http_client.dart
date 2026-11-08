import 'dart:async';
import 'dart:collection';

import 'package:http/http.dart' as http;

/// Runs at most [maxConcurrent] complete responses at once, leaving a quiet
/// interval on each slot between requests. Queue time does not count against
/// the network timeout. Drive throttling responses (429, or 403 with
/// `rateLimitExceeded`) are retried after [rateLimitRetryDelays].
class PacedHttpClient extends http.BaseClient {
  PacedHttpClient({
    required http.Client client,
    this.delay = defaultDelay,
    this.requestTimeout = const Duration(seconds: 10),
    this.validateRequest,
    this.ownsClient = false,
    this.maxConcurrent = 1,
    this.rateLimitRetryDelays = const <Duration>[],
  }) : assert(maxConcurrent > 0),
       _client = client {
    for (var i = 0; i < maxConcurrent; i++) {
      _freeSlots.add(_Slot());
    }
  }

  static const defaultDelay = Duration(milliseconds: 1);

  /// Exponential backoff for Drive throttling responses.
  static const driveRateLimitRetryDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  final http.Client _client;
  final Duration delay;
  final Duration requestTimeout;
  final void Function()? validateRequest;
  final bool ownsClient;
  final int maxConcurrent;
  final List<Duration> rateLimitRetryDelays;
  final Queue<_Slot> _freeSlots = Queue<_Slot>();
  final Queue<Completer<_Slot>> _waiters = Queue<Completer<_Slot>>();
  final Set<Completer<void>> _activeAborts = {};
  bool _closed = false;

  Future<_Slot> _acquire() {
    if (_freeSlots.isNotEmpty) return Future.value(_freeSlots.removeFirst());
    final waiter = Completer<_Slot>();
    _waiters.add(waiter);
    return waiter.future;
  }

  void _release(_Slot slot) {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete(slot);
    } else {
      _freeSlots.add(slot);
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final slot = await _acquire();
    try {
      _ensureOpen();
      final bodyBytes = await request.finalize().toBytes();
      for (var attempt = 0; ; attempt++) {
        final elapsed = slot.sinceCompletion?.elapsed;
        if (elapsed != null && elapsed < delay) {
          await Future<void>.delayed(delay - elapsed);
        }
        _ensureOpen();
        validateRequest?.call();
        final response = await _sendOnce(request, bodyBytes, slot);
        if (attempt < rateLimitRetryDelays.length && _isRateLimited(response)) {
          await Future<void>.delayed(rateLimitRetryDelays[attempt]);
          continue;
        }
        return http.StreamedResponse(
          Stream<List<int>>.value(response.bodyBytes),
          response.statusCode,
          contentLength: response.bodyBytes.length,
          request: request,
          headers: response.headers,
          isRedirect: response.isRedirect,
          persistentConnection: response.persistentConnection,
          reasonPhrase: response.reasonPhrase,
        );
      }
    } finally {
      _release(slot);
    }
  }

  Future<http.Response> _sendOnce(
    http.BaseRequest request,
    List<int> bodyBytes,
    _Slot slot,
  ) async {
    final abort = Completer<void>();
    _activeAborts.add(abort);
    final outgoing =
        http.AbortableRequest(
            request.method,
            request.url,
            abortTrigger: abort.future,
          )
          ..headers.addAll(request.headers)
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..persistentConnection = request.persistentConnection
          ..bodyBytes = bodyBytes;
    try {
      return await (() async {
        final streamed = await _client.send(outgoing);
        return http.Response.fromStream(streamed);
      })().timeout(
        requestTimeout,
        onTimeout: () {
          if (!abort.isCompleted) abort.complete();
          throw TimeoutException('Drive request timed out', requestTimeout);
        },
      );
    } finally {
      _activeAborts.remove(abort);
      slot.sinceCompletion = Stopwatch()..start();
    }
  }

  static bool _isRateLimited(http.Response response) {
    if (response.statusCode == 429) return true;
    if (response.statusCode != 403) return false;
    final body = response.body.toLowerCase();
    return body.contains('ratelimitexceeded');
  }

  void _ensureOpen() {
    if (_closed) throw http.ClientException('Drive client is closed');
  }

  @override
  void close() {
    _closed = true;
    for (final abort in _activeAborts.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
    if (ownsClient) _client.close();
  }
}

class _Slot {
  Stopwatch? sinceCompletion;
}
