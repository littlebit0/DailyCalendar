import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

void main() {
  test(
    'Jeju native reservations preserve clocks, unknown mode and full Drive document',
    () {
      final originals =
          (jsonDecode(
                    fixtureFile(
                      'work/university-research/catalog-i/jeju-current-whole-educational-review-20261008.json',
                    ).readAsStringSync(),
                  )
                  as Map)['courses']
              as List;
      final native = {for (final r in originals) '${r['enrollmentNumber']}': r};
      final scheduled = <UniversityCourse>[];
      var total = 0, count = 0, subjectCodes = 0, night = 0, blocks = 0;
      for (final campus in ['ara', 'sara', 'unknown']) {
        final raw =
            jsonDecode(
                  fixtureFile(
                    'work/university-research/catalog-r/jeju/jeju-$campus-2026-2.reservation-planned-v1.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final dataset = UniversityDataset.fromJson(raw);
        final rows = raw['courses'] as List;
        expect(raw['researchOnly'], isTrue);
        expect(raw['completionClaim'], isFalse);
        for (var i = 0; i < dataset.courses.length; i++) {
          final c = dataset.courses[i];
          final r = rows[i] as Map;
          final meta = r['metadata'] as Map;
          final original = meta['originalEducationalFields'] as Map;
          total++;
          expect(original, native['${original['enrollmentNumber']}']);
          expect(c.section, isEmpty);
          expect(c.sourceClassification, original['classification']);
          expect(meta['actualAttendanceConfirmed'], isFalse);
          expect(meta['currentActiveStatusVerified'], isFalse);
          if (original['subjectCode'] != null) {
            subjectCodes++;
            expect(c.code, original['subjectCode']);
          } else {
            expect(meta['referenceKind'], 'publishedEnrollmentNumber');
            expect(c.code, meta['publishedEnrollmentNumber']);
          }
          if (!c.hasSchedulableMeetings) continue;
          scheduled.add(c);
          expect(
            original['operatingReview'],
            'ordinary-clock-current-operation-review',
          );
          expect(original['department'].toString(), isNot(contains('의과대학')));
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
            final length = m.originalEndMinute - m.originalStartMinute;
            expect([45, 50, 75], contains(length));
            if (m.originalStartMinute >= 1110) {
              night++;
              expect(length, 45);
            }
            if (length == 75) blocks++;
            expect(
              (r['schedules'] as List).every(
                (dynamic s) => !(s as Map).containsKey('deliveryMode'),
              ),
              isTrue,
            );
          }
        }
      }
      expect(total, 3095);
      expect(subjectCodes, 531);
      expect(scheduled, hasLength(1510));
      expect(count, 52732);
      expect(night, greaterThan(0));
      expect(blocks, greaterThan(0));
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
        expect(restored, hasLength(1510));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, prior.note);
          expect(c.note, contains('공개 예약 계획, 실제 등교'));
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
