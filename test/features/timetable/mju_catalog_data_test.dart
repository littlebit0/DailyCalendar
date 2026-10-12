import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'MJU published undergraduate plans retain absent codes and native online identities without inventing actual operations',
    () {
      const root = 'work/university-research/catalog-f/mju/';
      Map<String, dynamic> read(String name) =>
          jsonDecode(File('$root$name').readAsStringSync())
              as Map<String, dynamic>;
      final art = read('mju-current-art-undergraduate-education-20261008.json');
      final online = read('mju-current-online-education-20261008.json');
      final closed = read('mju-current-final-closure-education-20261008.json');
      expect(art['nativeHeading'], "2026학년도 2학기 '학부 전공' 강좌배정 신청서");
      expect(art['excludedSheet'], '대학원');
      expect(art['excludedSheetHeading'], contains("'대학원'"));
      expect(closed['closedCourses'], hasLength(136));
      expect(closed['includesFirstClosureRows'], true);
      final datasets = [
        for (final campus in ['humanities', 'natural'])
          UniversityDataset.fromJson(
            read('mju-$campus-2026-2.art-online-partial-v1.json'),
          ),
      ];
      expect(datasets[0].courses, hasLength(80));
      expect(datasets[1].courses, hasLength(20));
      final all = datasets.expand((d) => d.courses).toList();
      expect(all.map((c) => c.sourceId).toSet(), hasLength(100));
      final plans = all.where((c) => c.meetings.isNotEmpty).toList();
      expect(plans, hasLength(7));
      expect(plans.fold<int>(0, (n, c) => n + c.meetings.length), 172);
      final expectedArts = {
        for (final row in art['educationRows'] as List) row['courseName']: row,
      };
      for (final c in plans) {
        final row = expectedArts[c.title];
        expect(row, isNotNull);
        expect(c.campus, 'humanities');
        expect(c.code, isEmpty);
        expect(c.section, isEmpty);
        expect(
          c.sourceId,
          'https://www.mju.ac.kr/bbs/gsca/433/179498/download.do#sheet=%EC%A0%84%EA%B3%B5&cell=C${row['sourceRow']}',
        );
        expect(c.professor, row['professor']);
        expect(c.credits, 3);
        expect(c.sourceClassroom, 'S1915');
        expect(c.sourceClassification, '학부 전공');
        expect(c.title, isNot(anyOf('한국도자사연습', '조선도자사특강', '불교미술세미나')));
        final nativeStart = row['nativeStartTime'] as String;
        final nativeEnd = row['nativeEndTime'] as String;
        final start =
            int.parse(nativeStart.substring(0, 2)) * 60 +
            int.parse(nativeStart.substring(2));
        final end =
            int.parse(nativeEnd.substring(0, 2)) * 60 +
            int.parse(nativeEnd.substring(2));
        for (final m in c.meetings) {
          expect(m.originalStartMinute, start);
          expect(m.originalEndMinute, end);
          expect(end - start, 75);
          expect(m.classroom, 'S1915');
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect({
            '2026-09-07',
            '2026-09-24',
            '2026-09-25',
            '2026-09-26',
            '2026-10-03',
            '2026-10-05',
            '2026-10-09',
          }, isNot(contains(m.date)));
          expect(
            m.date!.compareTo('2026-10-20') < 0 ||
                m.date!.compareTo('2026-10-26') > 0,
            true,
          );
          expect(
            m.date!.compareTo('2026-09-01') >= 0 &&
                m.date!.compareTo('2026-12-07') <= 0,
            true,
          );
        }
      }
      final remote = all.where((c) => c.meetings.isEmpty).toList();
      expect(remote, hasLength(93));
      final remoteSource = {
        for (final r in online['educationRows'] as List)
          '${r['campus']}/${r['nativeLectureNumber']}': r,
      };
      for (final c in remote) {
        final key =
            '${c.campus == 'humanities' ? '인문' : '자연'}/${c.sourceId.split('/').last}';
        final r = remoteSource[key];
        expect(c.code, r['nativeCourseCode']);
        expect(c.title, r['courseName']);
        expect(c.professor, r['professor']);
        expect(c.section, isEmpty);
        expect(c.credits, isNull);
        expect(
          c.sourceSchedule,
          '${r['weekday1']} ${r['nativeTime1']}; ${r['weekday2']} ${r['nativeTime2']}',
        );
        expect(c.sourceClassroom, '${r['classroom1']}; ${r['classroom2']}');
      }
      expect(
        remote.singleWhere((c) => c.sourceId.endsWith('/6072')).meetings,
        isEmpty,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = plans
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: originals,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(7));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          final original = lookup[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(c.note, contains('내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다'));
          expect(c.toJson()..remove('id'), original.toJson()..remove('id'));
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
