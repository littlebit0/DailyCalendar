import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'INHA catalog has complete identities, real half-hour times and remarks',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
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
    final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
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
