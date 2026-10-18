import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import '../../../tool/analytics_receiver.dart';

void main() {
  test(
    'receiver keeps test and production versions in separate groups',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'daily-analytics-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final aggregator = DailyAnalyticsAggregator(
        directory,
        now: () => DateTime.utc(2026, 10, 13),
      );
      final production = _safeBatch();
      final testBatch = _safeBatch();
      (testBatch['environment'] as Map)['appVersion'] = '3.1.0-test';
      ((testBatch['events'] as List).single as Map)['eventId'] =
          'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
      expect(await aggregator.accept(production), 1);
      expect(await aggregator.accept(testBatch), 1);
      final aggregate =
          jsonDecode(
                await File(
                  '${directory.path}/analytics-2026-10-13.json',
                ).readAsString(),
              )
              as Map;
      final groups = (aggregate['groups'] as Map).values.cast<Map>();
      expect(
        groups.map((group) => group['appVersion']),
        unorderedEquals(['3.1.0', '3.1.0-test']),
      );
      (testBatch['environment'] as Map)['appVersion'] = '3.1.0-private-data';
      await expectLater(aggregator.accept(testBatch), throwsFormatException);
    },
  );
  test(
    'HTTP receiver accepts safe batches and rejects content fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'daily-analytics-',
      );
      final server = await AnalyticsReceiverServer.bind(
        address: InternetAddress.loopbackIPv4.address,
        port: 0,
        aggregator: DailyAnalyticsAggregator(directory),
      );
      final client = http.Client();
      addTearDown(() async {
        client.close();
        await server.close();
        await directory.delete(recursive: true);
      });
      final endpoint = Uri.parse(
        'http://${server.address.address}:${server.port}/v1/events',
      );

      final accepted = await client.post(
        endpoint,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode(_safeBatch()),
      );
      expect(accepted.statusCode, HttpStatus.accepted);
      expect(jsonDecode(accepted.body), {'accepted': 1});

      final unsafe = _safeBatch();
      final event = Map<String, Object?>.from(
        (unsafe['events'] as List).single as Map,
      );
      event['attributes'] = {'view': 'month', 'memo': 'private calendar memo'};
      unsafe['events'] = [event];
      final rejected = await client.post(
        endpoint,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        body: jsonEncode(unsafe),
      );
      expect(rejected.statusCode, HttpStatus.badRequest);
      expect(jsonDecode(rejected.body), {'error': 'invalid_schema'});
    },
  );

  test(
    'receiver persists only aggregate dimensions and dedupe hashes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'daily-analytics-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final aggregator = DailyAnalyticsAggregator(
        directory,
        now: () => DateTime.utc(2026, 8, 21, 12),
      );
      final batch = _safeBatch();

      expect(await aggregator.accept(batch), 1);
      expect(await aggregator.accept(batch), 0);

      final aggregate = await File(
        '${directory.path}/analytics-2026-08-21.json',
      ).readAsString();
      final lower = aggregate.toLowerCase();
      expect(lower, isNot(contains('sessionid')));
      expect(lower, isNot(contains('eventid')));
      expect(lower, isNot(contains('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')));
      expect(lower, isNot(contains('private title')));
      expect(lower, contains('calendar_view_changed'));
      expect(lower, contains('"count":1'));

      final dedupe =
          jsonDecode(
                await File(
                  '${directory.path}/dedupe-2026-08-21.json',
                ).readAsString(),
              )
              as List;
      expect(dedupe, hasLength(1));
      expect(dedupe.single, isNot('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'));
    },
  );

  test('receiver rejects a batch containing calendar content', () async {
    final directory = await Directory.systemTemp.createTemp('daily-analytics-');
    addTearDown(() => directory.delete(recursive: true));
    final aggregator = DailyAnalyticsAggregator(directory);
    final batch = _safeBatch();
    final event = Map<String, Object?>.from(
      (batch['events'] as List).first as Map,
    );
    event['attributes'] = {
      'view': 'month',
      'trigger': 'manual',
      'title': 'private',
    };
    batch['events'] = [event];

    await expectLater(aggregator.accept(batch), throwsFormatException);
  });
}

Map<String, Object?> _safeBatch() => {
  'schemaVersion': 1,
  'sessionId': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  'environment': {'appVersion': '3.1.0', 'platform': 'ios', 'osMajor': 26},
  'events': [
    {
      'eventId': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'name': 'calendar_view_changed',
      'occurredAt': '2026-08-21T00:00:00.000Z',
      'attributes': {'view': 'month', 'trigger': 'manual'},
    },
  ],
};
