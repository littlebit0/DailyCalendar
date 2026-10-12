import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test(
    'Ulsan title references keep unpublished code empty in all modes and full Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/ulsan/';
      final proof =
          jsonDecode(
                File(
                  '${root}ulsan-honors-current-native-education-proof-v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final tables = (proof['attachments'] as List)[1]['tables'] as List;
      final nativeCells = {
        for (final t in tables)
          for (final cell in t['cells'])
            '${t['tableIndex']}/${cell['row']}/${cell['column']}': cell,
      };
      final scheduled = <UniversityCourse>[];
      var total = 0, count = 0, blankSection = 0;
      for (final campus in ['main']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/ulsan-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        final rows = raw['courses'] as List;
        expect(raw['researchOnly'], isFalse);
        expect(raw['completionClaim'], isFalse);
        for (var i = 0; i < dataset.courses.length; i++) {
          final c = dataset.courses[i];
          final r = rows[i] as Map;
          final meta = r['metadata'] as Map;
          total++;
          for (final cell in meta['originalEducationalCells']) {
            final course = cell['nativeCourseCell'] as Map;
            final prof = cell['nativeProfessorRoomCell'] as Map;
            expect(
              course,
              nativeCells['${cell['tableIndex']}/${course['row']}/${course['column']}'],
            );
            expect(
              prof,
              nativeCells['${cell['tableIndex']}/${prof['row']}/${prof['column']}'],
            );
          }

          expect(c.code, isEmpty);
          expect(c.section, meta['nativeSection']);
          expect(c.codeAndSection, c.section.isEmpty ? '' : '분반 ${c.section}');
          if (c.section.isNotEmpty) {
            expect(c.matchesQuery('분반 ${c.section}'), true);
          }
          expect(meta['sourceCodePublished'], isFalse);
          expect(meta['referenceKind'], 'publishedCourseTitle');
          expect(meta['actualAttendanceConfirmed'], isFalse);
          expect(c.sourceClassification, isEmpty);
          if (c.section.isEmpty) blankSection++;
          if (!c.hasSchedulableMeetings) continue;
          scheduled.add(c);
          expect(campus, 'main');
          for (final m in c.meetings) {
            count++;
            final date = DateTime.parse(m.date!);
            expect(date.weekday, m.weekday);
            expect(date.isBefore(DateTime(2026, 9, 1)), isFalse);
            expect(date.isAfter(DateTime(2026, 12, 7)), isFalse);
            expect(
              date.isBefore(DateTime(2026, 10, 20)) ||
                  date.isAfter(DateTime(2026, 10, 26)),
              isTrue,
            );
            expect([
              '2026-09-24',
              '2026-09-25',
              '2026-10-05',
              '2026-10-09',
            ], isNot(contains(m.date)));
            expect(m.originalEndMinute - m.originalStartMinute, 50);
            expect(m.originalStartMinute, greaterThanOrEqualTo(540));
            expect(m.originalEndMinute, lessThanOrEqualTo(1070));
            expect(
              (r['schedules'] as List).every(
                (dynamic s) => !(s as Map).containsKey('deliveryMode'),
              ),
              isTrue,
            );
          }
        }
      }
      expect(total, 23);
      expect(scheduled, hasLength(23));
      expect(count, 648);
      expect(blankSection, greaterThan(0));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(23));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, prior.note);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
          expect(c.note, contains('공개 예약 계획, 실제 등교'));
          expect(c.note, contains('과목코드는 미공개'));
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
