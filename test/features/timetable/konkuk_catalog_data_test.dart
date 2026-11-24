import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/file_asset_bundle.dart';

// 정규학기 교시별 시간 안내, https://www.konkuk.ac.kr/konkuk/2367/subview.do
const _seoulClock = {
  1: (540, 570), 2: (570, 600), 3: (600, 630), 4: (630, 660), //
  5: (660, 690), 6: (690, 720), 7: (720, 750), 8: (750, 780),
  9: (780, 810), 10: (810, 840), 11: (840, 870), 12: (870, 900),
  13: (900, 930), 14: (930, 960), 15: (960, 990), 16: (990, 1020),
  17: (1020, 1050), 18: (1050, 1080), 19: (1095, 1140), 20: (1140, 1185),
  21: (1185, 1230), 22: (1230, 1275), 23: (1275, 1320),
};
const _days = '월화수목금토일';

// Seoul 융합대학 rows with an empty 강의시간 give the host time in 비고.
final _remarkTime = RegExp(
  r'강의요시: ([월화수목금토일]) (\d{2}):(\d{2})~(\d{2}):(\d{2})',
);

List<(int, int, int)> _expected(UniversityCourse course) {
  if (course.sourceSchedule.isEmpty) {
    return [
      if (_remarkTime.firstMatch(course.remarks) case final m?)
        (
          _days.indexOf(m[1]!) + 1,
          int.parse(m[2]!) * 60 + int.parse(m[3]!),
          int.parse(m[4]!) * 60 + int.parse(m[5]!),
        ),
    ];
  }
  final seoul = course.campus == 'seoul';
  final pattern = seoul
      ? RegExp(r'([월화수목금토일])(\d{2})(?:-(\d{2}))?')
      : RegExp(r'([월화수목금토일])(\d{2})(\d{2})-(\d{2})(\d{2})');
  return [
    for (final block in course.sourceSchedule.split(','))
      if (pattern.firstMatch(block.trim()) case final m?)
        seoul
            ? (
                _days.indexOf(m[1]!) + 1,
                _seoulClock[int.parse(m[2]!)]!.$1,
                _seoulClock[int.parse(m[3] ?? m[2]!)]!.$2,
              )
            : (
                _days.indexOf(m[1]!) + 1,
                int.parse(m[2]!) * 60 + int.parse(m[3]!),
                int.parse(m[4]!) * 60 + int.parse(m[5]!),
              ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Konkuk profile exposes Seoul and GLOCAL published timetables',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'konkuk',
      );
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'seoul': 2432, 'glocal': 1502},
      );
      for (final (campus, expected) in [
        ('academyinfo:0000052', 'seoul'),
        ('academyinfo:0000053', 'glocal'),
      ]) {
        final profile = AcademicProfile.fromJson(
          AcademicProfile(
            universityId: 'institution:academyinfo:0000052',
            universityName: '건국대학교',
            schoolKind: 'fourYear',
            campusId: campus,
          ).toJson(),
        );
        expect(profile.timetableUniversity, 'konkuk');
        expect(profile.timetableCampus, expected);
      }
      final period = (await TimetablePeriodDefaults.load(
        bundle: FileAssetBundle(),
      )).periodFor(2026, '2', university: 'konkuk');
      expect(period?.start, DateTime(2026, 8, 31));
      expect(period?.end, DateTime(2026, 12, 18));
    },
  );

  test('Konkuk meetings follow the published clocks and survive Drive JSON', () {
    final courses = <UniversityCourse>[];
    for (final campus in ['seoul', 'glocal']) {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/konkuk-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      courses.addAll(UniversityDataset.fromJson(raw).courses);
    }
    final byStatus = <String, int>{};
    for (final c in courses) {
      byStatus.update(c.scheduleStatus!, (v) => v + 1, ifAbsent: () => 1);
    }
    // Only GLOCAL unit 006771 (학수번호 BZZA) has no published name.
    final unnamed = courses.where((c) => c.departments.isEmpty).toList();
    expect(unnamed, hasLength(10));
    expect(
      unnamed.every(
        (c) => c.campus == 'glocal' && c.remarks.contains('학수번호 BZZA'),
      ),
      isTrue,
    );
    expect(
      courses.where((c) => c.departments.contains('교양학부')),
      hasLength(423),
    );
    expect(courses.where((c) => c.departments.contains('교직과')), hasLength(22));
    expect(byStatus, {'scheduled': 3749, 'unscheduled': 185});
    // Rows the GLOCAL timetable marks 폐강 stay in the catalog; none publishes a time.
    final closed = courses.where((c) => c.remarks.contains('강의시간표 폐강 표시'));
    expect(closed, hasLength(53));
    for (final c in closed) {
      expect(c.campus, 'glocal');
      expect(c.scheduleStatus, 'unscheduled', reason: c.sourceId);
    }
    // Seoul's literal period 00 e-러닝 row has no published time.
    final untimed = courses.singleWhere(
      (c) => c.sourceId == 'konkuk/seoul/2026/2/3704',
    );
    expect(untimed.scheduleStatus, 'unscheduled');
    expect(untimed.meetings, isEmpty);
    final approved = courses.where((c) => c.hasSchedulableMeetings).toList();
    // 비고 강의요시 rows use the host university's HH:mm time as-is.
    final remarkTimed = approved.where((c) => c.sourceSchedule.isEmpty);
    expect(remarkTimed, hasLength(6));
    final xr = remarkTimed.singleWhere(
      (c) => c.sourceId == 'konkuk/seoul/2026/2/4264',
    );
    expect(
      [
        for (final m in xr.meetings)
          (m.weekday, m.originalStartMinute, m.originalEndMinute),
      ],
      [(1, 540, 710)],
    );
    final online = courses.singleWhere(
      (c) => c.sourceId == 'konkuk/seoul/2026/2/4253',
    );
    expect(online.remarks.contains('강의요시: 온라인'), isTrue);
    expect(online.scheduleStatus, 'unscheduled');
    // 집중이수 rows are scheduled only within the weeks the timetable publishes.
    final intensive = approved.where((c) => c.remarks.contains('집중이수제: '));
    expect(intensive, hasLength(96));
    for (final c in intensive) {
      expect(c.campus, 'glocal');
      expect(c.remarks.contains('강의시간표 집중이수'), isTrue);
      expect(c.period, isNotNull);
    }
    final k002 = intensive.singleWhere(
      (c) => c.sourceId == 'konkuk/glocal/2026/2/K002',
    );
    expect(k002.period?.start, DateTime(2026, 8, 31));
    expect(k002.period?.end, DateTime(2026, 10, 25));
    expect(
      [
        for (final m in k002.meetings)
          (m.weekday, m.originalStartMinute, m.originalEndMinute),
      ],
      [(3, 540, 720)],
    );
    for (final c in approved) {
      expect(
        [
          for (final m in c.meetings)
            (m.weekday, m.originalStartMinute, m.originalEndMinute),
        ],
        _expected(c),
        reason: c.sourceId,
      );
    }
    expect(approved.expand((c) => c.meetings), hasLength(4946));
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final values = <String, TimetableSyncValue>{};
      for (final course in approved) {
        final saved = course.toTimetable(id: course.sourceId, mode: mode);
        expect(saved.isValid, isTrue);
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
