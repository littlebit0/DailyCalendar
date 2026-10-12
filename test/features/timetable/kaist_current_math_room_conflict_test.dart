import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const root =
    'work/university-research/catalog-r/kaist/math-room-conflict-own-clock-v7-20261009/';
Map<String, dynamic> read(String name) {
  final path =
      name == 'kaist-main-2026-2.math-room-unconfirmed-own-clock-v7.json'
      ? 'work/university-research/catalog-r/kaist/math-room-conflict-own-clock-v7-20261009/kaist-main-2026-2.math-room-unconfirmed-own-clock-v7.json'
      : '$root$name';
  final data =
      jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
  if (data['courses'] != null) markHistoricalPublication(data);
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

// Independent literal native PDF clocks, rooms and individual section letters. Conflictrooms never usedasattendanceplaces.
const expected =
    <(String, String, String, String, String, String, int, int, String, int)>[
      (
        '480',
        '',
        '수학특강<최적운송, 편미분방정식, 그리고 기계학습>',
        '최범준',
        '창의103',
        'E11 203',
        540,
        615,
        'MW',
        -1,
      ),
      ('212', '', '선형대수학 [kr]', '변재형', '창의103', 'E11 203', 780, 855, 'MW', -1),
      ('102', 'O', '미적분학Ⅱ', '이기선', '창의102', 'E11 202', 780, 855, 'TT', 600),
      ('102', 'P', '미적분학Ⅱ', '이기선', '창의102', 'E11 202', 780, 855, 'TT', 780),
    ];
const mw =
    '2026-08-31 2026-09-02 2026-09-07 2026-09-09 2026-09-14 2026-09-16 2026-09-21 2026-09-23 2026-09-28 2026-09-30 2026-10-07 2026-10-12 2026-10-14 2026-10-26 2026-10-28 2026-11-02 2026-11-04 2026-11-09 2026-11-11 2026-11-16 2026-11-18 2026-11-23 2026-11-25 2026-11-30 2026-12-02 2026-12-07 2026-12-09';
const tt =
    '2026-09-01 2026-09-03 2026-09-08 2026-09-10 2026-09-15 2026-09-17 2026-09-22 2026-09-29 2026-10-01 2026-10-06 2026-10-08 2026-10-13 2026-10-15 2026-10-27 2026-10-29 2026-11-03 2026-11-05 2026-11-10 2026-11-12 2026-11-17 2026-11-19 2026-11-24 2026-11-26 2026-12-01 2026-12-03 2026-12-08 2026-12-10';
const fr =
    '2026-09-04 2026-09-11 2026-10-02 2026-10-16 2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27 2026-12-04 2026-12-11';
void main() {
  test(
    'KAIST source-conflictroom empty attendanceclassroom, exactownHH 4courses, full70 Drive three modes',
    () {
      final raw = read(
        'kaist-main-2026-2.math-room-unconfirmed-own-clock-v7.json',
      );
      final before = read('prior-full-66-course-2036-baseline.json');
      final rows = raw['courses'] as List;
      expect(rows.sublist(0, 66), before['courses']);
      expect(rows, hasLength(70));
      expect(raw['researchOnly'], false);
      expect(raw['completionClaim'], false);
      final proof = read('native-bilingual-room-conflict-own-clock-proof.json');
      expect(
        proof['sourcePDFSHA256'],
        'd158fcd7f42380788e46052d66c7178b1dfd9c618d051477d5fe75f4651c1fc9',
      );
      expect(proof['heldClockConflict491'], {
        'KR': 'MW16:00–17:00explicit',
        'EN': 'MW16:00–17:15grid withoutoverride',
        'decision': 'held unchanged; no partial time guessed',
      });
      final dataset = UniversityDataset.fromJson(raw);
      var added = 0;
      for (var i = 0; i < 4; i++) {
        final e = expected[i];
        final c = dataset.courses[i + 66];
        final row = rows[i + 66] as Map;
        final meta = row['metadata'] as Map;
        final orig = meta['originalEducationalFields'] as Map;
        expect(c.code, e.$1);
        expect(c.section, e.$2);
        expect(c.title, e.$3);
        expect(c.professor, e.$4);
        expect(c.campus, 'main');
        expect(c.hasSchedulableMeetings, true);
        expect(row['credits'], isNull);
        expect(row['classification'], '');
        expect(orig['nativeClassroomKR'], e.$5);
        expect(orig['nativeClassroomEN'], e.$6);
        expect(orig['nativeRoomConflictUnresolved'], true);
        expect(orig['lectureRoomSelected'], false);
        expect(meta['classroomSelectedFromConflictingSources'], false);
        expect(
          meta['lectureClassroomStatus'],
          'bilingual-source-conflict-unconfirmed',
        );
        expect(row['remarks'], contains(e.$5));
        expect(row['remarks'], contains(e.$6));
        final dates = (e.$9 == 'MW' ? mw : tt).split(' ');
        final literal = dates
            .map((d) => '$d|${DateTime.parse(d).weekday}|${e.$7}|${e.$8}|')
            .toSet();
        if (e.$10 >= 0) {
          literal.addAll(
            fr.split(' ').map((d) => '$d|5|${e.$10}|${e.$10 + 60}|'),
          );
          expect(orig['nativeSectionGroup'], 'OP');
          expect(orig['practiceNativeRoom'], '');
          expect(orig['practiceNativeProfessor'], '');
        }
        final actual = c.meetings
            .map(
              (m) =>
                  '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
            )
            .toSet();
        expect(actual, literal);
        expect(c.meetings, hasLength(i < 2 ? 27 : 38));
        expect(c.meetings.every((m) => m.classroom.isEmpty), true);
        added += c.meetings.length;
        expect(meta['actualAttendanceConfirmed'], false);
        expect(meta['currentActiveStatusVerified'], false);
        expect(
          (row['schedules'] as List).every(
            (s) => !(s as Map).containsKey('deliveryMode'),
          ),
          true,
        );
      }
      expect(added, 130);
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        2166,
      );
      expect(dataset.courses.where((c) => c.code == '491'), isEmpty);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = dataset.courses
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
        expect(restored, hasLength(70));
        final by = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final old = by[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, old.title);
          expect(c.professor, old.professor);
          expect(c.note, old.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            old.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
