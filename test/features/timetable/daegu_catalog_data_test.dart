import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-c/daegu-current-20261008';
Map<String, dynamic> read(String file) =>
    jsonDecode(fixtureFile('$directory/$file').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  final audit = read('candidate-audit.json');
  final file = audit['candidate']['file'] as String;
  final raw =
      jsonDecode(
            fixtureFile(
              'assets/timetable/daegu-main-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final courses = UniversityDataset.fromJson(raw).courses;
  final records = {for (final row in raw['courses']) row['sourceId']: row};
  final geometry =
      jsonDecode(
            fixtureFile(
              'work/university-research/catalog-c/daegu-sookmyung-ssu-held-native-bulk-v1-20261010/daegu-printed-time-room-geometry-proof.json',
            ).readAsStringSync(),
          )
          as Map;
  final resolvedGeometry = <String, Map>{
    for (final receipt in geometry['receipts'] as List)
      if (receipt['eligible'] == true)
        receipt['sourceId'] as String: receipt as Map,
  };
  test(
    'Native registration identity and actual excluded closures, never invented section',
    () {
      expect(raw['researchOnly'], false);
      expect(raw['completionClaim'], false);
      expect(courses, hasLength(3174));
      expect(
        sha256
            .convert(fixtureFile('$directory/$file').readAsBytesSync())
            .toString(),
        audit['candidate']['sha256'],
      );
      expect(audit['closedStillPresent'], isEmpty);
      expect(courses.map((c) => c.code).toSet(), hasLength(courses.length));
      for (final c in courses) {
        final record = records[c.sourceId];
        expect(record['referenceKind'], '수강번호');
        expect(record['canonicalSubjectCodePublished'], false);
        expect(c.section, isEmpty);
        for (final row in record['publicEducationRows']) {
          expect(c.code, row['nativeRegistrationNumber']);
          expect(c.code, row['education']['수강번호']);
        }
        expect(c.remarks, contains('별도 교과목코드 및 분반은 공개되지 않았습니다'));
      }
      final held = (audit['holds'] as List)
          .map((h) => h['nativeRegistrationNumber'])
          .toSet();
      for (final c in courses.where(
        (c) =>
            held.contains(c.code) && !resolvedGeometry.containsKey(c.sourceId),
      )) {
        expect(c.meetings, isEmpty);
      }
      expect(courses.singleWhere((c) => c.code == '2204').meetings, isEmpty);
    },
  );
  test(
    'Every projected date matches original source clock, weekday, room and calendar exclusions',
    () {
      final holiday = (audit['excludedHolidays'] as List)
          .cast<String>()
          .toSet();
      final clock = RegExp(r'([월화수목금토일])\((\d{2}):(\d{2})-(\d{2}):(\d{2})\)');
      var count = 0;
      for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
        final record = records[c.sourceId];
        final source = record['publicEducationRows'][0]['education'];
        expect(c.sourceSchedule, source['강의시간']);
        expect(c.sourceClassroom, source['강의실']);
        final blocks = clock.allMatches(source['강의시간'] as String).toList();
        expect(blocks, isNotEmpty);
        final expected = <String>{};
        for (
          var day = DateTime(2026, 9, 1);
          !day.isAfter(DateTime(2026, 12, 7));
          day = day.add(const Duration(days: 1))
        ) {
          final date = timetableDateKey(day);
          if (holiday.contains(date)) {
            continue;
          }
          for (final b in blocks) {
            final weekday = '월화수목금토일'.indexOf(b[1]!) + 1;
            if (day.weekday != weekday) {
              continue;
            }
            final start = int.parse(b[2]!) * 60 + int.parse(b[3]!);
            final end = int.parse(b[4]!) * 60 + int.parse(b[5]!);
            var room = source['강의실'];
            final proof = resolvedGeometry[c.sourceId];
            if (proof != null) {
              final printedRows = proof['printedGeometryRows'] as List;
              final lines = printedRows.expand(
                (r) => r['directPrintedLines'] as List,
              );
              final line = lines.firstWhere((r) => r['printedTime'] == b[0]);
              expect(line['samePrintedY'], true);
              room = line['printedRoom'];
            }
            expected.add('$date/$weekday/$start/$end/$room');
          }
        }
        final actual = <String>{};
        for (final m in c.meetings) {
          count++;
          expect(m.weekday, m.teachingDate!.weekday);
          expect(holiday.contains(m.date), false);
          expect(
            actual.add(
              '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            ),
            true,
          );
        }
        expect(actual, expected, reason: 'native registration ${c.code}');
      }
      expect(count, 55005);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(2801));
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      'Actual 2771 model classes 54198 dates full Drive JSON roundtrip ${mode.name}',
      () {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.defaultMode, mode);
          expect(saved.note, c.remarks);
          expect(saved.period!.start, DateTime(2026, 9, 1));
          expect(saved.period!.end, DateTime(2026, 12, 14));
          for (final m in saved.meetings) {
            count++;
            expect(m.isValid, true);
            expect(saved.period!.contains(m.teachingDate!), true);
            expect(saved.modeOn(m, m.teachingDate!), mode);
          }
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(values, hasLength(2801));
        expect(count, 55005);
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(2801));
        for (final c in restored.materializeClasses()) {
          expect(c.isValid, true);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      },
    );
  }
}
