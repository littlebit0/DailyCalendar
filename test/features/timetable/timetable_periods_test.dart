import 'dart:convert';
import 'dart:io';

import 'package:daily/core/di/app_providers.dart';
import 'package:daily/core/settings/settings_repository.dart';
import 'package:daily/features/events/domain/calendar_event.dart';
import 'package:daily/features/events/domain/event_category.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:daily/features/timetable/presentation/timetable_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'dated occurrences include both endpoints and exclude adjacent days',
    () {
      final period = TimetablePeriod(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 12, 21),
      );
      final dates = [
        DateTime(2026, 8, 31, 23, 59),
        DateTime(2026, 9, 1, 23, 59),
        DateTime(2026, 12, 21, 23, 59),
        DateTime(2026, 12, 22),
        DateTime(2027, 1, 4),
      ];
      final occurrences = classOccurrences(
        [_dailyCourse('fall')],
        dates,
        periodFor: (_) => period,
      );
      expect(occurrences.map((o) => timetableDateKey(o.date)), [
        '2026-09-01',
        '2026-12-21',
      ]);
    },
  );

  test('winter dates belong to the starting academic year across January', () {
    final period = TimetablePeriod(
      start: DateTime(2026, 12, 22),
      end: DateTime(2027, 1, 8),
    );
    final occurrences = classOccurrences(
      [_dailyCourse('winter', semester: '겨울')],
      [
        DateTime(2026, 12, 21),
        DateTime(2026, 12, 22),
        DateTime(2027, 1, 1),
        DateTime(2027, 1, 8),
        DateTime(2027, 1, 9),
      ],
      periodFor: (_) => period,
    );
    expect(occurrences.map((o) => timetableDateKey(o.date)), [
      '2026-12-22',
      '2027-01-01',
      '2027-01-08',
    ]);
    expect(occurrences.every((o) => o.course.academicYear == 2026), isTrue);
  });

  test(
    'unknown periods are excluded even when unscheduled modes are shown',
    () {
      final courses = [
        _dailyCourse('unknown'),
        _dailyCourse('unknown-video', mode: LectureMode.video),
      ];
      final dates = [DateTime(2026, 9, 25)];
      expect(classOccurrences(courses, dates, periodFor: (_) => null), isEmpty);
      expect(
        classOccurrences(
          courses,
          dates,
          periodFor: (_) => null,
          includeUnscheduled: true,
        ),
        isEmpty,
      );
      // The undated basic timetable intentionally remains available.
      expect(
        classOccurrences(courses, dates, includeUnscheduled: true),
        hasLength(2),
      );
    },
  );

  test('period limits apply before video, cancellation and mode overrides', () {
    final inside = DateTime(2026, 9, 25);
    final outside = DateTime(2026, 12, 25);
    final period = TimetablePeriod(
      start: DateTime(2026, 9, 1),
      end: DateTime(2026, 12, 21),
    );
    TimetableClass override(TimetableClass course, LectureMode mode) {
      final meeting = course.meetings.firstWhere(
        (m) => m.weekday == inside.weekday,
      );
      return course
          .withOverride(meeting, inside, mode)
          .withOverride(meeting, outside, mode);
    }

    final courses = [
      _dailyCourse('person'),
      _dailyCourse('live', mode: LectureMode.liveOnline),
      _dailyCourse('video', mode: LectureMode.video),
      override(_dailyCourse('cancelled'), LectureMode.cancelled),
      override(_dailyCourse('recorded'), LectureMode.video),
      override(
        _dailyCourse('video-now-live', mode: LectureMode.video),
        LectureMode.liveOnline,
      ),
    ];
    final scheduled = classOccurrences(courses, [
      inside,
      outside,
    ], periodFor: (_) => period);
    expect(scheduled.map((o) => o.course.id).toSet(), {
      'person',
      'live',
      'video-now-live',
    });
    expect(scheduled.every((o) => o.date == inside), isTrue);
    final all = classOccurrences(
      courses,
      [inside, outside],
      periodFor: (_) => period,
      includeUnscheduled: true,
    );
    expect(all, hasLength(6));
    expect(all.every((o) => o.date == inside), isTrue);
    expect(
      all.singleWhere((o) => o.course.id == 'cancelled').mode,
      LectureMode.cancelled,
    );
  });

  test('official defaults cover the four verified 2026 periods only', () async {
    final defaults = await TimetablePeriodDefaults.load(bundle: _FileBundle());
    final expected = <String, (DateTime, DateTime)>{
      '1': (DateTime(2026, 3, 3), DateTime(2026, 6, 22)),
      '여름': (DateTime(2026, 6, 23), DateTime(2026, 7, 8)),
      '2': (DateTime(2026, 9, 1), DateTime(2026, 12, 21)),
      '겨울': (DateTime(2026, 12, 22), DateTime(2027, 1, 8)),
    };
    expect(defaults.periods, hasLength(4));
    for (final entry in expected.entries) {
      final period = defaults.periodFor(2026, entry.key)!;
      expect(period.start, entry.value.$1);
      expect(period.end, entry.value.$2);
      expect(period.contains(period.start), isTrue);
      expect(period.contains(period.end), isTrue);
      expect(
        period.contains(period.start.subtract(const Duration(days: 1))),
        isFalse,
      );
      expect(period.contains(period.end.add(const Duration(days: 1))), isFalse);
    }
    expect(defaults.periodFor(2025, '2'), isNull);
    expect(defaults.periodFor(2027, '1'), isNull);
    expect(defaults.periodFor(2026, 'custom'), isNull);
  });

  test('official defaults reject duplicate terms and invalid dates', () async {
    final raw =
        jsonDecode(
              File('assets/timetable/term-periods.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final terms = List<Map<String, dynamic>>.from(
      (raw['terms'] as List).map((t) => Map<String, dynamic>.from(t as Map)),
    );
    await expectLater(
      TimetablePeriodDefaults.load(
        bundle: _JsonBundle({
          ...raw,
          'terms': [terms.first, terms.first],
        }),
      ),
      throwsFormatException,
    );
    await expectLater(
      TimetablePeriodDefaults.load(
        bundle: _JsonBundle({
          ...raw,
          'terms': [
            {...terms.first, 'start': '2026-02-30'},
          ],
        }),
      ),
      throwsFormatException,
    );
  });

  testWidgets('calendar projects dated terms regardless of the selected term', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsRepository(
      preferences: await SharedPreferences.getInstance(),
    );
    final store = settings.timetableStore;
    await store.save(_dailyCourse('spring', semester: '1'));
    await store.save(_dailyCourse('fall'));
    await store.save(_dailyCourse('winter', semester: '겨울'));
    await store.save(_dailyCourse('unknown', year: 2027, semester: '1'));
    final defaults = await TimetablePeriodDefaults.load(bundle: _FileBundle());
    await store.seedTermPeriods(defaults.periods);
    await store.selectTerm(2025, '2');
    final personal = CalendarEvent(
      id: 'personal',
      title: 'Personal summer appointment',
      startAt: DateTime(2026, 8, 3, 9),
      endAt: DateTime(2026, 8, 3, 10),
      allDay: false,
      category: EventCategory.basic,
      colorValue: EventCategory.basic.colorValue,
      createdAt: DateTime(2026, 8, 3),
      updatedAt: DateTime(2026, 8, 3),
    );
    List<CalendarEvent> rendered = [];
    Map<String, VoidCallback> actions = {};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsRepositoryProvider.overrideWithValue(settings)],
        child: MaterialApp(
          home: TimetableSchedule(
            days: [
              DateTime(2026, 3, 2),
              DateTime(2026, 3, 3),
              DateTime(2026, 6, 22),
              DateTime(2026, 8, 3),
              DateTime(2026, 9, 1),
              DateTime(2026, 12, 21),
              DateTime(2026, 12, 22),
              DateTime(2027, 1, 8),
              DateTime(2027, 1, 9),
              DateTime(2027, 3, 3),
            ],
            events: [personal],
            builder: (events, eventActions) {
              rendered = events;
              actions = eventActions;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final projected = rendered
        .where((event) => event.id != personal.id)
        .toList();
    expect(projected.map((e) => '${e.title}/${timetableDateKey(e.startAt)}'), [
      'spring/2026-03-03',
      'spring/2026-06-22',
      'fall/2026-09-01',
      'fall/2026-12-21',
      'winter/2026-12-22',
      'winter/2027-01-08',
    ]);
    expect(rendered.first, same(personal));
    expect(projected.every((e) => e.readOnly && e.systemEvent), isTrue);
    expect(actions.keys.toSet(), projected.map((e) => e.id).toSet());
    expect(store.activeYear, 2025);
    expect(store.activeSemester, '2');
    final before = rendered.map((e) => e.id).toList();
    await store.selectTerm(2026, '겨울');
    await tester.pumpAndSettle();
    expect(rendered.map((e) => e.id), before);
    expect(store.classes, hasLength(4));
    expect(tester.takeException(), isNull);
  });
}

TimetableClass _dailyCourse(
  String id, {
  int year = 2026,
  String semester = '2',
  LectureMode mode = LectureMode.inPerson,
}) => TimetableClass(
  id: id,
  title: id,
  academicYear: year,
  semester: semester,
  defaultMode: mode,
  meetings: [
    for (var weekday = 1; weekday <= 7; weekday++)
      ClassMeeting(
        id: 'day-$weekday',
        weekday: weekday,
        startMinute: 540,
        endMinute: 600,
      ),
  ],
);

class _FileBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class _JsonBundle extends _FileBundle {
  _JsonBundle(this.json);
  final Map<String, dynamic> json;

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      jsonEncode(json);
}
