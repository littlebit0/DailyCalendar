import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GJUE native undergraduate blocks preserve published clocks and practice exceptions in all modes and full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/gjue/';
      Map<String, dynamic> read(String name) =>
          jsonDecode(File('$root$name').readAsStringSync())
              as Map<String, dynamic>;
      final source = read('gjue-current-unambiguous-source-20261008.json');
      final rows = {
        for (final r in source['educationRows'] as List) r['sourceId']: r,
      };
      final dataset = UniversityDataset.fromJson(
        read('gjue-unknown-2026-2.public-blocks-partial-v1.json'),
      );
      final all = dataset.courses;
      expect(all, hasLength(464));
      expect(all.map((c) => c.sourceId).toSet(), hasLength(464));
      expect(all.fold<int>(0, (n, c) => n + c.meetings.length), 5721);
      expect(source['liveCurrentFileMatched'], true);
      expect(source['unambiguousPeriodSlots'], 870);
      expect(source['omittedMixedBlocks'], hasLength(23));
      expect(source['heldEducationalBlocks'], hasLength(6));
      for (final c in all) {
        final r = rows[c.sourceId];
        expect(r, isNotNull);
        expect(c.code, isEmpty);
        expect(c.section, isEmpty);
        expect(c.credits, isNull);
        expect(c.sourceClassification, isEmpty);
        expect(c.campus, 'unknown');
        expect(c.title, r['courseName']);
        expect(c.professor, r['professor']);
        expect(c.sourceClassroom, r['classroom']);
        expect(c.departments, [r['studentGroup']]);
        expect(c.sourceId, endsWith('&cell=${r['cell']}'));
        for (final comment in r['nativeEducationalComments'] as List) {
          expect(
            c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).note,
            contains(comment['text']),
          );
        }
        final slots = r['sourceSlotRows'] as List;
        expect(
          c.sourceSchedule,
          '${'월화수목금'[(r['weekday'] as int) - 1]} ${slots.first['start']}~${slots.last['end']}',
        );
        for (final m in c.meetings) {
          expect(m.originalStartMinute, r['startMinute']);
          expect(m.originalEndMinute, r['endMinute']);
          expect(
            m.originalEndMinute - m.originalStartMinute,
            slots.length * 60 - 10,
          );
          expect(m.weekday, r['weekday']);
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(m.classroom, r['classroom']);
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
                  m.date!.compareTo('2026-11-13') > 0,
              true,
            );
          }
        }
      }
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
        expect(restored, hasLength(464));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.note, contains('내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다'));
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(c.note, contains('최신 강좌별 폐강 대조 미완료'));
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
