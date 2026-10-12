import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const root =
    'work/university-research/catalog-r/kaist/math-joint-section-public-offering-v6-20261009/';
Map<String, dynamic> read(String name) {
  final path = name == 'kaist-main-2026-2.math-joint-ug-planned-v6.json'
      ? 'assets/timetable/kaist-main-2026-2.json'
      : '$root$name';
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

// Independently transcribed from literal original bilingual PDF cells, not generated candidate expectations.
const groups =
    <(String, String, String, String, String, int, int, String, int, int)>[
      ('101', 'AB', '미적분학 I', '응우옌', '창의304', 540, 615, 'TT', 600, 780),
      ('102', 'AB', '미적분학Ⅱ', '김용정', '창의311', 540, 615, 'TT', 600, 780),
      ('102', 'MN', '미적분학Ⅱ', '황강욱', '창의401', 540, 615, 'TT', 600, 780),
      ('102', 'KL', '미적분학Ⅱ', '임미경', '창의412', 540, 615, 'TT', 600, 780),
      ('102', 'CD', '미적분학Ⅱ', '김동한', '창의304', 780, 855, 'TT', 600, 780),
      ('102', 'EF', '미적분학Ⅱ', '김완수', '창의311', 780, 855, 'TT', 600, 780),
      ('102', 'IJ', '미적분학Ⅱ', '백상훈', '창의402', 780, 855, 'TT', 600, 780),
      ('102', 'GH', '미적분학Ⅱ', '박지원', '창의412', 780, 855, 'TT', 600, 780),
      ('109', 'CD', '선형대수학개론', '이민주', '창의304', 540, 615, 'MW', 660, 840),
      ('109', 'AB', '선형대수학개론', '박진현', '창의304', 870, 945, 'MW', 660, 840),
      ('109', 'EF', '선형대수학개론 [kr]', '한상근', '창의304', 870, 945, 'TT', -1, -1),
      (
        '110',
        'AB',
        '데이터과학을 위한 선형대수학',
        '하우석',
        '창의410',
        870,
        945,
        'MW',
        660,
        840,
      ),
      ('201', 'AB', '응용미분방정식', '김동환', '창의412', 630, 705, 'MW', 660, 840),
      ('201', 'CD', '응용미분방정식', '한재호', '창의412', 870, 945, 'TT', 660, 840),
      ('202', 'AB', '응용해석학', '남경식', '창의301', 630, 705, 'TT', -1, -1),
    ];
const mw =
    '2026-08-31 2026-09-02 2026-09-07 2026-09-09 2026-09-14 2026-09-16 2026-09-21 2026-09-23 2026-09-28 2026-09-30 2026-10-07 2026-10-12 2026-10-14 2026-10-26 2026-10-28 2026-11-02 2026-11-04 2026-11-09 2026-11-11 2026-11-16 2026-11-18 2026-11-23 2026-11-25 2026-11-30 2026-12-02 2026-12-07 2026-12-09';
const tt =
    '2026-09-01 2026-09-03 2026-09-08 2026-09-10 2026-09-15 2026-09-17 2026-09-22 2026-09-29 2026-10-01 2026-10-06 2026-10-08 2026-10-13 2026-10-15 2026-10-27 2026-10-29 2026-11-03 2026-11-05 2026-11-10 2026-11-12 2026-11-17 2026-11-19 2026-11-24 2026-11-26 2026-12-01 2026-12-03 2026-12-08 2026-12-10';
const friday =
    '2026-09-04 2026-09-11 2026-10-02 2026-10-16 2026-10-30 2026-11-06 2026-11-13 2026-11-20 2026-11-27 2026-12-04 2026-12-11';
void main() {
  test(
    'KAIST own math joint native section lecture+blankroom recitation scope, prior36, allthree Drive modes',
    () {
      final raw = read('kaist-main-2026-2.math-joint-ug-planned-v6.json');
      final prior = read('prior-full-36-course-v5-baseline.json');
      final rows = raw['courses'] as List;
      expect(rows.sublist(0, 36), prior['courses']);
      expect(rows, hasLength(70));
      expect(raw['researchOnly'], false);
      expect(raw['completionClaim'], false);
      final proof = read('joint-native-whole-operating-proof.json');
      expect(
        proof['sourcePDFSHA256'],
        'd158fcd7f42380788e46052d66c7178b1dfd9c618d051477d5fe75f4651c1fc9',
      );
      expect(proof['completeBilingualSourceText'], contains('102ACEGIKMO'));
      expect(proof['completeBilingualSourceText'], contains('109ACE'));
      expect(proof['completeBilingualSourceText'], contains('109AC Intro.'));
      final calendar = read('reused-own-current-calendar-proof.json');
      expect(
        calendar['nativeEducationalRows'],
        contains('09-18(금) ~ 09-19(토) 제23회 KAIST-POSTECH 학생대제전 (연습반 휴강)'),
      );
      final dataset = UniversityDataset.fromJson(raw);
      var i = 36;
      var added = 0;
      for (final g in groups) {
        for (var j = 0; j < 2; j++) {
          final course = dataset.courses[i];
          final row = rows[i] as Map;
          final section = g.$2[j];
          i++;
          expect(course.code, g.$1);
          expect(course.section, section);
          expect(course.title, g.$3);
          expect(course.professor, g.$4);
          expect(course.campus, 'main');
          expect(course.hasSchedulableMeetings, true);
          expect(row['credits'], isNull);
          expect(row['classification'], '');
          final meta = row['metadata'] as Map;
          final orig = meta['originalEducationalFields'] as Map;
          expect(orig['nativeSectionGroup'], g.$2);
          expect(orig['nativeIndividualSection'], section);
          expect(orig['practiceNativeRoom'], '');
          expect(orig['practiceNativeProfessor'], '');
          expect(meta['practiceRoomNotBorrowedFromLecture'], true);
          final expected = (g.$8 == 'MW' ? mw : tt)
              .split(' ')
              .map(
                (date) =>
                    '$date|${DateTime.parse(date).weekday}|${g.$6}|${g.$7}|${g.$5}',
              )
              .toSet();
          final ps = j == 0 ? g.$9 : g.$10;
          if (ps >= 0) {
            expected.addAll(
              friday.split(' ').map((date) => '$date|5|$ps|${ps + 60}|'),
            );
          }
          final actual = course.meetings
              .map(
                (m) =>
                    '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
              )
              .toSet();
          expect(actual, expected);
          expect(course.meetings, hasLength(ps < 0 ? 27 : 38));
          added += course.meetings.length;
          expect(
            course.meetings.any(
              (m) => m.weekday == 5 && m.date == '2026-09-18',
            ),
            false,
          );
          if (g.$1 == '109' && g.$2 == 'EF') {
            expect(meta['practiceOperatingStatus'], 'bilingual-conflict-held');
            expect(meta['partialOperatingComponentsHeld'], true);
          }
          if (g.$1 == '202') {
            expect(meta['practiceOperatingStatus'], 'unpublished');
          }
          expect(
            (row['schedules'] as List).every(
              (m) => !(m as Map).containsKey('deliveryMode'),
            ),
            true,
          );
        }
      }
      expect(i, 66);
      expect(added, 1096);
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        2166,
      );
      expect(
        dataset.courses.take(66).where(
          (c) => c.code == '102' && (c.section == 'O' || c.section == 'P'),
        ),
        isEmpty,
      );
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
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final old = before[c.sourceId]!;
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
