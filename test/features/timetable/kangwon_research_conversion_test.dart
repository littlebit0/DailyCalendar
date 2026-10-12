import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final datasets = [
    for (final campus in [
      'chuncheon',
      'samcheok',
      'dogye',
      'gangneung',
      'wonju',
    ])
      UniversityDataset.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(
                File(
                  'assets/timetable/kangwon-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map,
        ),
      ),
  ];
  final courses = [for (final dataset in datasets) ...dataset.courses];

  test(
    'Kangwon whole official active scope passes actual dataset boundaries',
    () {
      expect(courses, hasLength(5761));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(5761));
      expect(datasets.map((d) => d.campus).toSet(), hasLength(5));
      expect(courses.where((c) => !c.hasSchedulableMeetings), hasLength(653));
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
        expect(restored.period?.toJson(), saved.period?.toJson());
      }
    },
  );

  test(
    'All 135 institution service sections have proven short periods and actual clocks',
    () {
      final service = courses.where((c) => c.code == '14207025').toList();
      expect(service, hasLength(137));
      expect(service.where((c) => c.hasSchedulableMeetings), hasLength(135));
      for (final section in ['01', '02']) {
        expect(
          service
              .singleWhere((c) => c.section == section)
              .hasSchedulableMeetings,
          isFalse,
        );
      }
      for (final course in service.where((c) => c.hasSchedulableMeetings)) {
        final restored = TimetableClass.fromJson(
          course
              .toTimetable(id: course.sourceId, mode: LectureMode.inPerson)
              .toJson(),
        );
        expect(restored.period!.contains(DateTime(2026, 9, 13)), isFalse);
        expect(restored.period!.contains(DateTime(2026, 9, 14)), isTrue);
        expect(restored.period!.contains(DateTime(2026, 12, 4)), isTrue);
        expect(restored.period!.contains(DateTime(2026, 12, 5)), isFalse);
        expect(
          restored.meetings.single.endMinute -
              restored.meetings.single.startMinute,
          120,
        );
        expect(
          classOccurrences(
            [restored],
            [DateTime(2026, 9, 8), DateTime(2026, 12, 15)],
          ),
          isEmpty,
        );
      }
    },
  );

  test('Dataset rejects a mismatched physical campus', () {
    final raw = Map<String, dynamic>.from(
      jsonDecode(
            File(
              'assets/timetable/kangwon-wonju-2026-2.json',
            ).readAsStringSync(),
          )
          as Map,
    );
    expect(
      () => UniversityDataset.fromJson({...raw, 'campus': 'gangneung'}),
      throwsFormatException,
    );
  });
}
