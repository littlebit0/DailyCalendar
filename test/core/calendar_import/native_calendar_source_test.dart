import 'package:daily/core/calendar_import/calendar_import_models.dart';
import 'package:daily/core/calendar_import/native_calendar_source.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('daily/calendar_import_test');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // #872: Android reports removed and moved occurrences of a repeating event.
  test('excluded occurrence starts become local days of the series', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final start = DateTime(2026, 1, 5, 10);
    int at(DateTime value) => value.millisecondsSinceEpoch;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          return [
            {
              'sourceId': '1',
              'calendarId': 'c',
              'title': 'weekly',
              'startMilliseconds': at(start),
              'endMilliseconds': at(start.add(const Duration(hours: 2))),
              'allDay': false,
              'recurrenceRule': 'RRULE:FREQ=WEEKLY',
              'excludedMilliseconds': [
                at(DateTime(2026, 1, 19, 10)),
                at(DateTime(2026, 1, 12, 10)),
                at(DateTime(2026, 1, 12, 10)),
              ],
            },
            {
              'sourceId': '2',
              'calendarId': 'c',
              'title': 'single',
              'startMilliseconds': at(start),
              'endMilliseconds': at(start.add(const Duration(hours: 1))),
              'allDay': false,
            },
          ];
        });

    final events = await NativeCalendarSource(channel: channel).loadEvents([
      const ImportableCalendar(
        id: 'c',
        title: 'calendar',
        provider: CalendarImportProvider.samsung,
      ),
    ]);

    expect(events[0].excludedDates, [
      DateTime(2026, 1, 12),
      DateTime(2026, 1, 19),
    ]);
    expect(events[0].endAt.difference(events[0].startAt).inHours, 2);
    expect(events[1].excludedDates, isEmpty);
  });
}
