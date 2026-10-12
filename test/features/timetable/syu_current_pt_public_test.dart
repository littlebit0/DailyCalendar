import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-c/syu-general-clock-review-20261009/';
  Map<String, dynamic> read(String path) {
    final data =
        jsonDecode(fixtureFile(path).readAsStringSync())
            as Map<String, dynamic>;
    if (path.endsWith('syu-main-2026-2.native1391-chapel-partial-v1.json')) {
      for (final row in data['courses']) {
        if (row['metadata']?.containsKey('researchOnly') == true) {
          row['metadata']['researchOnly'] = false;
        }
      }
    }
    return data;
  }

  final prior = read(
    'work/university-research/catalog-f/syu/syu-main-2026-2.native1391-chapel-partial-v1.json',
  );
  final raw = read('${root}syu-main-2026-2.pt-current-clock-candidate-v2.json');
  final proof = read('${root}pt-current-clock-source-candidate-audit.json');
  final dataset = UniversityDataset.fromJson(raw);
  final calendar = read('${root}current-own-calendar-reservation-scope.json');
  final clockOCR = read('${root}current-clock-column-independent-ocr.json');
  final old = {for (final c in prior['courses'] as List) c['sourceId']: c};
  final planned = {
    for (final r in proof['reviewedCourses'] as List) r['sourceId']: r,
  };
  test(
    'current PT scope preserves 1391 native rows and prior38 whole courses',
    () {
      expect(dataset.courses, hasLength(1391));
      expect(dataset.courses.map((c) => c.sourceId).toSet(), old.keys.toSet());
      expect(planned, hasLength(17));
      for (final c in raw['courses'] as List) {
        final previous = old[c['sourceId']]!;
        if (!planned.containsKey(c['sourceId'])) {
          expect(c, previous);
        }
        if ((previous['schedules'] as List).isNotEmpty) {
          expect(c, previous);
        }
        for (final field in [
          'sourceId',
          'courseCode',
          'courseName',
          'section',
          'professor',
          'classification',
          'credits',
          'sourceSchedule',
          'sourceClassroom',
          'departments',
        ]) {
          expect(c[field], previous[field]);
        }
        for (final entry in (previous as Map).entries) {
          if (![
            'schedules',
            'scheduleStatus',
            'period',
            'departmentRemarks',
            'sourceEducation',
          ].contains(entry.key)) {
            expect(c[entry.key], entry.value);
          }
        }
        for (final entry in (previous['sourceEducation'] as Map).entries) {
          expect(c['sourceEducation'][entry.key], entry.value);
        }
        expect(
          c['sourceEducation']['nativePublicCells'],
          previous['sourceEducation']['nativePublicCells'],
        );
      }
      expect(
        dataset.courses
            .singleWhere((c) => c.sourceId.endsWith('/307'))
            .meetings,
        isEmpty,
      );
      expect(
        dataset.courses
            .singleWhere((c) => c.sourceId.endsWith('/886'))
            .meetings,
        isEmpty,
      );
    },
  );
  test(
    'native exact weekday HH room and explicit exceptions independently agree',
    () {
      expect(calendar['reservationStartDate'], '2026-09-01');
      expect(calendar['reservationEndDate'], '2026-12-07');
      final entries = calendar['nativeEducationEntries'] as List;
      for (final sourceRow in [
        {'nativeDates': '09.01', 'label': '개강'},
        {'nativeDates': '12.08 ~ 12.14', 'label': '기말고사(15주차)'},
        {'nativeDates': '10.27 ~ 11.02', 'label': '온라인수업 권장주간'},
      ]) {
        expect(
          entries.where(
            (r) =>
                r['nativeDates'] == sourceRow['nativeDates'] &&
                r['label'] == sourceRow['label'],
          ),
          hasLength(1),
        );
      }
      final observedTimes = (clockOCR['observations'] as List)
          .map((r) => r['text'] as String)
          .join(' ');
      for (final pair in [
        '09:00',
        '09:50',
        '10:00',
        '10:50',
        '11:00',
        '11:50',
        '12:00',
        '12:50',
        '13:00',
        '13:50',
        '14:00',
        '14:50',
        '15:00',
        '15:50',
        '16:00',
        '16:50',
        '17:00',
        '17:50',
        '18:00',
        '18:50',
      ]) {
        expect(observedTimes, contains(pair));
      }
      final slots = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(slots, hasLength(55));
      expect(slots.fold<int>(0, (n, c) => n + c.meetings.length), 448);
      for (final c in dataset.courses.where(
        (c) => planned.containsKey(c.sourceId),
      )) {
        final p = planned[c.sourceId]!;
        expect(c.sourceSchedule, p['nativeSchedule']);
        final day = '월화수목금'.indexOf(c.sourceSchedule[0]) + 1;
        final periods = c.sourceSchedule.substring(1).split('~');
        final first = int.parse(periods.first);
        final last = int.parse(periods.last);
        expect(
          c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).note,
          contains('날짜별 실제 출석·개별 강의계획 검증이 아닙니다'),
        );
        for (final m in c.meetings) {
          final d = DateTime.parse(m.date!);
          expect(d.weekday, day);
          expect(m.weekday, day);
          expect(
            m.originalStartMinute,
            (proof['clock'] as Map)['$first']['startMinute'],
          );
          expect(
            m.originalEndMinute,
            (proof['clock'] as Map)['$last']['endMinute'],
          );
          expect(m.classroom, c.sourceClassroom);
          expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
          expect(m.date!.compareTo('2026-12-07'), lessThanOrEqualTo(0));
          expect([
            '2026-09-24',
            '2026-09-25',
            '2026-10-05',
            '2026-10-06',
            '2026-10-07',
            '2026-10-09',
          ], isNot(contains(m.date)));
          expect(
            d.isAfter(DateTime(2026, 10, 19)) &&
                d.isBefore(DateTime(2026, 11, 3)),
            false,
          );
          if (c.sourceId.endsWith('/289')) {
            expect(['2026-11-20', '2026-11-27'], isNot(contains(m.date)));
          }
        }
      }
    },
  );
  test(
    'all55 courses keep every class field through all3 modes and full Drive JSON',
    () {
      final slots = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = slots
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
        expect(restored, hasLength(55));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
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
