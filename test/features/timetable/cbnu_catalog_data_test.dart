import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CBNU frozen prior11 published reservations retain closure and unknown modes',
    () {
      const root = 'work/university-research/catalog-f/cbnu/';
      final raw =
          jsonDecode(
                fixtureFile(
                  'work/university-research/catalog-f/cbnu/current-whole-public-path-and-politics-partial-v3-20261009/prior11-current-asset-snapshot.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final dataset = UniversityDataset.fromJson(raw);
      expect(dataset.courses, hasLength(11));
      expect(raw['institutionId'], 'institution:academyinfo:0000030');
      expect(raw['wholeSchoolCourseCoverageComplete'], isFalse);
      expect(raw['completionClaim'], isFalse);
      expect(raw['campusName'], '본교');
      expect(
        dataset.courses.any((c) => c.code == '0912002' && c.section == '10'),
        isFalse,
      );
      final prior = UniversityDataset.fromJson(
        jsonDecode(
              fixtureFile(
                '${root}cbnu-main-2026-2.korean-track-partial-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      for (final c in prior.courses) {
        final next = dataset.courses.singleWhere(
          (n) => n.sourceId == c.sourceId,
        );
        expect(
          next.meetings.map((m) => m.toJson()).toList(),
          c.meetings.map((m) => m.toJson()).toList(),
        );
      }
      expect(dataset.courses.map((c) => '${c.code}-${c.section}').toSet(), {
        '0932009-01',
        '0914002-19',
        '0923050-01',
        '0912002-04',
        '0922075-01',
        '0932010-02',
        '0921037-01',
        '0922006-01',
        '0934004-03',
        '5665084-01',
        '0914009-01',
      });
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        435,
      );
      final expectedDates = {
        '0932009-01': 14,
        '0914002-19': 14,
        '0923050-01': 12,
        '0912002-04': 12,
        '0922075-01': 14,
        '0932010-02': 12,
        '0921037-01': 14,
        '0922006-01': 14,
        '0934004-03': 14,
        '5665084-01': 13,
        '0914009-01': 12,
      };
      for (final c in dataset.courses) {
        final key = '${c.code}-${c.section}';
        expect(c.credits, isNull);
        expect(c.departmentCredits, isEmpty);
        expect(
          c.meetings.map((m) => m.date).toSet(),
          hasLength(expectedDates[key]!),
        );
        for (final m in c.meetings) {
          expect(m.originalEndMinute - m.originalStartMinute, 50);
          expect(m.originalStartMinute % 60, 0);
          expect(m.originalEndMinute % 60, 50);
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(m.date!.compareTo('2026-09-01') >= 0, isTrue);
          expect(m.date!.compareTo('2026-12-06') <= 0, isTrue);
          expect({
            '2026-09-24',
            '2026-09-25',
            '2026-09-26',
            '2026-09-27',
            '2026-10-03',
            '2026-10-05',
            '2026-10-09',
          }, isNot(contains(m.date)));
        }
        final grouped = <String, List<ClassMeeting>>{};
        for (final m in c.meetings) {
          (grouped[m.date!] ??= []).add(m);
        }
        for (final sameDate in grouped.values) {
          expect(sameDate, hasLength(3));
          expect(
            sameDate[1].originalStartMinute - sameDate[0].originalEndMinute,
            10,
          );
          expect(
            sameDate[2].originalStartMinute - sameDate[1].originalEndMinute,
            10,
          );
        }
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = dataset.courses
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
        expect(restored, hasLength(11));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          final original = lookup[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.note, original.note);
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(
            c.note,
            contains(
              c.sourceId!.endsWith('/0921037-01') ||
                      c.sourceId!.endsWith('/0922006-01') ||
                      c.sourceId!.endsWith('/0934004-03') ||
                      c.sourceId!.endsWith('/5665084-01') ||
                      c.sourceId!.endsWith('/0914009-01')
                  ? '행정학과 1학년'
                  : '한국어트랙 가반',
            ),
          );
          expect(c.note, contains('12월 7~18일'));
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
