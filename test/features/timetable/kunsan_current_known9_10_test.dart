import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const root =
    'work/university-research/catalog-m/'
    'kunsan-known9-10-pending-partial-root-review-v3-20261009/';

Map<String, dynamic> read(String name) =>
    jsonDecode(
          fixtureFile(
            name.endsWith('.known9-10-root-review-v3.json')
                ? 'assets/timetable/${name.replaceAll('.known9-10-root-review-v3', '')}'
                : '$root$name',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  test('Kunsan known9/10 keeps1717 whole and native11 held', () {
    final proof = read(
      'native-clock-date-calendar-and-preservation-proof.json',
    );
    final entries = (proof['datasets'] as List).cast<Map<String, dynamic>>();
    final originals = <Map<String, dynamic>>[
      for (final entry in entries)
        ...(read(entry['priorFile'] as String)['courses'] as List)
            .cast<Map<String, dynamic>>(),
    ];
    final rows = <Map<String, dynamic>>[
      for (final entry in entries)
        ...(read(entry['file'] as String)['courses'] as List)
            .cast<Map<String, dynamic>>(),
    ];
    final byId = {for (final row in rows) row['sourceId']: row};
    expect(byId, hasLength(1718));
    const key = 'kunsan/unknown/2026/2/116289/01';
    for (final original in originals) {
      if (original['sourceId'] != key) {
        expect(byId[original['sourceId']], original);
      }
    }
    final before = originals.singleWhere((c) => c['sourceId'] == key);
    final after = byId[key]!;
    for (final field in proof['sameCourseNativeFieldsExact'] as List) {
      expect(after[field], before[field]);
    }
    expect(before['schedules'], isEmpty);
    expect(after['courseCode'], '116289');
    expect(after['section'], '01');
    expect(after['professor'], '이승희');
    expect(after['courseName'], '디자인교과교재및연구법');
    expect(after['sourceSchedule'], '금9 10 11 [예술관-5403]');
    expect(after['classification'], '전공선택');
    expect(after['remarks'], contains('11교시'));
    expect(after['remarks'], contains('19:10'));
    expect(after['remarks'], contains('추정하거나'));
    expect(after['sourceEducation']['nativePublishedWeekday'], 5);
    expect(after['sourceEducation']['unresolvedSourcePeriodScope'], [
      {
        'sourceWeekday': 5,
        'sourcePeriodLiteral': '11',
        'sourceClassroom': '예술관-5403',
      },
    ]);
    const dates = [
      '2026-09-04',
      '2026-09-11',
      '2026-09-18',
      '2026-10-02',
      '2026-10-16',
      '2026-10-30',
      '2026-11-06',
      '2026-11-13',
      '2026-11-20',
      '2026-11-27',
      '2026-12-04',
      '2026-12-08',
      '2026-12-09',
    ];
    final meetings = (after['schedules'] as List).cast<Map<String, dynamic>>();
    expect(meetings.map((m) => m['date']).toList(), dates);
    for (final m in meetings) {
      expect(m['startMinute'], 1030);
      expect(m['endMinute'], 1140);
      expect(m['classroom'], '예술관-5403');
      expect(m['weekday'], DateTime.parse(m['date'] as String).weekday);
      expect(m['deliveryMode'], 'inPerson');
    }
    expect(meetings[11]['weekday'], 2);
    expect(meetings[12]['weekday'], 3);
    expect(after['sourceEducation']['makeupNativeWeekdayByActualDate'], {
      '2026-12-08': 5,
      '2026-12-09': 5,
    });
    expect(after['period'], {
      'startDate': '2026-08-31',
      'endDate': '2026-12-17',
    });
    expect(proof['wholeClassOperatingConfirmed'], isFalse);
    expect(proof['wholeClassEndConfirmed'], isFalse);
    expect(
      proof['exactMakeupEducationalRow'][1],
      contains('12.8.(화): 추석 9.25.(금)'),
    );
    expect(
      proof['exactMakeupEducationalRow'][1],
      contains('12.9.(수): 한글날 10.9.(금)'),
    );
    expect(
      originals.where((r) => (r['schedules'] as List).isNotEmpty),
      hasLength(1124),
    );
    expect(
      rows.where((r) => (r['schedules'] as List).isNotEmpty),
      hasLength(1125),
    );
    expect(
      originals.fold<int>(0, (n, r) => n + (r['schedules'] as List).length),
      22971,
    );
    expect(
      rows.fold<int>(0, (n, r) => n + (r['schedules'] as List).length),
      22984,
    );

    final datasets = [
      for (final entry in entries)
        UniversityDataset.fromJson(read(entry['file'] as String)),
    ];
    final allCourses = datasets.expand((d) => d.courses).toList();
    expect(allCourses, hasLength(1718));
    final scheduled = allCourses.where((c) => c.meetings.isNotEmpty).toList();
    expect(scheduled, hasLength(1125));
    expect(scheduled.fold<int>(0, (n, c) => n + c.meetings.length), 22984);
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final classes = scheduled
          .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
          .toList();
      final bySource = {for (final c in classes) c.sourceId: c};
      final document = TimetableSyncDocument.legacy(
        courses: classes,
        termNames: {},
        activeYear: 2026,
        activeSemester: '2',
      );
      final restored = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
      ).materializeClasses();
      expect(restored, hasLength(1125));
      expect(restored.map((c) => c.sourceId).toSet(), bySource.keys.toSet());
      expect(restored.fold<int>(0, (n, c) => n + c.meetings.length), 22984);
      for (final c in restored) {
        final original = bySource[c.sourceId]!;
        expect(c.isValid, isTrue);
        expect(c.defaultMode, mode);
        expect(c.id, timetableCourseSyncKey(original));
        expect(c.toJson(), {
          ...original.toJson(),
          'id': timetableCourseSyncKey(original),
        });
        for (final meeting in c.meetings) {
          expect(
            c.modeOn(meeting, DateTime.parse(meeting.date!)),
            original.modeOn(meeting, DateTime.parse(meeting.date!)),
          );
        }
      }
      final partial = restored.singleWhere((c) => c.sourceId == key);
      expect(partial.meetings, hasLength(13));
      expect(partial.meetings[11].weekday, 2);
      expect(partial.meetings[12].weekday, 3);
      for (final meeting in partial.meetings) {
        expect(
          partial.modeOn(meeting, DateTime.parse(meeting.date!)),
          LectureMode.inPerson,
        );
      }
    }
  });
}
