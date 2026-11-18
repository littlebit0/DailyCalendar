import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/file_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'INHA catalog has complete identities, real half-hour times and remarks',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'inha',
      );
      final courses = datasets.single.courses;
      expect(courses, hasLength(2777));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2777));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(2704));
      expect(courses.every((c) => c.meetings.every((m) => m.isValid)), isTrue);
      expect(courses.any((c) => c.remarks.isNotEmpty), isTrue);
      expect(
        courses.any((c) => c.categoriesFor().any((cat) => cat.label == '교직')),
        isTrue,
      );
      final course = courses.singleWhere(
        (c) => c.codeAndSection == 'BPE4206-001',
      );
      // 원문은 `목21,…,32`다. 공개 교시 목록은 24교시(21:00 종료)까지라, 21:00 이후
      // 시각은 tool/timetable/import_inha.py가 30분 간격을 이어 붙인 추정값이다.
      // 실제로 다음 날 01:00까지 수업하는지는 원문 미확인이다(#950).
      expect(
        course.meetings.map((m) => (m.weekday, m.startMinute, m.endMinute)),
        [(4, 1140, 1440), (5, 0, 60)],
      );
      final saved = course.toTimetable(id: 'test', mode: LectureMode.inPerson);
      expect(
        TimetableClass.fromJson(
          Map<String, dynamic>.from(saved.toJson()),
        ).isValid,
        isTrue,
      );
    },
  );
  test('INHA profile and semester bounds stay separate from SMU', () async {
    const profile = AcademicProfile(
      universityId: 'institution:academyinfo:0000169',
      universityName: '인하대학교',
      schoolKind: 'fourYear',
      campusId: 'academyinfo:0000169',
    );
    expect(profile.timetableUniversity, 'inha');
    expect(profile.timetableCampus, 'main');
    final defaults = await TimetablePeriodDefaults.load(bundle: FileAssetBundle());
    final period = defaults.periodFor(2026, '2', university: 'inha')!;
    expect(period.start, DateTime(2026, 8, 31));
    expect(period.end, DateTime(2026, 12, 18));
    expect(period.contains(DateTime(2026, 8, 30)), isFalse);
    expect(period.contains(DateTime(2026, 12, 19)), isFalse);
    final course =
        UniversityDataset.fromJson(
              jsonDecode(
                File(
                  'assets/timetable/inha-main-2026-2.json',
                ).readAsStringSync(),
              ),
            ).courses
            .singleWhere((c) => c.codeAndSection == 'BPE4206-001')
            .toTimetable(id: 'test', mode: LectureMode.inPerson);
    expect(
      classOccurrences(
        [course],
        [DateTime(2026, 12, 25)],
        periodFor: (_) => period,
      ),
      isEmpty,
    );
  });
}
