import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test(
    'Sungshin native current dates and clocks preserve all three choices through full Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/sungshin/';
      final proof =
          jsonDecode(
                fixtureFile(
                  '${root}sungshin-current-educational-proof-v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final nativeRows = proof['nativeRows'] as List;
      final p5 = proof['currentUndergraduateGuide']['nativePage5'] as String;
      expect(p5, contains('2026학년도 2학기 수업기간'));
      expect(p5, contains('모든 학부 수업'));
      final dateCells = RegExp(
        r'(\d+)월(\d+)일\(([월화수목금토])\)',
      ).allMatches(p5.split('※ 2026학년도 2학기 수업 제외일').first).toList();
      expect(dateCells, hasLength(90));
      final clocks = <int, List<int>>{};
      for (final row in proof['currentPublicClock']['nativeRows'] as List) {
        int minute(String x) {
          final p = x.split(':');
          return int.parse(p[0]) * 60 + int.parse(p[1]);
        }

        clocks[row['nativePeriod'] as int] = [
          minute(row['nativeStart']),
          minute(row['nativeEnd']),
        ];
      }
      expect(clocks, hasLength(12));
      expect(clocks[1], [540, 590]);
      expect(clocks[9], [1020, 1070]);
      final calendar = (proof['academicCalendars'] as List)
          .expand((dynamic x) => x['nativeEvents'] as List)
          .join(' ');
      expect(calendar, contains('12-08 (화) ~ 12-28 (월)'));
      expect(proof['examProof']['nativeText'], contains('2026.12.8.~12.28.'));
      expect(
        proof['examProof']['midtermDatesPublishedInInspectedSources'],
        isFalse,
      );
      expect(
        proof['sourceAccess']['directQueryWithoutAdmissionAttempted'],
        isFalse,
      );
      final closures = (proof['closureNotices'] as List)
          .expand((dynamic x) => x['nativeRows'] as List)
          .toList();
      expect(closures, hasLength(27));
      final courses = <UniversityCourse>[];
      var count = 0;
      for (final campus in ['sujeong', 'unjung']) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'assets/timetable/sungshin-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(raw['researchOnly'], isFalse);
        expect(raw['completionClaim'], isFalse);
        final dataset = UniversityDataset.fromJson(raw);
        expect(dataset.courses, hasLength(campus == 'sujeong' ? 12 : 17));
        for (var i = 0; i < dataset.courses.length; i++) {
          final c = dataset.courses[i];
          final row = (raw['courses'] as List)[i] as Map;
          final original = row['metadata']['originalEducationalRecord'] as Map;
          expect(
            original,
            nativeRows.singleWhere(
              (dynamic x) => x['excelRow'] == original['excelRow'],
            ),
          );
          final n = original['values'] as Map;
          expect(c.code, n['학수번호']);
          expect(c.section, '${n['분반']}');
          expect(c.title, n['교과목명']);
          expect(c.sourceSchedule, n['시간표']);
          expect(
            c.credits,
            double.parse((n['학점/이론/실습'] as String).split('/').first),
          );
          expect(c.sourceClassification, isEmpty);
          expect(c.professor, isEmpty);
          expect(c.sourceClassroom, isEmpty);
          expect(c.campus, campus);
          expect(n['캠퍼스'], campus == 'sujeong' ? '수정' : '운정');
          expect(row['metadata']['sourceNativeLanguage'], n['강의언어']);
          expect(row['metadata']['sourceNativeRestrictions'], n['수강안내 및 지정내용']);
          expect(row['metadata']['eligibilityScope'], '외국인 전용');
          expect(row['metadata']['actualAttendanceConfirmed'], isFalse);
          expect(row['metadata']['currentWholeClosureVerified'], isFalse);
          expect(
            closures.any(
              (dynamic x) =>
                  x[3] == c.code && int.parse(x[4]) == int.parse(c.section),
            ),
            isFalse,
          );
          final nativePeriod = RegExp(
            r'^([월화수목금])/(\d+)-(\d+)$',
          ).firstMatch(n['시간표'])!;
          final col = '월화수목금'.indexOf(nativePeriod[1]!);
          final expected = <String>{};
          for (var index = col; index < dateCells.length; index += 6) {
            final cell = dateCells[index];
            final date = DateTime(
              2026,
              int.parse(cell[1]!),
              int.parse(cell[2]!),
            );
            final day = date.toIso8601String().substring(0, 10);
            if (!date.isBefore(DateTime(2026, 12, 8)) || day == '2026-10-16') {
              continue;
            }
            expect(date.weekday, col + 1);
            for (
              var period = int.parse(nativePeriod[2]!);
              period <= int.parse(nativePeriod[3]!);
              period++
            ) {
              final clock = clocks[period]!;
              expected.add('$day/${date.weekday}/${clock[0]}/${clock[1]}/');
            }
          }
          final actual = <String>{};
          for (final m in c.meetings) {
            count++;
            actual.add(
              '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            );
            expect(DateTime.parse(m.date!).weekday, m.weekday);
          }
          expect(actual, expected);
          expect(actual, hasLength(c.meetings.length));
          expect(c.hasSchedulableMeetings, isTrue);
          expect(
            (row['schedules'] as List).every(
              (dynamic m) => !(m as Map).containsKey('deliveryMode'),
            ),
            isTrue,
          );
          courses.add(c);
        }
      }
      expect(courses, hasLength(29));
      expect(count, 1000);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = courses
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(29));
        final original = {for (final c in before) c.sourceId: c};
        for (final c in restored) {
          final prior = original[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
          expect(c.note, prior.note);
          expect(c.note, contains('외국인 전용'));
          expect(c.note, contains('중간고사 개별 시행 날짜'));
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            prior.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
