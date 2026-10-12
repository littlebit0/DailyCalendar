import 'dart:convert';

import 'package:daily/features/timetable/data/timetable_store.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/timetable_term.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TimetableClass _course({String? date = '2026-06-23'}) => TimetableClass(
  id: 'summer-credit',
  title: '여름 수업',
  academicYear: 2026,
  semester: '2',
  meetings: [
    ClassMeeting(
      id: 'tue',
      weekday: 2,
      startMinute: 780,
      endMinute: 950,
      classroom: '406',
      date: date,
    ),
  ],
);
TimetableSyncDocument _document(TimetableClass course, DateTime time) =>
    TimetableSyncDocument.records(
      courses: {
        timetableCourseSyncKey(course): TimetableSyncValue(
          course.toJson(),
          time,
          'a',
        ),
      },
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('published date emits once outside nominal term, never weekly', () {
    final course = _course();
    final fall = TimetablePeriod(
      start: DateTime(2026, 8, 31),
      end: DateTime(2026, 12, 18),
    );
    final days = [
      DateTime(2026, 6, 23),
      DateTime(2026, 6, 30),
      DateTime(2026, 9, 1),
    ];
    final occurrences = classOccurrences(
      [course],
      days,
      periodFor: (_) => fall,
    );
    expect(occurrences.map((o) => o.date), [DateTime(2026, 6, 23)]);
    expect(occurrences.single.end.hour, 16); // retained half-hour presentation
    expect(
      classOccurrences(
        [_course(date: null)],
        days,
        periodFor: (_) => fall,
      ).map((o) => o.date),
      [DateTime(2026, 9, 1)],
    );
  });

  test('date parser rejects rollover, time suffix and mismatched weekday', () {
    for (final date in [
      '2026-02-30',
      '2026-06-23T00:00:00Z',
      '2026-06-24',
      '26-06-23',
    ]) {
      expect(_course(date: date).isValid, isFalse, reason: date);
    }
    final withPeriod = TimetableClass.fromJson({
      ..._course().toJson(),
      'period': {'startDate': '2026-09-01', 'endDate': '2026-12-18'},
    });
    expect(withPeriod.isValid, isFalse);
  });

  test(
    'date-specific cancellation stays on that date and keeps original clock',
    () {
      final course = _course();
      final updated = course.withOverride(
        course.meetings.single,
        DateTime(2026, 6, 23),
        LectureMode.cancelled,
      );
      expect(updated.meetings.single.date, '2026-06-23');
      expect(updated.meetings.single.originalEndMinute, 950);
      expect(classOccurrences([updated], [DateTime(2026, 6, 23)]), isEmpty);
      expect(
        classOccurrences(
          [updated],
          [DateTime(2026, 6, 23)],
          includeUnscheduled: true,
        ).single.mode,
        LectureMode.cancelled,
      );
    },
  );

  test(
    'local save reload and new-device merge preserve dates and version 2',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final source = TimetableStore(prefs);
      await source.save(_course());
      final raw =
          jsonDecode(prefs.getString(TimetableStore.storageKey)!) as Map;
      expect(raw['version'], 2);
      expect((raw['sync'] as Map)['document']['schemaVersion'], 2);
      final restored = TimetableStore(prefs);
      expect(restored.loadError, isNull);
      expect(restored.classes.single.meetings.single.date, '2026-06-23');
      await restored.seedTermPeriods({
        timetableTermSyncKey(2026, '2'): TimetablePeriod(
          start: DateTime(2026, 8, 31),
          end: DateTime(2026, 12, 18),
        ),
      });
      expect(restored.syncDocument().schemaVersion, 2);
      SharedPreferences.setMockInitialValues({});
      final target = TimetableStore(await SharedPreferences.getInstance());
      await target.mergeSyncDocument(
        TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(restored.syncDocument().toJson())),
        ),
      );
      expect(target.classes.single.toJson(), restored.classes.single.toJson());
      await target.setOverride(
        _course().id,
        'tue',
        DateTime(2026, 6, 23),
        LectureMode.liveOnline,
      );
      await expectLater(
        target.setOverride(
          _course().id,
          'tue',
          DateTime(2026, 6, 30),
          LectureMode.cancelled,
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'schema 1 containing dated classes is rejected without cache overwrite',
    () async {
      final payload = jsonEncode({
        'version': 1,
        'activeYear': 2026,
        'activeSemester': '2',
        'classes': [_course().toJson()],
      });
      SharedPreferences.setMockInitialValues({
        TimetableStore.storageKey: payload,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs);
      expect(store.loadError, isNotNull);
      await expectLater(store.save(_course(date: null)), throwsStateError);
      expect(prefs.getString(TimetableStore.storageKey), payload);
      final document = _document(_course(), DateTime.utc(2026, 10, 1)).toJson();
      expect(
        () => TimetableSyncDocument.fromJson({...document, 'schemaVersion': 1}),
        throwsFormatException,
      );
    },
  );

  test(
    'offline old weekly edit cannot strip published dates in either merge order',
    () {
      final dated = _document(_course(), DateTime.utc(2026, 10, 1));
      final old = _document(_course(date: null), DateTime.utc(2026, 10, 2));
      expect(() => dated.merge(old), throwsFormatException);
      expect(() => old.merge(dated), throwsFormatException);
      final earlier = _document(_course(date: null), DateTime.utc(2026, 9, 30));
      expect(
        dated.merge(earlier).materializeClasses().single.meetings.single.date,
        '2026-06-23',
      );
      final compatible = TimetableSyncDocument.fromJson({
        ...old.toJson(),
        'schemaVersion': 2,
      });
      expect(
        dated
            .merge(compatible)
            .materializeClasses()
            .single
            .meetings
            .single
            .date,
        isNull,
      );
    },
  );
  test(
    'legacy published period migrates without losing dates or revisions',
    () async {
      final course = TimetableClass.fromJson({
        ..._course(date: null).toJson(),
        'period': {'startDate': '2026-09-01', 'endDate': '2026-10-20'},
      });
      final oldDocument = _document(course, DateTime.utc(2026, 9, 1)).toJson();
      oldDocument['schemaVersion'] = 1;
      final raw = jsonEncode({
        'version': 1,
        'activeYear': 2026,
        'activeSemester': '2',
        'classes': [course.toJson()],
        'sync': {'document': oldDocument, 'pending': false, 'deviceId': 'a'},
      });
      SharedPreferences.setMockInitialValues({TimetableStore.storageKey: raw});
      final prefs = await SharedPreferences.getInstance();
      final store = TimetableStore(prefs);
      expect(store.loadError, isNull);
      expect(store.hasPendingSync, isTrue);
      expect(store.classes.single.period, course.period);
      expect(store.syncDocument().schemaVersion, 2);
      expect(
        store.syncDocument().courses.values.single.changedAt,
        DateTime.utc(2026, 9, 1),
      );
      await store.renameActive('집중 수업');
      expect(
        jsonDecode(prefs.getString(TimetableStore.storageKey)!)['version'],
        2,
      );
      final oldOfflineEdit = _document(
        _course(date: null),
        DateTime.utc(2026, 9, 2),
      );
      expect(
        () => store.syncDocument().merge(oldOfflineEdit),
        throwsFormatException,
      );
    },
  );
}
