import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'KAU historical v1 undergraduate native identities and partial clocks preserve all modes and full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/kau/';
      Map<String, dynamic> read(String name) =>
          jsonDecode(fixtureFile('$root$name').readAsStringSync())
              as Map<String, dynamic>;
      final raw = read('kau-main-2026-2.public83-partial-v1.json');
      final dataset = UniversityDataset.fromJson(raw);
      final receipts = [
        read('kau-current-ta-undergraduate-education-20261008.json'),
        read('kau-current-electronics-education-20261008.json'),
        read('kau-current-sw-later-clock-20261008.json'),
        read('kau-current-predicted-closure-education-20261008.json'),
      ];
      final source = <String, Map<dynamic, dynamic>>{};
      for (final receipt in receipts) {
        expect(receipt['staffNumbersSaved'], false);
        expect(receipt['enrollmentCountsSaved'], false);
        for (final r in receipt['educationRows'] as List) {
          final id = r['nativeLectureNumber'] as String;
          source[id] = {...?source[id], ...r as Map};
        }
      }
      final closed = read('kau-current-final-closure-boundary-20261008.json');
      expect(closed['normalEmbeddedImageRequestStatus'], 403);
      expect(closed['nativeFinalClosedIdsVerified'], false);
      final cal = read('kau-current-calendar-20261008.json');
      expect(cal['startDate'], '2026-09-01');
      expect(cal['finalExamStartDate'], '2026-12-08');
      expect(cal['makeupEndDate'], '2026-12-21');
      expect(cal['midtermDatesIndividuallyPublished'], false);
      expect(dataset.courses, hasLength(83));
      expect(dataset.courses.map((c) => c.sourceId).toSet(), hasLength(83));
      final native = {for (final c in raw['courses'] as List) c['sourceId']: c};
      final plans = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(plans, hasLength(22));
      expect(plans.fold<int>(0, (n, c) => n + c.meetings.length), 332);
      var predicted = 0;
      for (final c in dataset.courses) {
        final id = c.sourceId.split('/').last;
        final r = source[id]!;
        final metadata = native[c.sourceId]['sourceEducation'];
        expect(c.sourceId, 'kau/main/2026-2/$id');
        expect(c.section, isEmpty);
        expect(c.code, r['nativeCourseCode'] ?? '');
        expect(c.title, r['courseName']);
        expect(c.professor, r['professor']);
        expect(
          c.sourceClassification,
          r['classification'] ??
              (metadata['sourceKind'] == 'electronicsIncreaseTable'
                  ? '전공과목(전선/전필)'
                  : ''),
        );
        if (metadata['sourceKind'] == 'electronicsIncreaseTable') {
          expect(receipts[1]['nativeHeading'], contains('전공과목(전선/전필)'));
          expect(c.departments, isEmpty);
        }
        expect(c.sourceSchedule, r['nativeSchedule'] ?? '');
        expect(c.sourceClassroom, r['classroom'] ?? '');
        expect(
          c.credits,
          r['credits'] == null ? null : double.parse(r['credits'] as String),
        );
        expect(metadata['finalNativeClosureCheckComplete'], false);
        expect(metadata['physicalCampusIndividuallyProven'], false);
        expect(metadata['entireWeeklyMeetingCoverageVerified'], false);
        if (metadata['predictedClosureHeld'] == true) {
          predicted++;
          expect(c.meetings, isEmpty);
        }
        if (c.meetings.isEmpty) continue;
        expect(c.sourceClassroom, isEmpty);
        expect(c.credits, isNull);
        final nativeClock = RegExp(
          r'([월화수목금토일](?:/[월화수목금토일])*)\s*\)?\s*(\d{1,2}):(\d{2})\s*[~∼]\s*(\d{1,2}):(\d{2})',
        ).allMatches(c.sourceSchedule);
        final clocks = <String>{};
        for (final m in nativeClock) {
          final start = int.parse(m[2]!) * 60 + int.parse(m[3]!);
          final end = int.parse(m[4]!) * 60 + int.parse(m[5]!);
          for (final wd in m[1]!.split('/')) {
            clocks.add('${'월화수목금토일'.indexOf(wd) + 1}/$start/$end');
          }
        }
        for (final m in c.meetings) {
          expect(
            clocks,
            contains(
              '${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}',
            ),
          );
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(
            m.date!.compareTo('2026-09-01') >= 0 &&
                m.date!.compareTo('2026-12-07') <= 0,
            true,
          );
          expect(cal['excludedHolidays'] as List, isNot(contains(m.date)));
        }
      }
      expect(predicted, 43);
      final conflict = dataset.courses.singleWhere(
        (c) => c.sourceId.endsWith('/0595'),
      );
      expect(conflict.meetings, isEmpty);
      expect(conflict.sourceSchedule, '화/금12:00~12:30');
      expect(
        dataset.courses.singleWhere((c) => c.sourceId.endsWith('/0618')).code,
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
        final doc = TimetableSyncDocument.legacy(
          courses: originals,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(22));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(c.note, contains('확정 폐강 대조 미완료'));
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
