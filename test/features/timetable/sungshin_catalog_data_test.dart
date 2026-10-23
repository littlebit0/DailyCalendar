import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/core/academic/university_support_policy.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

const _days = '월화수목금토일';

// 2026-2 수강신청 안내(학부) p5 요일별 수업일. 15주차 금요일 수업은 12월 22일(화).
const _teachingDates = {
  1: '09-07 09-14 09-21 09-28 10-12 10-19 10-26 11-02 11-09 11-16 11-23 11-30 12-07 12-14 12-21',
  2: '09-01 09-08 09-15 09-22 09-29 10-06 10-13 10-20 10-27 11-03 11-10 11-17 11-24 12-01 12-08',
  3: '09-02 09-09 09-16 09-23 09-30 10-07 10-14 10-21 10-28 11-04 11-11 11-18 11-25 12-02 12-09',
  4: '09-03 09-10 09-17 10-01 10-08 10-15 10-22 10-29 11-05 11-12 11-19 11-26 12-03 12-10 12-17',
  5: '09-04 09-11 09-18 10-02 10-16 10-23 10-30 11-06 11-13 11-20 11-27 12-04 12-11 12-18 12-22',
  6: '09-05 09-12 09-19 09-26 10-03 10-10 10-17 10-24 10-31 11-07 11-14 11-21 11-28 12-05 12-12',
};

List<UniversityCourse> _courses() => [
  for (final campus in ['sujeong', 'unjung'])
    ...UniversityDataset.fromJson(
      jsonDecode(
            File(
              'assets/timetable/sungshin-$campus-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>,
    ).courses,
];

// 강의시간편성표: n교시 = 09:00 + (n-1)시간, 50분.
Set<(String, int, int)> _expected(UniversityCourse course) => {
  for (final block in course.sourceSchedule.split(','))
    if (RegExp(r'^([월화수목금토])/(\d+)(?:-(\d+))?$').firstMatch(block)
        case final m?)
      for (final day in _teachingDates[_days.indexOf(m[1]!) + 1]!.split(' '))
        (
          '2026-$day',
          480 + int.parse(m[2]!) * 60,
          530 + int.parse(m[3] ?? m[2]!) * 60,
        ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Sungshin catalog exposes both campuses and the published term',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'sungshin',
      );
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'sujeong': 1368, 'unjung': 670},
      );
      // Rows with an unresolved slot keep the university suspended.
      expect(UniversitySupportPolicy.timetableAvailable('sungshin'), isFalse);
      final profile = AcademicProfile.fromJson(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000136',
          universityName: '성신여자대학교',
          schoolKind: 'fourYear',
        ).toJson(),
      );
      expect(profile.timetableUniversity, 'sungshin');
      expect(profile.timetableCampus, 'sujeong');
      final period = (await TimetablePeriodDefaults.load(
        bundle: _Files(),
      )).periodFor(2026, '2', university: 'sungshin');
      expect(period?.start, DateTime(2026, 9, 1));
      expect(period?.end, DateTime(2026, 12, 22));
      for (final course in datasets.expand((d) => d.courses)) {
        expect(
          course.offeringOrganizations,
          isNotEmpty,
          reason: course.sourceId,
        );
        for (final unit in course.offeringOrganizations) {
          expect(unit.college, isNotNull, reason: course.sourceId);
        }
      }
    },
  );

  test('Sungshin meetings follow the published dates and clock', () {
    final courses = _courses();
    final byStatus = <String, int>{};
    for (final c in courses) {
      byStatus.update(c.scheduleStatus!, (v) => v + 1, ifAbsent: () => 1);
    }
    expect(byStatus, {
      'scheduled': 1743,
      'unrecognized': 282,
      'unscheduled': 13,
    });
    for (final c in courses.where((c) => c.scheduleStatus != 'scheduled')) {
      expect(c.meetings, isEmpty, reason: c.sourceId);
      expect(
        c.scheduleStatus == 'unscheduled'
            ? c.sourceSchedule.isEmpty
            : c.remarks.contains('시각 보류: '),
        isTrue,
        reason: c.sourceId,
      );
    }
    final scheduled = courses.where((c) => c.hasSchedulableMeetings).toList();
    expect(scheduled, hasLength(1743));
    for (final c in scheduled) {
      final actual = {
        for (final m in c.meetings)
          (m.date!, m.originalStartMinute, m.originalEndMinute),
      };
      if (c.remarks.contains('집중이수: ')) {
        // Only the syllabus that dates every session is scheduled.
        expect(c.code, 'DB095500');
        final dates = actual.map((m) => m.$1).toList()..sort();
        expect(dates, hasLength(15));
        expect((dates.first, dates.last), ('2026-09-01', '2026-10-22'));
        expect(_expected(c).containsAll(actual), isTrue);
      } else {
        expect(actual, _expected(c), reason: c.sourceId);
      }
    }
    // The 15th Friday session is held on Tuesday 12/22 (요일변경).
    expect(
      scheduled
          .expand((c) => c.meetings)
          .where((m) => m.date == '2026-12-22')
          .every((m) => m.weekday == DateTime.tuesday),
      isTrue,
    );
    expect(scheduled.expand((c) => c.meetings), hasLength(26460));
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final values = <String, TimetableSyncValue>{};
      for (final course in scheduled) {
        final saved = course.toTimetable(id: course.sourceId, mode: mode);
        expect(saved.isValid, isTrue, reason: course.sourceId);
        final key = timetableCourseSyncKey(saved);
        values[key] = TimetableSyncValue(
          {...saved.toJson(), 'id': key},
          DateTime.utc(2026, 10, 23),
          'test',
        );
      }
      final restored = TimetableSyncDocument.fromJson(
        jsonDecode(
              jsonEncode(
                TimetableSyncDocument.records(
                  courses: values,
                  schemaVersion: 2,
                ).toJson(),
              ),
            )
            as Map<String, dynamic>,
      );
      expect(restored.courses.keys.toSet(), values.keys.toSet());
      for (final entry in restored.courses.entries) {
        expect(entry.value.value, values[entry.key]!.value);
      }
    }
  });
}
