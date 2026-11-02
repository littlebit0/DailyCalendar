// 2026-10-23 공식 개설교과목 재대조와 강의계획서 직접 표기 반영을 확인한다.
import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final raw =
      jsonDecode(
            File('assets/timetable/sogang-unknown-2026-2.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final courses = (raw['courses'] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> byId(String id) =>
      courses.singleWhere((c) => '${c['courseCode']}-${c['section']}' == id);
  const weekdays = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
  final excluded = <String>{
    '2026-09-18',
    '2026-09-24',
    '2026-09-25',
    '2026-09-26',
    '2026-10-03',
    '2026-10-05',
    '2026-10-09',
    '2026-11-20',
    for (var d = 20; d <= 26; d++) '2026-10-$d',
    for (var d = 15; d <= 21; d++) '2026-12-$d',
  };

  test('계획서가 대면 운영과 시각을 직접 적은 23강좌만 정규 주간 예약을 받는다', () {
    final resolved = courses
        .where(
          (c) =>
              (c['reservationEvidence'] as Map?)?['planDirectStatement'] !=
              null,
        )
        .toList();
    expect(resolved, hasLength(23));
    for (final c in resolved) {
      final id = '${c['courseCode']}-${c['section']}';
      final evidence = c['reservationEvidence'] as Map;
      final native = c['sourceEducationalMetadata'] as Map;
      final meeting = RegExp(
        r'^([월화수목금토일](?:,[월화수목금토일])*) (\d{2}):(\d{2})~(\d{2}):(\d{2}) \[([^\]]+)\]$',
      ).firstMatch(native['meetingText'] as String)!;
      final days = meeting[1]!.split(',').map((d) => weekdays[d]!).toSet();
      final start = int.parse(meeting[2]!) * 60 + int.parse(meeting[3]!);
      final end = int.parse(meeting[4]!) * 60 + int.parse(meeting[5]!);
      final skip = {
        ...excluded,
        ...(evidence['excludedPlanStatedNoClassDates'] as List).cast<String>(),
        ...RegExp(r'(\d{1,2})\.(\d{1,2})\(')
            .allMatches(native['exam'] as String)
            .map(
              (m) => '2026-${m[1]!.padLeft(2, '0')}-${m[2]!.padLeft(2, '0')}',
            ),
      };
      final expected = <String>[];
      for (
        var d = DateTime(2026, 9, 1);
        !d.isAfter(DateTime(2026, 12, 21));
        d = d.add(const Duration(days: 1))
      ) {
        final key = timetableDateKey(d);
        if (days.contains(d.weekday) && !skip.contains(key)) expected.add(key);
      }
      final regular = (c['schedules'] as List)
          .cast<Map>()
          .where(
            (m) =>
                m['startMinute'] == start &&
                m['endMinute'] == end &&
                m['classroom'] == meeting[6] &&
                !skip.contains(m['date']),
          )
          .map((m) => m['date'])
          .toList();
      expect(regular, expected, reason: id);
      expect(c['scheduleStatus'], 'scheduled', reason: id);
      expect(c['period'], {'startDate': '2026-09-01', 'endDate': '2026-12-21'});
      final statement = evidence['planDirectStatement'] as Map;
      expect(statement['operatingModeExcerpt'], isNotEmpty, reason: id);
      expect(statement['clockExcerpt'], isNotEmpty, reason: id);
      // 시험만 있던 강좌는 공개 시험 약속 1회를 그대로 유지한다.
      final exam = c['publishedExamAppointmentEvidence'] as Map?;
      expect(
        (c['schedules'] as List).length,
        expected.length + (exam == null ? 0 : 1),
        reason: id,
      );
      if (exam != null) {
        expect(
          (c['schedules'] as List).where(
            (m) =>
                m['date'] == exam['calendarDate'] &&
                m['startMinute'] == exam['startMinute'] &&
                m['endMinute'] == exam['endMinute'],
          ),
          hasLength(1),
          reason: id,
        );
      }
    }
    for (final id in ['ECO2001-01', 'SHS2007-03']) {
      expect(
        (byId(id)['schedules'] as List).map((m) => m['date']),
        isNot(contains('2026-09-10')),
      );
    }
  });

  test('공식 조회에서 시험일자가 빠진 시험만 강좌는 미확정으로 남는다', () {
    for (final id in ['HSS4003-01', 'HSS4007-01', 'MEE3301-04', 'SOCG017-01']) {
      final c = byId(id);
      expect(c['scheduleStatus'], 'unrecognized', reason: id);
      expect(c['schedules'], isEmpty, reason: id);
      expect((c['sourceEducationalMetadata'] as Map)['exam'], '', reason: id);
      expect(c.containsKey('publishedExamAppointmentEvidence'), false);
    }
    final examOnly = courses.where(
      (c) =>
          c.containsKey('publishedExamAppointmentEvidence') &&
          !c.containsKey('reservationEvidence'),
    );
    expect(examOnly, hasLength(392));
    expect(raw['publishedExamAppointmentOnlyAdditionCount'], 392);
    expect(
      courses.where((c) => c['scheduleStatus'] == 'unrecognized'),
      hasLength(188),
    );
  });

  test('바뀐 시험 약속·강의실·학과가 저장과 복원을 거쳐도 유지된다', () {
    final data = UniversityDataset.fromJson(raw);
    final moved = data.courses.singleWhere(
      (c) => c.codeAndSection == 'GKS3024-01',
    );
    final saved = moved.toTimetable(id: moved.sourceId, mode: LectureMode.video);
    final restored = TimetableClass.fromJson(saved.toJson());
    expect(restored.meetings.single.date, '2026-10-21');
    final room = data.courses.singleWhere(
      (c) => c.codeAndSection == 'ENG3107-01',
    );
    expect(room.meetings.map((m) => m.classroom).toSet(), {'X349'});
    expect(
      data.courses.singleWhere((c) => c.codeAndSection == 'STS2008-02').departments,
      ['전인교육원'],
    );
    expect(
      data.courses
          .singleWhere((c) => c.codeAndSection == 'CSE4115-01')
          .meetings
          .map((m) => m.date),
      isNot(contains('2026-10-23')),
    );
  });
}
