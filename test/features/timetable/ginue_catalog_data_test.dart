import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GINUE current published merged blocks retain document identity, actual campus and printed clock boundaries with study/practice exceptions in all modes and full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/ginue/';
      Map<String, dynamic> read(String n) =>
          jsonDecode(fixtureFile('$root$n').readAsStringSync())
              as Map<String, dynamic>;
      final source = read(
        'ginue-current-unambiguous-merged-source-20261008.json',
      );
      final rows = {
        for (final r in source['educationRows'] as List) r['sourceId']: r,
      };
      final datasets = [
        for (final campus in ['incheon', 'gyeonggi'])
          UniversityDataset.fromJson(
            read('ginue-$campus-2026-2.merged165-partial-v1.json'),
          ),
      ];
      expect(datasets[0].courses, hasLength(29));
      expect(datasets[1].courses, hasLength(136));
      final all = datasets.expand((d) => d.courses).toList();
      expect(all.map((c) => c.sourceId).toSet(), hasLength(165));
      expect(all.fold<int>(0, (n, c) => n + c.meetings.length), 2025);
      expect(source['todayLiveRequestsReturnedBlankHtml'], true);
      for (final c in all) {
        final r = rows[c.sourceId];
        expect(r, isNotNull);
        expect(c.code, isEmpty);
        expect(c.credits, isNull);
        expect(c.sourceClassification, isEmpty);
        expect(c.title, r['courseName']);
        expect(c.professor, r['professor']);
        expect(c.sourceClassroom, r['classroom']);
        expect(c.departments, [r['nativeColumnHeader']]);
        expect(c.section, r['section']);
        expect(c.sourceId, contains('#sheet='));
        expect(c.sourceId, endsWith('&cell=${r['cell']}'));
        expect(c.campus, r['campusNative'] == '인천' ? 'incheon' : 'gyeonggi');
        final clocks = r['clockRows'] as List;
        expect(
          c.sourceSchedule,
          '${clocks.first['weekday']} ${clocks.first['start']}~${clocks.last['end']}',
        );
        for (final m in c.meetings) {
          expect(m.originalStartMinute, r['startMinute']);
          expect(m.originalEndMinute, r['endMinute']);
          expect(
            m.originalEndMinute - m.originalStartMinute,
            clocks.length * 60,
          );
          expect(m.weekday, r['weekday']);
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(m.classroom, r['classroom']);
          expect(
            m.date!.compareTo('2026-08-31') >= 0 &&
                m.date!.compareTo('2026-12-13') <= 0,
            true,
          );
          expect([
            '2026-09-24',
            '2026-09-25',
            '2026-09-26',
            '2026-10-03',
            '2026-10-05',
            '2026-10-09',
          ], isNot(contains(m.date)));
          expect(
            m.date!.compareTo('2026-10-12') < 0 ||
                m.date!.compareTo('2026-10-16') > 0,
            true,
          );
          if (r['grade'] == 3) {
            expect(
              m.date!.compareTo('2026-10-12') < 0 ||
                  m.date!.compareTo('2026-10-30') > 0,
              true,
            );
          }
        }
      }
      final explicit = all.where((c) => c.section.isNotEmpty).toList();
      expect(explicit, hasLength(1));
      expect(explicit.single.title, '교육행정과학교경영');
      expect(explicit.single.section, '11');
      expect(explicit.single.professor, '구자원');
      final nativeNotice = fixtureFile(
        'work/university-research/catalog-g/ginue-current2026-2.html',
      ).readAsStringSync();
      expect(
        nativeNotice,
        contains('4학년 교육행정과학교경영 11반 월 6-8교시(구자원) 월 7-9교시로 변경'),
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = all
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: originals,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(165));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.note, contains('내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다'));
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(c.note, contains('최신 변경/폐강 대조 미완료'));
          expect(
            c.toJson()..remove('id'),
            lookup[c.sourceId]!.toJson()..remove('id'),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
