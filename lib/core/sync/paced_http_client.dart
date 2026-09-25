import 'dart:async';

import 'package:http/http.dart' as http;

/// Serializes complete responses, leaving a quiet interval between requests.
/// Queue time does not count against the network timeout.
class PacedHttpClient extends http.BaseClient {
  PacedHttpClient({
    required http.Client client,
    this.delay = const Duration(milliseconds: 250),
    this.requestTimeout = const Duration(seconds: 10),
    this.validateRequest,
    this.ownsClient = false,
  }) : _client = client;

  final http.Client _client;
  final Duration delay;
  final Duration requestTimeout;
  final void Function()? validateRequest;
  final bool ownsClient;
  Future<void> _tail = Future<void>.value();
  Stopwatch? _sinceCompletion;
  bool _closed = false;
  Completer<void>? _activeAbort;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final result = _tail.then((_) async {
      _ensureOpen();
      final elapsed = _sinceCompletion?.elapsed;
      if (elapsed != null && elapsed < delay) {
        await Future<void>.delayed(delay - elapsed);
      }
      _ensureOpen();
      validateRequest?.call();
      final abort = Completer<void>();
      _activeAbort = abort;
      final outgoing =
          http.AbortableRequest(
              request.method,
              request.url,
              abortTrigger: abort.future,
            )
            ..headers.addAll(request.headers)
            ..followRedirects = request.followRedirects
            ..maxRedirects = request.maxRedirects
            ..persistentConnection = request.persistentConnection;
      try {
        outgoing.bodyBytes = await request.finalize().toBytes();
        final response =
            await (() async {
              final streamed = await _client.send(outgoing);
              return http.Response.fromStream(streamed);
            })().timeout(
              requestTimeout,
              onTimeout: () {
                if (!abort.isCompleted) abort.complete();
                throw TimeoutException(
                  'Drive request timed out',
                  requestTimeout,
                );
              },
            );
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
      } finally {
        _activeAbort = null;
        _sinceCompletion = Stopwatch()..start();
      }
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _ensureOpen() {
    if (_closed) throw http.ClientException('Drive client is closed');
  }

  @override
  void close() {
    _closed = true;
    final abort = _activeAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    if (ownsClient) _client.close();
  }
}
