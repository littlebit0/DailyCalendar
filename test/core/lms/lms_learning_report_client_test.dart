import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:daily/core/lms/lms_learning_report_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _Headers implements HttpHeaders {
  final values = <String, Object>{};
  @override
  ContentType? contentType = ContentType.html;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  int statusCode = 200;
  @override
  final headers = _Headers();
  @override
  final cookies = <Cookie>[];
  List<List<int>> chunks = [utf8.encode('<body>fixture</body>')];
  @override
  int contentLength = -1;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.fromIterable(chunks).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  _Request(this.response);
  final _Response response;
  @override
  final cookies = <Cookie>[];
  @override
  final headers = _Headers();
  @override
  bool followRedirects = true;
  int sends = 0;
  @override
  Future<HttpClientResponse> close() async {
    sends++;
    return response;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Client implements HttpClient {
  _Client(this.request);
  final _Request request;
  Uri? requested;
  bool closed = false;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested = url;
    return request;
  }

  @override
  void close({bool force = false}) => closed = force;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final uri = Uri.https(
    'ecampus.smu.ac.kr',
    '/report/ubcompletion/user_progress.php',
    {'id': '8001'},
  );
  const cookies = [
    {'name': 'MoodleSession', 'value': 'synthetic-cookie'},
    {'name': 'unrelated', 'value': 'must-not-send'},
  ];
  late _Response response;
  late _Request request;
  late _Client client;
  late LmsLearningReportClient reader;
  setUp(() {
    response = _Response();
    request = _Request(response);
    client = _Client(request);
    reader = LmsLearningReportClient(createClient: () => client);
  });

  test(
    'desktop report is GET-only with scoped session and no redirects',
    () async {
      final result = await reader.read(uri, cookies);
      expect(result['status'], 'ok');
      expect(result['url'], uri.toString());
      expect(result['html'], '<body>fixture</body>');
      expect(client.requested, uri);
      expect(request.followRedirects, isFalse);
      expect(request.cookies.map((c) => c.name), ['MoodleSession']);
      expect(
        (request.headers as _Headers).values[HttpHeaders.userAgentHeader],
        contains('Macintosh'),
      );
      expect(client.closed, isTrue);
    },
  );

  test(
    'foreign host, mutations, duplicate IDs and invalid transport never connect',
    () async {
      for (final invalid in [
        uri.replace(scheme: 'http'),
        uri.replace(host: 'other.test'),
        uri.replace(port: 444),
        uri.replace(userInfo: 'user'),
        uri.replace(fragment: 'fragment'),
        uri.replace(path: '/login/logout.php'),
        uri.replace(query: 'id=8001&id=8002'),
        uri.replace(query: 'id=8001&userid=9000'),
      ]) {
        expect((await reader.read(invalid, cookies))['status'], 'invalid');
      }
      expect(client.requested, isNull);
      expect(request.sends, 0);
    },
  );

  test(
    'missing session does not send and server auth rejection stays explicit',
    () async {
      expect((await reader.read(uri, []))['reason'], 'unauthorized');
      expect(request.sends, 0);
      for (final status in [303, 401, 403, 503]) {
        response.statusCode = status;
        expect(
          (await reader.read(uri, cookies))['status'],
          status == 303 || status == 401
              ? 'auth'
              : status == 403
              ? 'invalid'
              : 'network',
        );
      }
      expect(client.closed, isTrue);
    },
  );

  test(
    'non-HTML and excessive streamed or declared body is rejected',
    () async {
      response.headers.contentType = ContentType.json;
      expect((await reader.read(uri, cookies))['status'], 'invalid');
      response.headers.contentType = ContentType.html;
      response.contentLength = 4000001;
      expect((await reader.read(uri, cookies))['status'], 'invalid');
      response.contentLength = -1;
      response.chunks = [List.filled(2000000, 65), List.filled(2000001, 65)];
      expect((await reader.read(uri, cookies))['status'], 'invalid');
    },
  );

  test(
    'only validated report session rotation is returned to owner guard',
    () async {
      response.cookies.add(
        Cookie('MoodleSession', 'rotated')
          ..path = '/'
          ..domain = '.smu.ac.kr',
      );
      final result = await reader.read(uri, cookies);
      expect(result['status'], 'ok');
      expect(result['rotatedCookies'], [
        {'name': 'MoodleSession', 'value': 'rotated'},
      ]);
      response.cookies.single.domain = 'other.test';
      expect((await reader.read(uri, cookies))['status'], 'invalid');
      response.cookies.single.domain = 'ecampus.smu.ac.kr';
      response.cookies.single.maxAge = 60;
      final rotated =
          (await reader.read(uri, cookies))['rotatedCookies'] as List;
      expect((rotated.single as Map)['expires'], isA<int>());
      response.cookies.single.maxAge = 0;
      expect((await reader.read(uri, cookies))['reason'], 'unauthorized');
    },
  );
}
