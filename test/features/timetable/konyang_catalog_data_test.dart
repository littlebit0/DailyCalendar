import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/file_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Konyang partial catalog keeps syllabus clocks per campus period table',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'konyang',
      );
      expect(datasets.map((d) => d.campus).toSet(), {
        'glocal',
        'medical',
        'unknown',
      });
      final courses = [for (final d in datasets) ...d.courses];
      expect(courses, hasLength(1558));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(1558));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(280));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(1267),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(11),
      );
      expect(courses.every((c) => c.meetings.every((m) => m.isValid)), isTrue);
      expect(courses.any((c) => c.sourceClassification == '학석사연계'), isFalse);

      UniversityCourse find(String codeAndSection) =>
          courses.singleWhere((c) => c.codeAndSection == codeAndSection);
      List<(int, int, int)> clocks(UniversityCourse c) => [
        for (final m in c.meetings) (m.weekday, m.startMinute, m.endMinute),
      ];

      // 글로컬캠퍼스: 1교시 09:30, 60-minute slots.
      final abap = find('68212A-01');
      expect(abap.campus, 'glocal');
      expect(abap.sourceSchedule, '화(2,3),금(2)');
      expect(clocks(abap), [(2, 630, 750), (5, 630, 690)]);
      // 메디컬캠퍼스: 1교시 09:00.
      expect(clocks(find('61570A-01')), [(1, 780, 900), (3, 780, 900)]);
      // The latest notice (nttId=292203) makes 대전학 a pre-recorded online
      // course, so the earlier 화 10,11교시 change is not used.
      final daejeon = find('00042K-01');
      expect(daejeon.campus, 'medical');
      expect(daejeon.scheduleStatus, 'unscheduled');
      expect(daejeon.meetings, isEmpty);
      // Campus-marked text keeps only the offering campus's part:
      // '교양학부(대전)' 2시수 "(논산) 월5,6 (대전) 목 5,6" -> 메디컬 목 5,6교시.
      final split = find('00011L-02');
      expect(split.campus, 'medical');
      expect(clocks(split), [(4, 780, 900)]);
      // 3시수 but the 글로컬 part has 2 periods: time undecided, text kept.
      final mismatch = find('31390B-01');
      expect(mismatch.campus, 'glocal');
      expect(mismatch.scheduleStatus, 'unscheduled');
      expect(mismatch.sourceSchedule, '(논산) 월5,6 (대전) 목 5,6');
      // A course added by notice (nttId=292200) gets each campus's time.
      expect(clocks(find('00086K-01')), [(3, 810, 930)]);
      expect(clocks(find('00086K-02')), [(2, 780, 900)]);
      // A syllabus that names its campus overrides the department campus.
      expect(find('11055A-01').campus, 'glocal');
      // The 경영학부 homepage footer names 글로컬캠퍼스.
      final accounting = find('31613A-01');
      expect(accounting.campus, 'glocal');
      expect(accounting.sourceSchedule, '화요일 2-3교시, 수요일 5교시');
      expect(clocks(accounting), [(2, 630, 750), (3, 810, 870)]);
      // No published campus: the period table cannot be chosen.
      final tourism = find('11101A-01');
      expect(tourism.campus, 'unknown');
      expect(tourism.scheduleStatus, 'unrecognized');
      expect(tourism.canAddToTimetable, isFalse);
      // Notation that cannot be read as periods stays verbatim, time undecided.
      final typo = find('61714A-01');
      expect(typo.sourceSchedule, '울(6,7), 수(3)');
      expect(typo.scheduleStatus, 'unscheduled');
      expect(typo.meetings, isEmpty);
      expect(typo.canAddToTimetable, isTrue);
      // "월 수/5, /1~2" pairs weekdays and period groups in order: 월 5, 수 1~2.
      final paired = find('61482A-01');
      expect(paired.sourceSchedule, '월 수/5, /1~2');
      expect(clocks(paired), [(1, 780, 840), (3, 540, 660)]);
      // "월,수 3,4교시" on a 2-2-0 course pairs in order: 월 3교시, 수 4교시.
      expect(clocks(find('80207C-01')), [(1, 660, 720), (3, 720, 780)]);
      // Weekdays without any period stay verbatim and time undecided.
      final noPeriod = find('61480A-01');
      expect(noPeriod.sourceSchedule, '화요일 수요일');
      expect(noPeriod.scheduleStatus, 'unscheduled');
      expect(noPeriod.meetings, isEmpty);

      expect(
        abap.isMajorForSourceDepartment('기업소프트웨어학부'),
        isTrue,
        reason: '제1기본 is the major basic-course classification',
      );
      expect(
        TimetableClass.fromJson(
          Map<String, dynamic>.from(
            abap.toTimetable(id: 'test', mode: LectureMode.inPerson).toJson(),
          ),
        ).isValid,
        isTrue,
      );
    },
  );

  test('Konyang campuses map to their own catalog and semester', () async {
    for (final (campusId, campus) in [
      ('academyinfo:0000054', 'glocal'),
      ('academyinfo:0000055', 'medical'),
    ]) {
      final profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000054',
        universityName: '건양대학교',
        schoolKind: 'fourYear',
        campusId: campusId,
      );
      expect(profile.timetableUniversity, 'konyang');
      expect(profile.timetableCampus, campus);
      expect(profile.timetableSupported, isTrue);
    }
    final period = (await TimetablePeriodDefaults.load(
      bundle: FileAssetBundle(),
    )).periodFor(2026, '2', university: 'konyang')!;
    expect(period.start, DateTime(2026, 8, 24));
    expect(period.end, DateTime(2026, 12, 11));
  });
}
