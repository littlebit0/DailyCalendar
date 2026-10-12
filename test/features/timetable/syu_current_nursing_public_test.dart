import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-c/syu-other-undergraduate-clock-review-20261009/';
  Map<String, dynamic> read(String path) {
    final actual =
        path.endsWith('syu-main-2026-2.nursing-current-clock-candidate-v3.json')
        ? 'work/university-research/catalog-c/syu-pt-room-teacher-unpublished-own-clock-v4-20261009/prior-full-1391-93-945-baseline.json'
        : path;
    final data =
        jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
    for (final row in data['courses'] ?? []) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
    }
    return data;
  }

  final prior = read(
    'work/university-research/catalog-c/syu-general-clock-review-20261009/syu-main-2026-2.pt-current-clock-candidate-v2.json',
  );
  final raw = read(
    '${root}syu-main-2026-2.nursing-current-clock-candidate-v3.json',
  );
  final proof = read(
    '${root}nursing-current-clock-source-candidate-audit.json',
  );
  final source = read('${root}latest-nursing-official-scope.json');
  final calendar = read(
    'work/university-research/catalog-c/syu-general-clock-review-20261009/current-own-calendar-reservation-scope.json',
  );
  final dataset = UniversityDataset.fromJson(raw);
  final old = {for (final c in prior['courses'] as List) c['sourceId']: c};
  final planned = {
    for (final r in proof['reviewedCourses'] as List) r['sourceId']: r,
  };
  test(
    '1391 native objects and frozen v2 whole55/448 remain unchanged; nursing84 union is exact',
    () {
      expect(dataset.courses, hasLength(1391));
      expect(dataset.courses.map((c) => c.sourceId).toSet(), old.keys.toSet());
      expect(planned, hasLength(38));
      final oldScheduled = (prior['courses'] as List)
          .where((c) => (c['schedules'] as List).isNotEmpty)
          .toList();
      expect(oldScheduled, hasLength(55));
      expect(
        oldScheduled.fold<int>(
          0,
          (n, c) => n + (c['schedules'] as List).length,
        ),
        448,
      );
      for (final c in raw['courses'] as List) {
        final previous = old[c['sourceId']]!;
        if (!planned.containsKey(c['sourceId']) ||
            (previous['schedules'] as List).isNotEmpty) {
          expect(c, previous);
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
      }
      final nursing = (raw['courses'] as List)
          .where(
            (c) =>
                (c['departments'] as List).length == 1 &&
                c['departments'][0] == '간호학과',
          )
          .toList();
      expect(nursing, hasLength(84));
      final held = proof['nursingHeld'] as List;
      expect(held, hasLength(44));
      expect(
        nursing.where((c) => (c['schedules'] as List).isNotEmpty),
        hasLength(40),
      );
      for (final row in held) {
        expect(
          dataset.courses
              .singleWhere((c) => c.sourceId == row['sourceId'])
              .meetings,
          isEmpty,
        );
        expect(row['reason'], isNotEmpty);
      }
      for (final i in [
        '27',
        '38',
        '45',
        '46',
        '2',
        '3',
        '25',
        '28',
        '307',
        '886',
      ]) {
        expect(
          dataset.courses
              .singleWhere((c) => c.sourceId == 'syu/main/2026-2/$i')
              .meetings,
          isEmpty,
        );
      }
    },
  );
  test(
    'current official nursing source exact HH, printed offering/group, per-day rooms and own calendar independently match',
    () {
      expect(source['nativeLastModified'], '2026.09.10');
      expect(source['downloadLinkObserved'], true);
      expect(
        source['PDFSHA256'],
        'abff39cbce16267e0fdb770cd2d5107a9646878cf066b318f89ed3b9a6235576',
      );
      expect(proof['olderAugustPDFUsedForCurrentCandidate'], false);
      expect(
        proof['clockScope'],
        '2026-2 nursing undergraduate timetable only',
      );
      final entries = calendar['nativeEducationEntries'] as List;
      for (final row in [
        {'nativeDates': '09.01', 'label': '개강'},
        {'nativeDates': '10.20 ~ 10.26', 'label': '중간고사(8주차)'},
        {'nativeDates': '10.27 ~ 11.02', 'label': '온라인수업 권장주간'},
        {'nativeDates': '12.08 ~ 12.14', 'label': '기말고사(15주차)'},
      ]) {
        expect(
          entries.where(
            (e) =>
                e['nativeDates'] == row['nativeDates'] &&
                e['label'] == row['label'],
          ),
          hasLength(1),
        );
      }
      const clockStart = [540, 600, 660, 720, 780, 840, 900, 960, 1020];
      const clockEnd = [590, 650, 710, 770, 830, 890, 950, 1010, 1070];
      final allSlots = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(allSlots, hasLength(93));
      expect(allSlots.fold<int>(0, (n, c) => n + c.meetings.length), 945);
      var newReservations = 0;
      for (final c in dataset.courses.where(
        (c) => planned.containsKey(c.sourceId),
      )) {
        final p = planned[c.sourceId]!;
        final published = old[c.sourceId]!;
        expect(c.code, p['nativeCourseCode']);
        expect(c.section, '');
        expect((p['PDFTeacherLiterals'] as List).contains(c.professor), true);
        expect(p['sourceImageVisuallyReviewed'], true);
        expect(p['sourceAliasInvented'], false);
        expect(
          c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).note,
          contains('날짜별 실제 출석·임상실습 배정 확인이 아닙니다'),
        );
        final expected = <String, String>{};
        for (final m in p['sourceMeetings'] as List) {
          final first = m['firstPeriod'] as int;
          final last = m['lastPeriod'] as int;
          expect(m['startMinute'], clockStart[first - 1]);
          expect(m['endMinute'], clockEnd[last - 1]);
          expect(m['educationImageCellBBox'], hasLength(4));
          expect(m['nativeRoomPublishedLiteral'], isNotEmpty);
          if (m['nativeRoomNumberClipped'] == true) {
            expect(p['PDFNativeLectureNumberPrinted'], true);
          }
          for (
            var d = DateTime(2026, 9, 1);
            !d.isAfter(DateTime(2026, 12, 7));
            d = d.add(const Duration(days: 1))
          ) {
            final ds =
                '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
            if (d.weekday != m['weekday'] ||
                [
                  '2026-09-24',
                  '2026-09-25',
                  '2026-10-05',
                  '2026-10-06',
                  '2026-10-07',
                  '2026-10-09',
                ].contains(ds) ||
                (d.isAfter(DateTime(2026, 10, 19)) &&
                    d.isBefore(DateTime(2026, 11, 3)))) {
              continue;
            }
            final room =
                p['PDFMidtermAfterRoomLiteral'] != null &&
                    d.isAfter(DateTime(2026, 10, 26))
                ? p['PDFMidtermAfterRoomLiteral'] as String
                : m['PDFRoomLiteral'] as String;
            expected['$ds/${m['weekday']}/${clockStart[first - 1]}/${clockEnd[last - 1]}'] =
                room;
          }
        }
        expect(c.meetings, hasLength(expected.length));
        expect(c.meetings, hasLength(p['reservationCount'] as int));
        for (final m in c.meetings) {
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          final key =
              '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}';
          expect(expected[key], m.classroom);
          expect(m.classroom, isNotEmpty);
        }
        expect(c.sourceSchedule, published['sourceSchedule']);
        expect(c.sourceClassroom, published['sourceClassroom']);
        newReservations += c.meetings.length;
      }
      expect(newReservations, 497);
      for (final i in ['75', '76', '81', '1537', '1']) {
        final c = dataset.courses.singleWhere(
          (c) => c.sourceId == 'syu/main/2026-2/$i',
        );
        final p = planned[c.sourceId]!;
        expect(
          c.meetings
              .where((m) => m.date!.compareTo('2026-11-03') >= 0)
              .every((m) => m.classroom == p['PDFMidtermAfterRoomLiteral']),
          true,
        );
      }
    },
  );
  test(
    'historical whole93/945 retain original clocks, rooms, notes and native identity through all3 modes and full Drive JSON',
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
        final doc = TimetableSyncDocument.legacy(
          courses: originals,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(93));
        final lookup = {for (final c in originals) c.sourceId: c};
        expect(restored.fold<int>(0, (n, c) => n + c.meetings.length), 945);
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
