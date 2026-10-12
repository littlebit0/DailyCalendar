import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'SYU current native 1391 retains source cells, holds closures and uses chapel-only exact dates and clocks in all modes and Drive',
    () {
      const root = 'work/university-research/catalog-f/syu/';
      Map<String, dynamic> read(String name) =>
          jsonDecode(fixtureFile('$root$name').readAsStringSync())
              as Map<String, dynamic>;
      final raw = read('syu-main-2026-2.native1391-chapel-partial-v1.json');
      final dataset = UniversityDataset.fromJson(raw);
      final originalRows =
          jsonDecode(
                fixtureFile(
                  'work/university-research/catalog-l/syu-2026-2-public-all-rows.json',
                ).readAsStringSync(),
              )
              as List;
      final lookup = {for (final row in originalRows) row[0]: row};
      final rawLookup = {
        for (final row in raw['courses'] as List) row['sourceId']: row,
      };
      final closure = read('syu-current-cumulative-closure-20261008.json');
      final closed = (closure['unionNativeClosedIds'] as List).toSet();
      final program = read('syu-current-chapel-program-20261008.json');
      final clock = read('syu-current-chapel-clock-20261008.json');
      final calendar = read('syu-current-calendar-20261008.json');
      expect(dataset.courses, hasLength(1391));
      expect(dataset.courses.map((c) => c.sourceId).toSet(), hasLength(1391));
      expect(dataset.courses.map((c) => c.code).toSet(), hasLength(772));
      expect(closed, hasLength(106));
      expect(program['sourceProgram'], hasLength(15));
      expect(clock['scope'], startsWith('CHAPEL ONLY'));
      expect(clock['pageId'], 'page-c2eb-c1ae');
      expect(calendar['startDate'], '2026-09-01');
      expect(calendar['finalExamEndDate'], '2026-12-14');
      expect(calendar['termEndDateIndividuallyPublished'], false);
      final plans = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(plans, hasLength(38));
      expect(plans.fold<int>(0, (n, c) => n + c.meetings.length), 266);
      const mon = [
        '2026-09-14',
        '2026-09-21',
        '2026-09-28',
        '2026-10-12',
        '2026-11-09',
        '2026-11-16',
        '2026-11-30',
      ];
      const wed = [
        '2026-09-09',
        '2026-09-16',
        '2026-09-23',
        '2026-09-30',
        '2026-11-04',
        '2026-11-11',
        '2026-11-25',
      ];
      for (final c in dataset.courses) {
        final id = c.sourceId.split('/').last;
        final original = lookup[id] as List;
        final native =
            rawLookup[c.sourceId]['sourceEducation']['nativePublicCells']
                as List;
        final omissions =
            rawLookup[c
                    .sourceId]['sourceEducation']['contactCellIndexesOmitted']
                as List;
        expect(c.sourceId, 'syu/main/2026-2/$id');
        expect(c.code, original[4]);
        expect(c.title, original[5]);
        expect(c.section, isEmpty);
        expect(c.professor, original[10] ?? '');
        expect(c.sourceSchedule, original[11] ?? '');
        expect(c.sourceClassroom, original[12] ?? '');
        expect(c.sourceClassification, original[6]);
        expect(c.departments, [original[1]]);
        for (var i = 0; i < 16; i++) {
          if (!omissions.contains(i)) expect(native[i], original[i] ?? '');
        }
        final parsed = double.tryParse(original[8] ?? '');
        expect(c.credits, parsed);
        if (closed.contains(id)) expect(c.meetings, isEmpty);
        if (c.meetings.isEmpty) continue;
        expect(c.title, '채플');
        expect(c.code, '1004903');
        expect(c.sourceClassroom, '대강당(메인)');
        expect(original[14] ?? '', isEmpty);
        expect(original[13], 'N');
        for (final excluded
            in program['excludedSeparateDepartmentChapelTerms'] as List) {
          expect(c.departments.single, isNot(contains(excluded)));
        }
        final isMonday = c.sourceSchedule == '월3';
        expect(c.meetings.map((m) => m.date).toList(), isMonday ? mon : wed);
        for (final m in c.meetings) {
          expect(m.weekday, isMonday ? 1 : 3);
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(m.originalStartMinute, isMonday ? 660 : 600);
          expect(m.originalEndMinute, isMonday ? 710 : 650);
          expect(m.classroom, '대강당(메인)');
        }
      }
      expect(
        dataset.courses
            .singleWhere((c) => c.sourceId.endsWith('/886'))
            .meetings,
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
        expect(restored, hasLength(38));
        final originalsLookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          final original = originalsLookup[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.note, contains('공개 날짜별 예약 계획, 실제 운영/출석 미확인'));
          expect(c.note, contains('온라인/e-Class 주차'));
          expect(c.toJson()..remove('id'), original.toJson()..remove('id'));
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
