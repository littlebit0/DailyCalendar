import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/file_asset_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'KNU registered whole scope retains source campuses and blocked exceptions',
    () async {
      final data = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'knu',
      );
      expect(
        {for (final d in data) d.campus: d.courses.length},
        {
          'daegu': 3117,
          'sangju': 497,
          'dongin': 26,
          'downtown': 2,
          'unassigned': 205,
        },
      );
      final courses = [for (final d in data) ...d.courses];
      expect(courses, hasLength(3847));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(3847));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(3724));
      // Official remark "이론은 금 6/7교시 강의" + KNU period table (n교시 = (8+n):00).
      for (final (id, start) in [('NURS0309-001', 840), ('NURS0309-002', 900)]) {
        final nursing = courses.singleWhere((c) => c.codeAndSection == id);
        expect(nursing.sourceSchedule, isEmpty);
        expect(nursing.scheduleStatus, 'scheduled');
        expect(
          nursing.meetings
              .map((m) => [m.weekday, m.originalStartMinute, m.originalEndMinute])
              .toList(),
          [
            [5, start, start + 60],
          ],
        );
      }
      expect(courses.where((c) => c.scheduleStatus == 'unrecognized'), isEmpty);
      // Remote/exchange rows keep their official HH:mm clocks as-is.
      final exchange = courses.singleWhere(
        (c) => c.codeAndSection == 'AAAA0101-001',
      );
      expect(exchange.sourceSchedule, '토 10:00 ~ 11:00');
      expect(exchange.scheduleStatus, 'scheduled');
      expect(
        exchange.meetings
            .map((m) => [m.weekday, m.originalStartMinute, m.originalEndMinute])
            .toList(),
        [
          [6, 600, 660],
        ],
      );
      final remote = courses.singleWhere(
        (c) => c.codeAndSection == 'CLTR0539-001',
      );
      expect(remote.sourceSchedule, '목 16:30 ~ 18:00,화 16:30 ~ 18:00');
      expect(
        remote.meetings
            .map(
              (m) => [
                m.weekday,
                m.originalStartMinute,
                m.originalEndMinute,
                m.classroom,
              ],
            )
            .toList(),
        [
          [4, 990, 1080, '상주캠퍼스 제6호관 / 124'],
          [2, 990, 1080, '상주캠퍼스 제6호관 / 124'],
        ],
      );
      expect(
        remote.departmentRemarks.values.join('\n'),
        allOf(contains('공식 요일·시각 기준 확정'), isNot(contains('시간표 추가 불가'))),
      );
      for (final id in [
        'TCHR0601-001',
        'TCHR0606-001',
        'TCHR0528-007',
        'CCCC0102-001',
      ]) {
        expect(courses.any((c) => c.codeAndSection == id), isFalse);
      }
      for (final c in courses) {
        if (!c.hasSchedulableMeetings) {
          expect(c.meetings, isEmpty);
          expect(
            c.departmentRemarks.values.join('\n'),
            contains(
              c.scheduleStatus == 'unscheduled' ? '요일·시각 미게시' : '시간표 추가 불가',
            ),
          );
        } else {
          expect(
            c.departmentRemarks.values.join('\n'),
            isNot(contains('요일·시각 미게시')),
          );
          final saved = c.toTimetable(
            id: c.sourceId,
            mode: LectureMode.inPerson,
          );
          final restored = TimetableClass.fromJson(saved.toJson());
          expect(restored.isValid, isTrue, reason: c.sourceId);
          expect(
            restored.meetings.map((m) => m.toJson()).toList(),
            saved.meetings.map((m) => m.toJson()).toList(),
          );
        }
        expect(
          c.departmentRemarks.values.any((s) => s.contains('<br>')),
          isFalse,
        );
      }
      final aliased = courses.singleWhere(
        (c) => c.codeAndSection == 'COMP0454-001',
      );
      expect(aliased.departmentClassifications['컴퓨터학부 인공지능컴퓨팅전공'], '전공필수');
      expect(aliased.departmentClassifications['IT 첨단자율학부'], '일반선택');
      for (final label in ['융합전공', '공학전공', '연계전공']) {
        expect(courseCategory(label), CourseCategory.major);
      }
      expect(courseCategory('전공심화'), CourseCategory.advancedMajor);
    },
  );

  test(
    'KNU dated online teaching excludes exams and preserves actual moved date',
    () async {
      final data = await UniversityCatalog.load(
        bundle: FileAssetBundle(),
        university: 'knu',
      );
      final courses = [for (final d in data) ...d.courses];
      final dated = courses.where(
        (c) =>
            ['AAAA0912', 'AAAA0901'].contains(c.code) &&
            c.meetings.any((m) => m.date != null),
      );
      expect(dated, hasLength(2));
      for (final c in dated) {
        final restored = TimetableClass.fromJson(
          c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).toJson(),
        );
        for (final m in restored.meetings) {
          expect(m.date, isNotNull);
          expect(restored.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
          expect(m.classroom, isEmpty);
          expect(m.date, isNot('2026-10-24'));
          expect(m.date, isNot('2026-12-12'));
        }
        if (c.code == 'AAAA0912') {
          expect(restored.meetings, hasLength(6));
          expect(restored.meetings.map((m) => m.date), contains('2026-09-23'));
        } else {
          expect(restored.meetings, hasLength(7));
        }
      }
      // Without a dated weekly plan the official weekly clocks are used as-is.
      final weekly = courses.singleWhere(
        (c) => c.codeAndSection == 'AAAA0908-001',
      );
      expect(weekly.meetings.every((m) => m.date == null), isTrue);
      expect(
        weekly.meetings
            .map((m) => [m.weekday, m.originalStartMinute, m.originalEndMinute])
            .toList(),
        [
          [6, 840, 900],
          [5, 1080, 1140],
          [5, 1140, 1200],
        ],
      );
    },
  );

  test(
    'KNU unified profile defaults to Daegu and excludes winter vacation',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000005',
        universityName: '경북대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000005',
      );
      expect(profile.timetableUniversity, 'knu');
      expect(profile.timetableCampus, 'daegu');
      final period = (await TimetablePeriodDefaults.load(
        bundle: FileAssetBundle(),
      )).periodFor(2026, '2', university: 'knu')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 18));
    },
  );
}
