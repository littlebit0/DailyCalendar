import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final datasets = [
    for (final campus in [
      'daegu',
      'sangju',
      'dongin',
      'downtown',
      'unassigned',
    ])
      UniversityDataset.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(
                File(
                  'assets/timetable/knu-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map,
        ),
      ),
  ];
  final courses = [for (final dataset in datasets) ...dataset.courses];
  test(
    'KNU dated dataset requires schema 2 and campus boundaries stay enforced',
    () {
      final raw = Map<String, dynamic>.from(
        jsonDecode(
              File(
                'assets/timetable/knu-unassigned-2026-2.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      expect(raw['schemaVersion'], 2);
      expect(
        () => UniversityDataset.fromJson({...raw, 'schemaVersion': 1}),
        throwsFormatException,
      );
      expect(
        () => UniversityDataset.fromJson({...raw, 'campus': 'daegu'}),
        throwsFormatException,
      );
      expect(datasets.map((d) => d.campus).toSet(), hasLength(5));
    },
  );
  test('KNU whole official scope parses with blocked exceptions preserved', () {
    expect(courses, hasLength(3847));
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(3847));
    expect(courses.where((c) => !c.hasSchedulableMeetings), hasLength(240));
    for (final course in courses) {
      if (!course.hasSchedulableMeetings) {
        expect(course.scheduleStatus, 'unrecognized');
        continue;
      }
      final saved = course.toTimetable(
        id: course.sourceId,
        mode: LectureMode.inPerson,
      );
      final restored = TimetableClass.fromJson(saved.toJson());
      expect(restored.isValid, isTrue, reason: course.sourceId);
      expect(
        restored.meetings.map((m) => m.toJson()).toList(),
        saved.meetings.map((m) => m.toJson()).toList(),
      );
    }
  });
  test(
    'KNU actual dated online classes do not become weekly or exam blocks',
    () {
      final dated = courses.where(
        (c) =>
            ['AAAA0912', 'AAAA0901'].contains(c.code) &&
            c.meetings.any((m) => m.date != null),
      );
      expect(dated, hasLength(2));
      for (final course in dated) {
        final saved = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.inPerson,
        );
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.meetings.every((m) => m.date != null), isTrue);
        for (final meeting in restored.meetings) {
          expect(
            restored.modeOn(meeting, meeting.teachingDate!),
            LectureMode.liveOnline,
          );
        }
        final dates = restored.meetings.map((m) => m.date).toSet();
        expect(dates, isNot(contains('2026-10-24')));
        expect(dates, isNot(contains('2026-12-12')));
        if (course.code == 'AAAA0912') {
          expect(dates, contains('2026-09-23'));
          expect(dates, isNot(contains('2026-09-24')));
          expect(restored.meetings, hasLength(6));
        } else {
          expect(restored.meetings, hasLength(7));
        }
      }
    },
  );
}
