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
      expect(courses.where((c) => !c.hasSchedulableMeetings), hasLength(198));
      for (final course in courses) {
        if (!course.hasSchedulableMeetings) {
          // 원문 시간표 칸이 비었거나 '0'뿐(강의실도 '0')이거나 같은 교시를 여러 번
          // 적어 교시로 해석할 수 없는 표기('토1,1,1')는 시간 미정이다.
          final source = course.sourceSchedule.trim();
          expect(course.scheduleStatus, 'unscheduled', reason: course.sourceId);
          expect(
            source.isEmpty ||
                source == '0' ||
                RegExp(r'^[토일],?(\d+),\1,\1$').hasMatch(source),
            isTrue,
            reason: course.sourceId,
          );
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
      expect(service.where((c) => c.period != null), hasLength(135));
      // 기관 시각이 없는 01·02분반은 원문 요일·교시(목·수 10,11교시)로 확정한다.
      for (final (section, weekday) in [('01', 4), ('02', 3)]) {
        final course = service.singleWhere((c) => c.section == section);
        expect(course.period, isNull);
        expect(
          course.meetings.map(
            (m) => (m.weekday, m.originalStartMinute, m.originalEndMinute),
          ),
          [(weekday, 1080, 1200)],
        );
      }
      for (final course in service.where((c) => c.period != null)) {
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

  test(
    'Official day-period rows map to the published Kangwon period clock',
    () {
      List<(int, int, int, String)> meetings(String id) => [
        for (final m in courses.singleWhere((c) => c.sourceId == id).meetings)
          (m.weekday, m.originalStartMinute, m.originalEndMinute, m.classroom),
      ];
      // A7은 공식 표(A1~A6, 90분 슬롯)를 같은 길이로 이어 18:00부터다.
      expect(meetings('kangwon/gangneung/2026/2/61400002/02'), [
        (1, 1080, 1170, 'C2-107'),
      ]);
      // 10~15교시 실습: 15교시는 60분 슬롯으로 이어 23:00~24:00.
      expect(meetings('kangwon/dogye/2026/2/53100095/1'), [
        (3, 1080, 1440, '보건과학관 응급간호학실습실(320호)'),
      ]);
      final repeated = courses.singleWhere(
        (c) => c.sourceId == 'kangwon/samcheok/2026/2/81220004/2',
      );
      expect(repeated.scheduleStatus, 'unscheduled');
      expect(repeated.canAddToTimetable, isTrue);
      expect(repeated.sourceSchedule, '토1,1,1');
      final zero = courses.singleWhere(
        (c) => c.sourceId == 'kangwon/gangneung/2026/2/22205004/01',
      );
      expect(zero.scheduleStatus, 'unscheduled');
      expect(zero.sourceSchedule, '0');
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
