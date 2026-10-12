import 'dart:convert';
import '../../support/source_fixture.dart';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test('Batch changes retain literal source fields, dates and Drive modes', () {
    final ledger = read(
      'work/university-research/resume-batch-20261010/staging-ledger.json',
    );
    for (final entry in ledger['sources'] as List) {
      final source = read(entry['source'] as String);
      // This regression audits the recorded staging operation, before later corrections.
      final asset = read(entry['stagedFile'] as String);
      final expected = {
        for (final c in source['courses'] as List) c['sourceId']: c,
      };
      final changed = (entry['changedSourceIds'] as List).toSet();
      final dataset = UniversityDataset.fromJson(asset);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final records = <String, TimetableSyncValue>{};
        for (final course in dataset.courses) {
          if (!changed.contains(course.sourceId)) continue;
          final literal = expected[course.sourceId] as Map;
          final rawMeetings = literal['schedules'] as List;
          if (rawMeetings.isEmpty) {
            expect(course.hasSchedulableMeetings, isFalse);
            continue;
          }
          final saved = course.toTimetable(id: course.sourceId, mode: mode);
          expect(saved.isValid, isTrue, reason: course.sourceId);
          expect(saved.defaultMode, mode);
          expect(saved.meetings, hasLength(rawMeetings.length));
          for (var i = 0; i < rawMeetings.length; i++) {
            final m = saved.meetings[i];
            final raw = rawMeetings[i] as Map;
            expect(m.date, raw['date']);
            expect(m.originalStartMinute, raw['startMinute']);
            expect(m.originalEndMinute, raw['endMinute']);
            expect(m.classroom, raw['classroom']);
            expect(m.weekday, raw['weekday']);
            if (m.teachingDate != null) {
              expect(m.weekday, m.teachingDate!.weekday);
              if (saved.period != null) {
                expect(saved.period!.contains(m.teachingDate!), isTrue);
              }
            }
            final forced = switch (raw['deliveryMode']) {
              'inPerson' => LectureMode.inPerson,
              'liveOnline' => LectureMode.liveOnline,
              'video' => LectureMode.video,
              _ => mode,
            };
            final modeDate = m.teachingDate ?? DateTime.utc(2026, 10, 10);
            expect(saved.modeOn(m, modeDate), forced);
          }
          final key = timetableCourseSyncKey(saved);
          expect(records.containsKey(key), isFalse);
          records[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 10),
            'source-batch',
          );
        }
        final document = TimetableSyncDocument.records(
          courses: records,
          schemaVersion: 2,
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(records.length));
        for (final c in restored) {
          expect(c.toJson(), records[timetableCourseSyncKey(c)]!.value);
        }
      }
    }
  });
}
