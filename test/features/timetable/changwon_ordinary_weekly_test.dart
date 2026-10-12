import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Changwon frozen v3 native clocks and own dates preserve 1754 identities, prior exact plans and three full Drive documents',
    () {
      const source = 'work/university-research/catalog-v/';
      const root = '${source}changwon-ordinary-weekly-reservations-v3/';
      Map<String, dynamic> object(String file) =>
          jsonDecode(File(file).readAsStringSync()) as Map<String, dynamic>;
      final raw = object(
        '${root}changwon-unknown-2026-2.ordinary-weekly-v3.json',
      );
      final prior = object(
        '${source}changwon-unknown-2026-2.eleven-dated-v2.json',
      );
      final proof = object('${root}source-period-operation-proof.json');
      final clocks = object(
        '${root}current-undergraduate-native-clock-education.json',
      );
      final dataset = UniversityDataset.fromJson(raw);
      final original =
          jsonDecode(
                File(
                  '${source}changwon-current-educational-rows-20261008.json',
                ).readAsStringSync(),
              )
              as List;
      final grouped = <String, List<dynamic>>{};
      for (final dynamic row in original) {
        grouped
            .putIfAbsent('${row['code']}-${row['section']}', () => [])
            .add(row);
      }
      expect(original, hasLength(2112));
      expect(dataset.courses, hasLength(1754));
      expect(proof['allCurrentPublicPlanReceipts'], hasLength(1754));
      expect(proof['currentPublishedUndergraduateClosures'], hasLength(69));
      final currentById = {for (final c in dataset.courses) c.sourceId: c};
      final rawById = {
        for (final dynamic c in raw['courses'] as List) c['sourceId']: c,
      };
      var priorCount = 0;
      var priorDates = 0;
      for (final dynamic c in prior['courses'] as List) {
        final dynamic n = rawById[c['sourceId']];
        for (final field in [
          'sourceId',
          'universityId',
          'campus',
          'academicYear',
          'semester',
          'courseCode',
          'section',
          'courseName',
          'professor',
          'credits',
          'sourceSchedule',
          'classification',
        ]) {
          expect(n[field], c[field]);
        }
        expect(
          n['sourceEducation']['originalPublicRows'],
          grouped['${c['courseCode']}-${c['section']}'],
        );
        expect(c['campus'], 'unknown');
        if ((c['schedules'] as List).isNotEmpty) {
          priorCount++;
          priorDates += (c['schedules'] as List).length;
          expect(
            n,
            c,
          ); // Preserve every prior exact date/exam/room/notes/mode exception.
        }
      }
      expect(priorCount, 11);
      expect(priorDates, 185);
      final clockRows = {
        for (final dynamic r
            in clocks['nativePublishedPeriodClockRows'] as List)
          r['nativePeriod'] as String: r,
      };
      expect(clockRows, hasLength(28));
      expect(clockRows['1A']['startMinute'], 540);
      expect(clockRows['9B']['endMinute'], 1080);
      expect(clockRows['10A']['startMinute'], 1100);
      expect(clockRows['10B']['endMinute'], 1150);
      expect(clockRows['14A']['startMinute'], 1300);
      expect(clockRows['14B']['endMinute'], 1350);
      expect(clockRows.containsKey('15A'), isFalse);
      for (final dynamic r in clockRows.values) {
        expect(
          r['endMinute'] - r['startMinute'],
          int.parse(
                    (r['nativePeriod'] as String).replaceAll(
                      RegExp('[AB]'),
                      '',
                    ),
                  ) <=
                  9
              ? 30
              : 25,
        );
      }
      final calendar = proof['currentOwnCalendar']['rows'] as List;
      expect(
        calendar.any(
          (dynamic r) =>
              r['schdulTitle'] == '2026-2학기 개강' && r['bgnde'] == '2026/09/01',
        ),
        isTrue,
      );
      expect(
        calendar.any(
          (dynamic r) =>
              r['schdulTitle'] == '보강주' && r['bgnde'] == '2026/12/08',
        ),
        isTrue,
      );
      expect(
        calendar.any(
          (dynamic r) =>
              r['schdulTitle'] == '기말고사' &&
              r['bgnde'] == '2026/12/14' &&
              r['endde'] == '2026/12/19',
        ),
        isTrue,
      );
      final holidays =
          (proof['nationalDateReferenceOnly']['conservativeUnknownOperationHoldDates']
                  as List)
              .cast<String>()
              .toSet();
      final published = dataset.courses
          .where((c) => c.hasSchedulableMeetings)
          .toList();
      expect(published, hasLength(1377));
      expect(published.expand((c) => c.meetings), hasLength(28278));
      var ordinaryCount = 0;
      var ordinaryDates = 0;
      for (final course in dataset.courses) {
        final dynamic native = rawById[course.sourceId];
        final dynamic review =
            native['sourceEducation']['regularReservationReview'];
        if (review == null) {
          expect(course.hasSchedulableMeetings, isTrue);
          continue;
        }
        final file =
            '$source${native['sourceEducation']['currentPublicPlanReceipt']['sourceFile']}';
        final actual = object(file);
        expect(
          native['sourceEducation']['currentPublicPlanFields'],
          actual['fields'],
        );
        expect(actual['fields']['학수번호'], course.code);
        expect(actual['fields']['분반'], course.section);
        expect(actual['fields']['강의시간(장소)'], course.sourceSchedule);
        if (!course.hasSchedulableMeetings) {
          expect(review['holdReasons'], isNotEmpty);
          continue;
        }
        ordinaryCount++;
        ordinaryDates += course.meetings.length;
        expect(actual['fields']['수업운영방식'], '대면');
        expect([
          '일반강의',
          '영어강의',
          '제2외국어강의',
          '외국인전용강좌',
          '팀티칭',
        ], contains(actual['fields']['강의진행방식']));
        expect(course.period!.start, DateTime(2026, 9, 1));
        expect(course.period!.end, DateTime(2026, 12, 7));
        expect(course.period!.contains(DateTime(2026, 8, 31)), isFalse);
        expect(course.period!.contains(DateTime(2026, 12, 8)), isFalse);
        final match = RegExp(r'([월화수목금토일])(\d{1,2})([AB])(?:\(([^()]*)\))?');
        final pieces = <Map<String, dynamic>>[];
        final rooms = <int, String>{};
        for (final m in match.allMatches(course.sourceSchedule)) {
          final day = '월화수목금토일'.indexOf(m[1]!) + 1;
          final period = '${m[2]}${m[3]}';
          expect(clockRows.containsKey(period), isTrue);
          if (m[4] != null && m[4]!.isNotEmpty) {
            rooms[day] = m[4]!;
          }
          expect(rooms[day], isNotNull);
          pieces.add({
            'weekday': day,
            'start': clockRows[period]['startMinute'],
            'end': clockRows[period]['endMinute'],
            'room': rooms[day],
          });
        }
        final examDates = RegExp(r'2026\.(\d{1,2})\.(\d{1,2})')
            .allMatches(actual['fields']['시험일시'] as String? ?? '')
            .map(
              (m) => '2026-${m[1]!.padLeft(2, '0')}-${m[2]!.padLeft(2, '0')}',
            )
            .toSet();
        final expected = <String>{};
        for (
          var day = DateTime(2026, 9, 1);
          !day.isAfter(DateTime(2026, 12, 7));
          day = day.add(const Duration(days: 1))
        ) {
          final date = timetableDateKey(day);
          if (holidays.contains(date) ||
              examDates.contains(date) ||
              date == '2026-11-24') {
            continue;
          }
          for (final piece in pieces.where(
            (r) => r['weekday'] == day.weekday,
          )) {
            for (
              var minute = piece['start'] as int;
              minute < (piece['end'] as int);
              minute += 5
            ) {
              if (date == '2026-11-19' && minute < 600) {
                continue;
              }
              expected.add('$date/${day.weekday}/$minute/${piece['room']}');
            }
          }
        }
        final restoredPieces = <String>{};
        for (final m in course.meetings) {
          expect(m.date, isNotNull);
          expect(m.teachingDate!.weekday, m.weekday);
          expect(course.period!.contains(m.teachingDate!), isTrue);
          expect(
            (native['schedules'] as List).every(
              (dynamic r) => !r.containsKey('deliveryMode'),
            ),
            isTrue,
          );
          expect(m.originalStartMinute % 5, 0);
          expect(m.originalEndMinute % 5, 0);
          for (
            var minute = m.originalStartMinute;
            minute < m.originalEndMinute;
            minute += 5
          ) {
            restoredPieces.add('${m.date}/${m.weekday}/$minute/${m.classroom}');
          }
        }
        expect(restoredPieces, expected, reason: course.sourceId);
      }
      expect(ordinaryCount, 1366);
      expect(ordinaryDates, 28093);
      final writing = dataset.courses.singleWhere(
        (c) => c.code == 'GEA5053' && c.section == '00',
      );
      expect(writing.professor, '안정아');
      expect(writing.meetings, hasLength(14));
      expect(
        writing.meetings.every(
          (m) =>
              m.weekday == 3 &&
              m.originalStartMinute == 720 &&
              m.originalEndMinute == 840 &&
              m.classroom == '11106',
        ),
        isTrue,
      );
      final night = dataset.courses.singleWhere(
        (c) => c.code == 'GEA8585' && c.section == '60',
      );
      expect(night.meetings, hasLength(27));
      expect(
        night.meetings
            .where((m) => m.weekday == 1)
            .every(
              (m) =>
                  m.originalStartMinute == 1100 &&
                  m.originalEndMinute == 1175 &&
                  m.classroom == 'B21116',
            ),
        isTrue,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = published
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(after, hasLength(1377));
        expect(after.expand((c) => c.meetings), hasLength(28278));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in after) {
          final old = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.title, old.title);
          expect(c.professor, old.professor);
          expect(c.note, old.note);
          expect(c.period!.toJson(), old.period!.toJson());
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            old.meetings.map((m) => m.toJson()).toList(),
          );
          final dynamic review =
              rawById[c
                  .sourceId]['sourceEducation']['regularReservationReview'];
          for (final m in c.meetings) {
            expect(
              c.modeOn(m, m.teachingDate!),
              review == null ? LectureMode.inPerson : mode,
            );
          }
          expect(currentById.containsKey(c.sourceId), isTrue);
        }
      }
    },
  );
}
