import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/file_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Dongguk WISE 2026-2 keeps every public timetable row and its printed '
      'clocks', () async {
    final data = (await UniversityCatalog.load(
      bundle: FileAssetBundle(),
      university: 'dongguk',
    )).singleWhere((d) => d.campus == 'wise');
    final courses = data.courses;
    // 1,683 dsMain rows of the 학부(WISE) query, unique 학수번호-분반.
    expect(courses, hasLength(1683));
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(1683));
    final byStatus = <String?, int>{};
    for (final c in courses) {
      byStatus[c.scheduleStatus] = (byStatus[c.scheduleStatus] ?? 0) + 1;
    }
    expect(byStatus, {
      'scheduled': 1477,
      'unscheduled': 138,
      'unrecognized': 68,
    });
    expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1477));
    expect(courses.every((c) => c.meetings.every((m) => m.isValid)), isTrue);

    UniversityCourse byKey(String key) =>
        courses.singleWhere((c) => c.sourceId == 'dongguk/wise/2026-2/$key');

    // '1.5교시(09:30) ~ 4교시(12:30)': front bracket starts, '~' bracket ends;
    // 180 minutes for 3.0 시수. Midterm 10/13~26 and 10/5 are skipped.
    final buddhism = byKey('LAC14626-01');
    expect(buddhism.sourceSchedule, '월 1.5교시(09:30) ~ 4교시(12:30)');
    expect(buddhism.departments, ['불교문화대학', '불교학부']);
    expect(
      buddhism.meetings
          .map((m) => (m.weekday, m.startMinute, m.endMinute, m.classroom))
          .toSet(),
      {(1, 570, 750, 'A307')},
    );
    expect(buddhism.meetings.map((m) => m.date), [
      '2026-09-07',
      '2026-09-14',
      '2026-09-21',
      '2026-09-28',
      '2026-10-12',
      '2026-11-02',
      '2026-11-09',
      '2026-11-16',
      '2026-11-23',
      '2026-11-30',
      '2026-12-07',
    ]);
    // Two weekdays, two rooms kept as one published room text.
    final history = byKey('AAH31222-01');
    expect(
      history.meetings
          .map((m) => (m.weekday, m.startMinute, m.endMinute, m.classroom))
          .toSet(),
      {
        (1, 570, 690, 'A110, A319(HyFlex)'),
        (6, 570, 750, 'A110, A319(HyFlex)'),
      },
    );
    // Same-day touching spans join into one block.
    expect(
      byKey(
        'EES30722-01',
      ).meetings.map((m) => (m.startMinute, m.endMinute)).toSet(),
      {(810, 1050)},
    );
    // Week-limited rows stay as published text only.
    final elderly = byKey('NUR30914-01');
    expect(elderly.scheduleStatus, 'unrecognized');
    expect(elderly.meetings, isEmpty);
    expect(elderly.sourceSchedule, startsWith('1주차 - 7주차 목'));
    // No weekday or clock published: addable as an untimed course.
    final cyber = byKey('COM31018-01');
    expect(cyber.scheduleStatus, 'unscheduled');
    expect(cyber.sourceSchedule, isEmpty);

    expect(
      TimetableClass.fromJson(
        Map<String, dynamic>.from(
          buddhism.toTimetable(id: 'test', mode: LectureMode.inPerson).toJson(),
        ),
      ).isValid,
      isTrue,
    );

    final wise = AcademicProfile(
      universityId: 'institution:academyinfo:0000100',
      universityName: '동국대학교',
      schoolKind: 'fourYear',
      campusId: 'academyinfo:0000101',
    );
    expect(wise.timetableUniversity, 'dongguk');
    expect(wise.timetableCampus, 'wise');
    expect(wise.timetableSupported, isTrue);
  });
}
