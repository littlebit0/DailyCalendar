import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const root =
    'work/university-research/catalog-r/kaist/public-individual-course-v3-20261009/';
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'Current public EE415 26 and CS330 Wednesday14, old12/306 deep and three-mode full Drive',
    () {
      final old = read(
        'work/university-research/catalog-r/kaist/nqe-current-ug-v2-20261009/kaist-main-2026-2.nqe-ug-planned-v2.json',
      );
      final raw = read(
        'work/university-research/catalog-r/kaist/math-room-conflict-own-clock-v7-20261009/kaist-main-2026-2.math-room-unconfirmed-own-clock-v7.json',
      );
      markHistoricalPublication(raw);
      for (final c in old['courses']) {
        if (c['metadata']?.containsKey('researchOnly') == true) {
          c['metadata']['researchOnly'] = false;
        }
      }
      final proof = read('${root}individual-course-education-proof.json');
      final rows = raw['courses'] as List;
      expect(rows.take(12).toList(), old['courses']);
      expect(rows, hasLength(70));
      expect(raw['researchOnly'], false);
      expect(raw['completionClaim'], false);
      final dataset = UniversityDataset.fromJson(raw);
      expect(
        dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length),
        2166,
      );
      final ee = dataset.courses[12];
      final cs = dataset.courses[13];
      expect(ee.code, 'EE415');
      expect(cs.code, 'CS330');
      expect(ee.professor, 'Youjip Won');
      expect(cs.professor, 'Youngjin Kwon');
      expect(ee.section, isEmpty);
      expect(cs.section, isEmpty);
      expect(ee.sourceClassification, isEmpty);
      expect(cs.sourceClassification, isEmpty);
      expect(ee.credits, isNull);
      expect(cs.credits, isNull);
      final expectedEe = <String>{
        '2026-09-02',
        '2026-09-07',
        '2026-09-09',
        '2026-09-14',
        '2026-09-16',
        '2026-09-21',
        '2026-09-23',
        '2026-09-28',
        '2026-09-30',
        '2026-10-07',
        '2026-10-12',
        '2026-10-14',
        '2026-10-26',
        '2026-10-28',
        '2026-11-02',
        '2026-11-04',
        '2026-11-09',
        '2026-11-11',
        '2026-11-16',
        '2026-11-18',
        '2026-11-23',
        '2026-11-25',
        '2026-11-30',
        '2026-12-02',
        '2026-12-07',
        '2026-12-09',
      };
      final expectedCs = <String>{
        '2026-09-02',
        '2026-09-09',
        '2026-09-16',
        '2026-09-23',
        '2026-09-30',
        '2026-10-07',
        '2026-10-14',
        '2026-10-28',
        '2026-11-04',
        '2026-11-11',
        '2026-11-18',
        '2026-11-25',
        '2026-12-02',
        '2026-12-09',
      };
      expect(ee.meetings.map((m) => m.date).toSet(), expectedEe);
      expect(cs.meetings.map((m) => m.date).toSet(), expectedCs);
      expect(ee.meetings, hasLength(26));
      expect(cs.meetings, hasLength(14));
      final eeSource = (proof['courses'] as List)[0] as Map;
      final csSource = (proof['courses'] as List)[1] as Map;
      expect(eeSource['nativeTerm'], '2026 FALL');
      expect(eeSource['nativeClockRoom'], 'Mon/Wed 14:30 – 16:00, N1-111');
      expect(csSource['nativeClock'], 'Mon&Wed 1:00pm - 2:30pm');
      expect(csSource['nativeLocation'], 'Mon (online), Wed (E3-1, 1501)');
      expect(
        (proof['undergraduateScope']
            as Map)['officialCurrentOfferingAliasJoinVerified'],
        false,
      );
      expect(
        (proof['teacherTerm'] as Map)['publishedLink'],
        'https://sites.google.com/view/cs330',
      );
      expect(
        (proof['publisherAffiliation'] as Map)['publishedLinks'],
        contains('https://sites.google.com/view/yjkwon/home'),
      );
      final nativeRows = eeSource['nativeDatedRows'] as List;
      expect(nativeRows, hasLength(28));
      expect(
        nativeRows
            .where(
              (dynamic r) =>
                  (r as Map)['nativeOperation'] == 'published tentative class',
            )
            .map((dynamic r) => (r as Map)['date'])
            .toSet(),
        expectedEe,
      );
      expect(
        (eeSource['nativeExamRows'] as List).every(
          (dynamic r) => (r as Map)['classroom'] == null,
        ),
        true,
      );
      for (final m in ee.meetings) {
        expect(m.classroom, 'N1-111');
        expect(m.originalStartMinute, 870);
        expect(m.originalEndMinute, 960);
        expect(m.weekday, DateTime.parse(m.date!).weekday);
        expect(m.weekday, anyOf(1, 3));
      }
      for (final m in cs.meetings) {
        expect(m.classroom, 'E3-1, 1501');
        expect(m.originalStartMinute, 780);
        expect(m.originalEndMinute, 870);
        expect(m.weekday, 3);
      }
      for (final row in rows.skip(12).take(2).cast<Map>()) {
        final meta = row['metadata'] as Map;
        expect(meta['referenceKind'], 'published legacy course reference');
        expect(meta['canonicalCodeAliasJoinVerified'], false);
        expect(meta['nativeSection'], isNull);
        expect(meta['publishedEnrollmentNumber'], isNull);
        expect(meta['currentActiveStatusVerified'], false);
        expect(meta['actualAttendanceConfirmed'], false);
        expect(
          (row['schedules'] as List).every(
            (dynamic m) => !(m as Map).containsKey('deliveryMode'),
          ),
          true,
        );
      }
      final held =
          read('${root}followup-held-education.json')['entries'] as List;
      expect((held[0] as Map)['nativeTerm'], '2026 Fall');
      expect((held[0] as Map)['nativeCode'], 'CS.10001');
      expect((held[1] as Map)['currentYearExplicitlyVerified'], false);
      expect(
        dataset.courses.any((c) => c.code == 'CS.10001' || c.code == 'EE209'),
        false,
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
        expect(restored.fold<int>(0, (n, c) => n + c.meetings.length), 2166);
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
          expect(c.note, prior.note);
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
