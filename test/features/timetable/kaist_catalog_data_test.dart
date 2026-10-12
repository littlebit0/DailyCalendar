import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'KAIST ten source-dated lectures preserve native identity and three modes through full Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/kaist/';
      final proof =
          jsonDecode(
                File(
                  '${root}kaist-current-aic-educational-proof-v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final raw =
          jsonDecode(
                File(
                  '${root}kaist-main-2026-2.aic-dated-planned-v1.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(raw['researchOnly'], isTrue);
      expect(raw['completionClaim'], isFalse);
      expect(raw['publishedDate'], isEmpty);
      final dataset = UniversityDataset.fromJson(raw);
      final c = dataset.courses.single;
      final native = proof['undergraduateProof']['nativeRow'] as List;
      expect(
        proof['undergraduateProof']['nativeHeading'],
        'Undergraduate Courses',
      );
      expect(c.code, native[1]);
      expect(c.code, 'AIC.20000');
      expect(c.section, isEmpty);
      expect(c.title, native[2]);
      expect(c.sourceClassification, native[0]);
      expect(c.sourceClassification, 'Major Required');
      expect(c.credits, num.parse((native[3] as String).split(':').last));
      expect(c.campus, 'main');
      expect(
        proof['campusProof']['nativeBuildingScope'],
        contains('대전광역시 유성구 대학로 291'),
      );
      expect(proof['campusProof']['nativeBuildingScope'], contains('E3-1'));
      expect(proof['campusProof']['nativeBuildingScope'], contains('N1'));
      final calendar = (proof['calendarProof']['nativeRows'] as List)
          .map((dynamic x) => x.join(' '))
          .join('\n');
      expect(calendar, contains('08-31(Mon) Beginning of Fall 2026 classes'));
      expect(
        calendar,
        contains('10-19(Mon) ~ 10-23(Fri) Fall 2026 mid-term exams'),
      );
      expect(
        calendar,
        contains('12-14(Mon) ~ 12-18(Fri) Fall 2026 final exams'),
      );
      expect(calendar, contains('12-18(Fri) End of Fall 2026 classes'));
      final clocks = RegExp(
        r'^Thursdays, (\d\d):(\d\d)-(\d\d):(\d\d)$',
      ).firstMatch(proof['nativeClock'])!;
      final start = int.parse(clocks[1]!) * 60 + int.parse(clocks[2]!);
      final end = int.parse(clocks[3]!) * 60 + int.parse(clocks[4]!);
      expect(start, 960);
      expect(end, 1140);
      final rows = proof['nativeRows'] as List;
      expect(rows, hasLength(16));
      final lectures = rows
          .where((dynamic r) => r['session'].startsWith('Lecture '))
          .toList();
      final noClassDates = rows
          .where((dynamic r) => r['session'] == 'No Class')
          .map((dynamic r) => r['date'])
          .toSet();
      expect(noClassDates, {
        '2026-09-17',
        '2026-09-24',
        '2026-10-15',
        '2026-10-22',
        '2026-11-26',
        '2026-12-17',
      });
      expect(lectures, hasLength(10));
      final professors = lectures
          .map((dynamic r) => r['instructor'])
          .toSet()
          .join(' / ');
      expect(c.professor, professors);
      final expected = {
        for (final dynamic r in lectures)
          '${r['date']}/${DateTime.parse(r['date']).weekday}/$start/$end/${r['location']}',
      };
      expect(
        c.meetings
            .map(
              (m) =>
                  '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            )
            .toSet(),
        expected,
      );
      expect(c.meetings, hasLength(10));
      expect(c.meetings.any((m) => noClassDates.contains(m.date)), isFalse);
      for (final m in c.meetings) {
        expect(m.teachingDate!.isBefore(DateTime(2026, 8, 31)), isFalse);
        expect(m.teachingDate!.isAfter(DateTime(2026, 12, 18)), isFalse);
        expect(m.weekday, 4);
      }
      final row = (raw['courses'] as List).single as Map;
      expect(row['metadata']['originalEducationalSchedule'], rows);
      expect(row['metadata']['actualAttendanceConfirmed'], isFalse);
      expect(row['metadata']['latestWholeClosureConfirmed'], isFalse);
      expect(
        (row['schedules'] as List).every(
          (dynamic m) => !(m as Map).containsKey('deliveryMode'),
        ),
        isTrue,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final original = c.toTimetable(id: c.sourceId, mode: mode);
        final doc = TimetableSyncDocument.legacy(
          courses: [original],
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses().single;
        expect(after.isValid, isTrue);
        expect(after.defaultMode, mode);
        expect(after.sourceId, original.sourceId);
        expect(after.title, original.title);
        expect(after.professor, original.professor);
        expect(after.note, original.note);
        expect(
          after.meetings.map((m) => m.toJson()).toList(),
          original.meetings.map((m) => m.toJson()).toList(),
        );
        for (final m in after.meetings) {
          expect(after.modeOn(m, DateTime.parse(m.date!)), mode);
        }
      }
    },
  );
}
