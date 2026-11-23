import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/file_asset_bundle.dart';

const directory = 'work/university-research/catalog-c/daegu-current-20261008';
Map<String, dynamic> read(String file) =>
    jsonDecode(fixtureFile('$directory/$file').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  test('Catalog and term period load the restored Daegu dataset', () async {
    final datasets = await UniversityCatalog.load(
      bundle: FileAssetBundle(),
      university: 'daegu',
    );
    expect(
      {for (final d in datasets) d.campus: d.courses.length},
      {'main': 3555},
    );
    final period = (await TimetablePeriodDefaults.load(
      bundle: FileAssetBundle(),
    )).periodFor(2026, '2', university: 'daegu');
    expect(period?.start, DateTime(2026, 9, 1));
    expect(period?.end, DateTime(2026, 12, 14));
  });
  test(
    'Rows recovered from the official PDF keep printed cells and add only new registration numbers',
    () {
      final added = courses
          .where(
            (c) => (records[c.sourceId]['publicEducationRows'] as List).any(
              (r) => r['extraction'] != null,
            ),
          )
          .toList();
      // 143 rows the 2026-10-08 extraction missed plus 238 courses the
      // closure list had removed (2026-11-23 user decision).
      expect(added, hasLength(381));
      expect(
        added.where((c) => c.remarks.contains('폐강 공지 대상이어도 공식 시간표 행')),
        hasLength(238),
      );
      for (final c in added) {
        final rows = records[c.sourceId]['publicEducationRows'] as List;
        expect(rows.every((r) => r['extraction'] != null), true);
        final education = rows.first['education'] as Map;
        expect(c.title, education['교과목명']);
        expect(c.sourceSchedule, education['강의시간']);
        expect(c.sourceClassroom, education['강의실']);
        if (c.remarks.contains('일정 미생성')) {
          expect(c.meetings, isEmpty);
        }
      }
      // 104 printed clocks, 1 DU-Flex row and 3 rows whose official clock is
      // confirmed by the 2026-11-23 user decision, plus 216 restored rows.
      expect(added.where((c) => c.meetings.isNotEmpty), hasLength(324));
    },
  );
  test(
    'Native registration identity and actual excluded closures, never invented section',
    () {
      expect(raw['researchOnly'], false);
      expect(raw['completionClaim'], false);
      expect(courses, hasLength(3555));
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
            held.contains(c.code) &&
            !resolvedGeometry.containsKey(c.sourceId) &&
            // DU-Flex: the official timetable legend prints only the weekly
            // in-person 75 minutes, confirmed on 2026-11-23.
            !c.remarks.contains('DU-Flex 대면 시각 확정') &&
            // 2026-11-23 user decision: official weekday/clock is confirmed
            // even when the operation mode is unclear.
            !c.remarks.contains('공식 시각 확정(2026-11-23)'),
      )) {
        expect(c.meetings, isEmpty);
      }
      // Law notice 225363 (2026-09-03) moves 2204 to Friday 10:00-10:50 and
      // cancels the first September week.
      final career = courses.singleWhere((c) => c.code == '2204');
      expect(career.sourceSchedule, '수(12:00-12:50)');
      expect(career.meetings, hasLength(11));
      for (final m in career.meetings) {
        expect(
          [m.weekday, m.originalStartMinute, m.originalEndMinute],
          [5, 600, 650],
        );
        expect(m.date, isNot('2026-09-04'));
      }
      // The same notice moves law major 2165 to Tuesday 11:00-11:50.
      final lawCareer = courses.singleWhere((c) => c.code == '2165');
      expect(lawCareer.sourceSchedule, '수(12:00-12:50)');
      expect(lawCareer.meetings, hasLength(14));
      for (final m in lawCareer.meetings) {
        expect(
          [m.weekday, m.originalStartMinute, m.originalEndMinute],
          [2, 660, 710],
        );
      }
      // Courses whose official clock cell is blank stay without meetings and
      // are listed as unscheduled (2026-11-23 instruction); none stays held.
      for (final row in raw['courses'] as List) {
        expect(row['scheduleStatus'], isNot('unrecognized'));
        if ((row['sourceSchedule'] as String).trim().isEmpty) {
          expect(row['schedules'], isEmpty);
          expect(row['scheduleStatus'], 'unscheduled');
        }
      }
      // HUSS consortium courses are online with no weekly clock (notice 224170).
      final huss = courses.where(
        (c) => c.remarks.contains('HUSS_004/detail/224170'),
      );
      expect(huss, hasLength(21));
      for (final c in huss) {
        expect(c.meetings, isEmpty);
        expect(records[c.sourceId]['scheduleStatus'], 'unscheduled');
      }
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
        // A department notice clock replaces the printed clock (2204).
        final noticeClock = RegExp(r'공지 시각 (\S+\)),').firstMatch(c.remarks);
        final blocks = clock
            .allMatches(noticeClock?[1] ?? source['강의시간'] as String)
            .toList();
        final cancelled = RegExp(
          r'휴강 (\d{4}-\d{2}-\d{2})',
        ).allMatches(c.remarks).map((m) => m[1]).toSet();
        expect(blocks, isNotEmpty);
        final expected = <String>{};
        for (
          var day = DateTime(2026, 9, 1);
          !day.isAfter(DateTime(2026, 12, 7));
          day = DateTime(day.year, day.month, day.day + 1)
        ) {
          final date = timetableDateKey(day);
          if (holiday.contains(date) || cancelled.contains(date)) {
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
            final rooms = [
              for (final row in record['publicEducationRows'] as List)
                row['education']['강의실'] as String,
            ];
            if (c.remarks.contains('긴 표기로 통일')) {
              room = rooms.reduce((a, b) => b.length > a.length ? b : a);
              expect(
                rooms.every((r) => room.startsWith(r.split(' ').first)),
                true,
              );
              // Two rooms printed on two lines pair with the two clock lines.
              final parts = (room as String).split(' ');
              if (parts.length == blocks.length) {
                room = parts[blocks.indexOf(b)];
              }
            }
            final notice = RegExp(r'변경 강의실 (\S+)을').firstMatch(c.remarks);
            if (notice != null) {
              room = notice[1];
            }
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
      expect(count, 66117);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(3381));
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      'Actual 3381 model classes 66117 dates full Drive JSON roundtrip ${mode.name}',
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
        expect(values, hasLength(3381));
        expect(count, 66117);
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(3381));
        for (final c in restored.materializeClasses()) {
          expect(c.isValid, true);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      },
    );
  }
}
