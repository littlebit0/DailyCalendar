import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BNUE current published blocks preserve exact clocks, native unassigned staff labels, grade practice and all modes through full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/bnue/';
      Map<String, dynamic> read(String n) =>
          jsonDecode(
                File(
                  n == 'bnue-unknown-2026-2.native305-partial-v1.json'
                      ? 'assets/timetable/bnue-unknown-2026-2.json'
                      : '$root$n',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final source = read('bnue-current-native305-source-20261008.json');
      final rows = {
        for (final r in source['educationRows'] as List) r['sourceId']: r,
      };
      final dataset = UniversityDataset.fromJson(
        read('bnue-unknown-2026-2.native305-partial-v1.json'),
      );
      final all = dataset.courses;
      final scheduled = all.where((c) => c.meetings.isNotEmpty).toList();
      expect(all, hasLength(305));
      expect(scheduled, hasLength(305));
      expect(all.where((c) => c.meetings.isEmpty), isEmpty);
      expect(all.map((c) => c.sourceId).toSet(), hasLength(305));
      expect(all.fold<int>(0, (n, c) => n + c.meetings.length), 3577);
      expect(source['liveFileBytesMatched'], true);
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
        if (r['professorUnassignedNativeLabel'] == true) {
          expect(c.meetings, isNotEmpty);
          expect(c.professor, isIn(['신규', '신규교수', '신규강사']));
        }
        for (final m in c.meetings) {
          expect(m.originalStartMinute, r['startMinute']);
          expect(m.originalEndMinute, r['endMinute']);
          expect(
            m.originalEndMinute - m.originalStartMinute,
            ((r['lastPeriod'] as int) - (r['firstPeriod'] as int) + 1) * 60 -
                10,
          );
          expect(DateTime.parse(m.date!).weekday, r['weekday']);
          expect(m.classroom, r['classroom']);
          expect(
            m.date!.compareTo('2026-09-01') >= 0 &&
                m.date!.compareTo('2026-12-07') <= 0,
            true,
          );
          expect([
            '2026-09-02',
            '2026-09-24',
            '2026-09-25',
            '2026-10-05',
            '2026-10-09',
          ], isNot(contains(m.date)));
          if (r['grade'] == 2) {
            expect(
              m.date!.compareTo('2026-10-12') < 0 ||
                  m.date!.compareTo('2026-10-23') > 0,
              true,
            );
          }
          if (r['grade'] == 3) {
            expect(
              m.date!.compareTo('2026-11-02') < 0 ||
                  m.date!.compareTo('2026-11-13') > 0,
              true,
            );
          }
        }
        for (final comment in r['nativeEducationalComments'] as List) {
          expect(
            c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).note,
            contains(comment['text']),
          );
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
        expect(restored, hasLength(305));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(c.note, contains('내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다'));
          expect(c.note, contains('전체 강좌 폐강 대조 미완료'));
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
