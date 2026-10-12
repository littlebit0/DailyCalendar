import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/core/academic/unist_academic_source.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Current officially linked UNIST undergraduate dated plans preserve actual clocks, exceptions, calendar and all modes through Drive',
    () {
      const root = 'work/university-research/catalog-f/unist/';
      Map<String, dynamic> read(String n) =>
          jsonDecode(
                fixtureFile(
                  n ==
                          'unist-unknown-2026-2.current-two-faculty-plans-partial-v1.json'
                      ? 'assets/timetable/unist-unknown-2026-2.json'
                      : '$root$n',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final source = read(
        'unist-current-two-faculty-plan-education-source-20261008.json',
      );
      final plans = {
        for (final p in source['coursePlans'] as List) p['sourceId']: p,
      };
      final proof = source['officialPublicPublicationProof'] as List;
      expect(
        proof[1]['educationPublicLinks'].single['publicTarget'],
        'https://websec-lab.github.io/',
      );
      expect(proof[2]['nativeUndergraduateEntry']['code'], 'CSE480');
      expect(
        proof[2]['nativeUndergraduateEntry']['nativePageScope'],
        contains('학사과정'),
      );
      final calendar = UnistAcademicSource.parse(
        fixtureFile(
          '${root}unist-current-own-calendar-educational-rows-20261008.json',
        ).readAsStringSync(),
        2026,
      );
      final entries = source['calendar']['educationalEvents'] as List;
      expect(
        entries.any(
          (r) =>
              r['startDate'] == '2026-08-31' &&
              (r['nativeTitle'] as String).contains('개강'),
        ),
        true,
      );
      expect(
        entries.any(
          (r) =>
              r['startDate'] == '2026-12-18' &&
              (r['nativeTitle'] as String).contains('종강'),
        ),
        true,
      );
      expect(calendar, isNotEmpty);
      expect(
        calendar
            .singleWhere(
              (e) => e.title.contains('제2학기') && e.title.contains('개강'),
            )
            .start,
        DateTime(2026, 8, 31),
      );
      expect(
        calendar.singleWhere((e) => e.title == '제2학기 종강').start,
        DateTime(2026, 12, 18),
      );
      expect(
        calendar
            .singleWhere((e) => e.title == '중간고사' && e.start.month == 10)
            .start,
        DateTime(2026, 10, 19),
      );
      expect(
        calendar
            .singleWhere((e) => e.title == '중간고사' && e.start.month == 10)
            .end,
        DateTime(2026, 10, 24),
      );
      expect(
        calendar
            .singleWhere((e) => e.title == '기말고사' && e.start.month == 12)
            .start,
        DateTime(2026, 12, 14),
      );
      expect(
        calendar
            .singleWhere((e) => e.title == '기말고사' && e.start.month == 12)
            .end,
        DateTime(2026, 12, 19),
      );
      final raw = read(
        'unist-unknown-2026-2.current-two-faculty-plans-partial-v1.json',
      );
      expect(raw['termStartDate'], '2026-08-31');
      expect(raw['termEndDate'], '2026-12-18');
      final ds = UniversityDataset.fromJson(raw);
      expect(ds.courses, hasLength(2));
      expect(ds.courses.map((c) => c.sourceId).toSet(), hasLength(2));
      expect(ds.courses.fold<int>(0, (n, c) => n + c.meetings.length), 40);
      for (final c in ds.courses) {
        final p = plans[c.sourceId]!;
        expect(
          c.code,
          RegExp(
            r'^(UNI\d+|CSE\d+)',
          ).firstMatch(p['nativeCourseHeading'] as String)!.group(0),
        );
        expect(p['nativeCourseHeading'], contains('Fall 2026'));
        expect(c.title, p['nativeCourseTitle']);
        expect(c.section, isEmpty);
        expect(c.credits, isNull);
        expect(c.sourceClassification, isEmpty);
        expect(c.campus, 'unknown');
        expect(c.professor, p['nativeProfessor']);
        final clock = RegExp(
          r'(\d+):(\d+)–(\d+):(\d+) pm',
        ).firstMatch(p['nativeFacts']['Time'] as String)!;
        final start =
            (int.parse(clock[1]!) % 12 + 12) * 60 + int.parse(clock[2]!);
        final end =
            (int.parse(clock[3]!) % 12 + 12) * 60 + int.parse(clock[4]!);
        final loc = RegExp(
          r'Room (\w+), Building (\d+)',
        ).firstMatch(p['nativeFacts']['Location'] as String)!;
        expect(c.sourceClassroom, '${loc[2]}-${loc[1]}');
        final dates = (p['educationDateRows'] as List)
            .where(
              (r) =>
                  r['nativeNoClassText'] == '' &&
                  r['nativeDeliveryException'] == '' &&
                  r['nativeKind'] != 'exam',
            )
            .map((r) => r['nativeISODate'])
            .toList();
        expect(c.meetings.map((m) => m.date).toList(), dates);
        for (final m in c.meetings) {
          final d = DateTime.parse(m.date!);
          expect(d.isBefore(DateTime(2026, 8, 31)), false);
          expect(d.isAfter(DateTime(2026, 12, 18)), false);
          expect(m.originalStartMinute, start);
          expect(m.originalEndMinute, end);
          expect(m.classroom, c.sourceClassroom);
          expect(m.weekday, d.weekday);
          expect(m.date, isNot('2026-09-24'));
          expect(m.date, isNot('2026-09-15'));
          expect(m.date, isNot('2026-12-17'));
          expect(
            m.date!.compareTo('2026-10-19') >= 0 &&
                m.date!.compareTo('2026-10-23') <= 0,
            false,
          );
          expect(
            m.date!.compareTo('2026-12-14') >= 0 &&
                m.date!.compareTo('2026-12-18') <= 0,
            false,
          );
        }
        if (c.code == 'UNI111') {
          expect(c.meetings, hasLength(14));
          expect(p['nativeFacts']['For'], 'First-year students');
          expect(p['nativeProfessorRole'], 'Coordinator');
        }
        if (c.code == 'CSE480') {
          expect(c.meetings, hasLength(26));
          expect(p['nativeProfessorRole'], 'Instructor');
        }
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = ds.courses
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(2));
        final lookup = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(
            c.toJson()..remove('id'),
            lookup[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.note, contains('공개 교수 운영 계획, 실제 출석/개별 변경 미확인'));
          expect(c.note, contains('내부 원문 문서 위치 식별자는 수강신청 분반번호가 아닙니다'));
        }
      }
    },
  );
}
