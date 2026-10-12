import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GNUE current native rows and exact clock blocks retain held scope, grade practice and all modes through full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/gnue/';
      Map<String, dynamic> read(String n) =>
          jsonDecode(fixtureFile('$root$n').readAsStringSync())
              as Map<String, dynamic>;
      final source = read('gnue-current-native-education-source-20261008.json');
      final rows = {
        for (final r in source['educationRows'] as List) r['sourceId']: r,
      };
      final dataset = UniversityDataset.fromJson(
        read('gnue-unknown-2026-2.native251-partial-v1.json'),
      );
      final all = dataset.courses;
      expect(all, hasLength(251));
      expect(all.map((c) => c.sourceId).toSet(), hasLength(251));
      expect(all.fold<int>(0, (n, c) => n + c.meetings.length), 1399);
      expect(source['liveFileBytesMatched'], true);
      final scheduled = all.where((c) => c.meetings.isNotEmpty).toList();
      expect(scheduled, hasLength(118));
      expect(all.where((c) => c.meetings.isEmpty), hasLength(133));
      for (final c in all) {
        final r = rows[c.sourceId];
        expect(r, isNotNull);
        expect(c.code, isEmpty);
        expect(c.section, isEmpty);
        expect(c.campus, 'unknown');
        expect(c.title, r['courseName']);
        expect(c.professor, r['professor']);
        expect(c.credits, r['sourceCredits']);
        expect(c.sourceClassroom, r['sourceClassroom']);
        expect(c.departments, [r['nativeStudentGroup']]);
        if (r['status'] == 'held') {
          expect(c.meetings, isEmpty);
          expect(c.sourceClassification, r['nativeProcess']);
          for (final comment in r['nativeEducationalRoomComments'] as List) {
            expect(
              c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).note,
              contains(comment['text']),
            );
          }
        } else {
          expect(c.sourceClassification, isEmpty);
          final clocks = r['clockRows'] as List;
          expect(
            c.sourceSchedule,
            '${'월화수목금'[(r['weekday'] as int) - 1]} ${clocks.first['start']}~${clocks.last['end']}',
          );
          for (final m in c.meetings) {
            expect(m.originalStartMinute, r['startMinute']);
            expect(m.originalEndMinute, r['endMinute']);
            expect(
              m.originalEndMinute - m.originalStartMinute,
              clocks.length * 60 - 10,
            );
            expect(DateTime.parse(m.date!).weekday, r['weekday']);
            expect(m.classroom, r['sourceClassroom']);
            expect(
              m.date!.compareTo('2026-09-01') >= 0 &&
                  m.date!.compareTo('2026-12-07') <= 0,
              true,
            );
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));
            if (r['grade'] == 3) {
              expect(
                m.date!.compareTo('2026-10-19') < 0 ||
                    m.date!.compareTo('2026-10-30') > 0,
                true,
              );
            }
          }
        }
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = scheduled
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
        expect(restored, hasLength(118));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(c.note, contains('내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다'));
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
