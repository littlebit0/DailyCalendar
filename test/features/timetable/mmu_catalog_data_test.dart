import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const root = 'work/university-research/catalog-w/mmu/';
Map<String, dynamic> read(String name) =>
    jsonDecode(
          File(
            name == 'mmu-unknown-2026-2.published-grid-partial-v1.json'
                ? 'assets/timetable/mmu-unknown-2026-2.json'
                : '$root$name',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  test(
    'MMU current changed grid retains document identity and complete exact period reservations in Drive',
    () {
      final raw = read('mmu-unknown-2026-2.published-grid-partial-v1.json');
      final data = UniversityDataset.fromJson(raw);
      final source = read('current-grid-education.json');
      final byRow = {for (final r in source['rows'] as List) r['sourceRow']: r};
      final clock = read('current-clock-education.json')['rows'][1] as List;
      expect(data.courses, hasLength(634));
      expect(raw['completionClaim'], false);
      final plans = <UniversityCourse>[];
      var slots = 0;
      for (var i = 0; i < data.courses.length; i++) {
        final c = data.courses[i];
        final r = raw['courses'][i] as Map;
        final education = r['sourceEducation'] as Map;
        final row = byRow[education['sourceRow']] as Map;
        expect(
          education['slots'],
          (row['slots'] as List)
              .where((s) => s['courseName'] == c.title)
              .toList(),
        );
        expect(c.code, isEmpty);
        expect(c.section, isEmpty);
        expect(c.codeAndSection, isEmpty);
        expect(c.credits, isNull);
        expect(c.sourceClassification, isEmpty);
        expect(
          c.sourceId,
          '${source['url']}#sheet=%EC%9E%90%EB%A3%8C&row=${row['sourceRow']}&column=${education['slots'][0]['sourceColumn']}',
        );
        expect(c.remarks, contains('공식 분반으로 확정하지 않았습니다'));
        expect(
          c.professor,
          (education['slots'] as List)
              .map((s) => s['professor'])
              .toSet()
              .join(', '),
        );
        if (!c.hasSchedulableMeetings) {
          expect(r['heldReason'], isNotEmpty);
          expect(
            c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).isValid,
            false,
          );
          continue;
        }
        expect(education['closureCandidates'], isEmpty);
        expect(row['department'].toString().trim(), isNot('모듈형과정'));
        plans.add(c);
        final expected = <String>{};
        for (final s in education['slots'] as List) {
          final period = s['period'] as String;
          final n = int.parse(period.substring(1));
          expect(n, inInclusiveRange(1, 13));
          final hours = (clock[n] as String).split(' ~ ');
          int minute(String t) =>
              int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3));
          final start = minute(hours[0]), end = minute(hours[1]);
          expect(end - start, 50);
          final weekday = '월화수목금토'.indexOf(period[0]) + 1;
          for (
            var day = DateTime(2026, 9, 1);
            !day.isAfter(DateTime(2026, 12, 13));
            day = day.add(const Duration(days: 1))
          ) {
            final date = day.toIso8601String().substring(0, 10);
            if (day.weekday != weekday ||
                {
                  '2026-09-24',
                  '2026-09-25',
                  '2026-09-26',
                  '2026-10-03',
                  '2026-10-05',
                  '2026-10-09',
                }.contains(date) ||
                (date.compareTo('2026-10-26') >= 0 &&
                    date.compareTo('2026-10-30') <= 0)) {
              continue;
            }
            expected.add('$date/$start/$end/${s['room']}');
          }
        }
        final actual = {
          for (final m in c.meetings)
            '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
        };
        expect(actual, expected, reason: c.sourceId);
        expect(actual, hasLength(c.meetings.length));
        slots += c.meetings.length;
        for (final m in c.meetings) {
          expect(DateTime.parse(m.date!).weekday, m.weekday);
        }
      }
      expect(plans, hasLength(587));
      expect(slots, 18946);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = plans
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        expect(classes.every((c) => c.isValid), true);
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        final lookup = {for (final c in classes) timetableCourseSyncKey(c): c};
        expect(restored, hasLength(classes.length));
        for (final c in restored) {
          final before = Map<String, dynamic>.from(
            lookup[timetableCourseSyncKey(c)]!.toJson(),
          )..remove('id');
          final after = Map<String, dynamic>.from(c.toJson())..remove('id');
          expect(after, before);
          expect(c.defaultMode, mode);
        }
      }
    },
  );
}
