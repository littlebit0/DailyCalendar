import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const root =
    'work/university-research/catalog-r/kaist/bioeng-current-public-grid-v4-20261009/';
Map<String, dynamic> read(String name) =>
    jsonDecode(File('$root$name').readAsStringSync()) as Map<String, dynamic>;
// Independently transcribed from actual original JPG, not candidate-produced expectations.
const expected = <(String, String, String, String, String, int, int, String)>[
  (
    'BiS.43008',
    '',
    'Bioinformatics (바이오정보학)',
    'Kim, Dongsup',
    'CMS205',
    540,
    630,
    'MW',
  ),
  (
    'BiS.45002',
    '',
    'Biomedical Imaging (바이오 의료영상)',
    'Park, Sung-Hong',
    'CMS205',
    540,
    630,
    'TT',
  ),
  (
    'BiS.42010',
    '',
    'Cognitive Neuroscience (인지신경과학)',
    'Chung, Ain',
    'CMS219',
    630,
    720,
    'TT',
  ),
  (
    'BiS.49900',
    'A',
    'Special Topics (바이오및뇌공학특론) - Principles of Biomedical Optics (의생명광학원리) -',
    'Jang, Mooseok',
    'CMS215',
    630,
    720,
    'MW',
  ),
  (
    'BiS.49900',
    'B',
    'Special Topics (바이오및뇌공학특론) - AI Models of the Brain (인공지능 뇌 모델) -',
    'Kang, Yul HR',
    'CMS207',
    780,
    870,
    'MW',
  ),
  (
    'BiS.37001',
    '',
    'Biofluidics (바이오유체공학)',
    'Shin, Woojoung',
    'CMS207',
    780,
    870,
    'TT',
  ),
  (
    'BiS.22002',
    '',
    'Molecular and Cellular Biology (분자세포 생물학)',
    'Lee, Hyeseon',
    'YBS207',
    870,
    960,
    'MW',
  ),
  (
    'BiS.35002',
    '',
    'System Modeling in Bioengineering (바이오공학의 시스템 모델링)',
    'Cho, Kwang-Hyun',
    'CMS220',
    870,
    960,
    'MW',
  ),
  (
    'BiS.25002',
    '',
    'Bioinstrumentation Fundamentals (바이오 계측기초)',
    'Nam, Yoonkey',
    'YBS207',
    870,
    960,
    'TT',
  ),
];
// Own-calendar-derived ordinary reservations; NOT individually published attendance dates.
const mw =
    '2026-08-31 2026-09-02 2026-09-07 2026-09-09 2026-09-14 2026-09-16 2026-09-21 2026-09-23 2026-09-28 2026-09-30 2026-10-07 2026-10-12 2026-10-14 2026-10-26 2026-10-28 2026-11-02 2026-11-04 2026-11-09 2026-11-11 2026-11-16 2026-11-18 2026-11-23 2026-11-25 2026-11-30 2026-12-02 2026-12-07 2026-12-09';
const tt =
    '2026-09-01 2026-09-03 2026-09-08 2026-09-10 2026-09-15 2026-09-17 2026-09-22 2026-09-29 2026-10-01 2026-10-06 2026-10-08 2026-10-13 2026-10-15 2026-10-27 2026-10-29 2026-11-03 2026-11-05 2026-11-10 2026-11-12 2026-11-17 2026-11-19 2026-11-24 2026-11-26 2026-12-01 2026-12-03 2026-12-08 2026-12-10';
void main() {
  test(
    'KAIST actual mixed Bio grid, exact UG9, prior14 preservation and three-mode full Drive roundtrip',
    () {
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/kaist-main-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final prior = read('prior-full-14-course-baseline.json');
      final rows = raw['courses'] as List;
      expect(rows.sublist(0, 14), prior['courses']);
      expect(rows, hasLength(70));
      expect(raw['researchOnly'], false);
      expect(raw['completionClaim'], false);
      final source = read('manual-grid-and-exact-ug-scope-proof.json');
      expect(
        source['sourceImageSHA256'],
        '0234680105b7a41b15ff6f8ea89843e69e51180c58227ae0fb15677595ac88a5',
      );
      final ugHtml = File(
        '${root}actual-undergraduate-course-reference.html',
      ).readAsStringSync();
      final graduate = source['excludedExactGraduateCodes'] as Map;
      expect(graduate.containsKey('BiS.89901'), true);
      final calendar = read('reused-own-current-calendar-proof.json');
      expect((calendar['reservationWindow'] as Map)['startDate'], '2026-08-31');
      expect((calendar['reservationWindow'] as Map)['endDate'], '2026-12-13');
      expect(calendar['excludedAssessmentWindows'], [
        ['2026-10-19', '2026-10-23'],
        ['2026-12-14', '2026-12-18'],
      ]);
      expect(
        File('${root}actual-notice.html').readAsStringSync(),
        contains('대학로 291'),
      );
      final dataset = UniversityDataset.fromJson(raw);
      var added = 0;
      for (var i = 0; i < expected.length; i++) {
        final e = expected[i];
        final course = dataset.courses[i + 14];
        final row = rows[i + 14] as Map;
        expect(course.code, e.$1);
        expect(course.section, e.$2);
        expect(course.title, e.$3);
        expect(course.professor, e.$4);
        expect(course.campus, 'main');
        expect(course.hasSchedulableMeetings, true);
        expect(ugHtml, contains(e.$1));
        expect(graduate.containsKey(e.$1), false);
        expect(row['credits'], isNull);
        expect(row['departmentCredits'], isEmpty);
        final original =
            (row['metadata'] as Map)['originalEducationalFields'] as Map;
        expect(original['sourceHeaderOrder'], ['Mon', 'Wed', 'Tue', 'Thu']);
        expect(original['nativeClassroom'], e.$5);
        expect(original['nativeSection'], e.$2);
        final dates = (e.$8 == 'MW' ? mw : tt).split(' ');
        final independent = dates
            .map(
              (date) =>
                  '$date|${DateTime.parse(date).weekday}|${e.$6}|${e.$7}|${e.$5}',
            )
            .toSet();
        final actual = course.meetings
            .map(
              (m) =>
                  '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
            )
            .toSet();
        expect(actual, independent);
        expect(course.meetings, hasLength(27));
        added += course.meetings.length;
        expect(
          (row['schedules'] as List).every(
            (m) => !(m as Map).containsKey('deliveryMode'),
          ),
          true,
        );
        expect((row['metadata'] as Map)['actualAttendanceConfirmed'], false);
        expect((row['metadata'] as Map)['currentActiveStatusVerified'], false);
      }
      expect(added, 243);
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        2166,
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
          final orig = before[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, orig.title);
          expect(c.professor, orig.professor);
          expect(c.note, orig.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            orig.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
