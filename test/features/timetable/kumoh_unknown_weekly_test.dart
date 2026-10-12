import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const root =
    'work/university-research/catalog-r/kumoh/unknown-campus-weekly-v2-20261008/';
Map<String, dynamic> readMap(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
void main() {
  final payload = readMap('assets/timetable/kumoh-unknown-2026-2.json');
  final rows = payload['courses'] as List;
  final baseline =
      readMap('${root}prior-packaged-unknown73-baseline.json')['courses']
          as List;
  final originals =
      jsonDecode(
            fixtureFile(
              'work/university-research/catalog-m/kumoh-current-educational-recheck-20261008.json',
            ).readAsStringSync(),
          )
          as List;
  final native = {for (final r in originals) r['SBJCT_CD_DCLSS']: r};
  final dataset = UniversityDataset.fromJson(payload);
  test('73 native metadata and 20 genuine holds preserved independently', () {
    expect(rows, hasLength(73));
    expect(
      dataset.courses.where((c) => c.hasSchedulableMeetings),
      hasLength(53),
    );
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i] as Map;
      final original =
          (row['metadata'] as Map)['originalEducationalFields'] as Map;
      expect(original, native['${row['courseCode']}-${row['section']}']);
      for (final key in [
        'sourceId',
        'campus',
        'courseCode',
        'section',
        'courseName',
        'credits',
        'professor',
        'classification',
        'sourceSchedule',
        'sourceClassroom',
        'period',
      ]) {
        expect(row[key], baseline[i][key]);
      }
      expect(row['campus'], 'unknown');
      if ((row['schedules'] as List).isEmpty) expect(row, baseline[i]);
    }
  });
  test('all2069 dates follow original day period room and own exclusions', () {
    var count = 0;
    const holidays = {
      '2026-09-24',
      '2026-09-25',
      '2026-09-26',
      '2026-10-03',
      '2026-10-05',
      '2026-10-09',
    };
    for (final dynamic row in rows) {
      if ((row['schedules'] as List).isEmpty) continue;
      final source = (row['metadata']['originalEducationalFields']) as Map;
      expect(source['LSN_OPER_MTHD_NM'], '대면수업');
      final geometries = <String>{};
      for (final part in (source['TIME_LCTRM_INFO'] as String).split(',')) {
        final match = RegExp(
          r'^([월화수목금토일])([0-9A-E]+)/(.+)$',
        ).firstMatch(part)!;
        final day = '월화수목금토일'.indexOf(match[1]!) + 1;
        for (final period in match[2]!.split('')) {
          final n = int.tryParse(period);
          final start = n == null
              ? 1080 + 'ABCDE'.indexOf(period) * 55
              : 480 + n * 60;
          geometries.add('$day|$start|${start + 50}|${match[3]}');
        }
      }
      final expected = <String>{};
      for (
        var date = DateTime(2026, 9, 1);
        !date.isAfter(DateTime(2026, 12, 7));
        date = date.add(const Duration(days: 1))
      ) {
        final iso = date.toIso8601String().substring(0, 10);
        if (holidays.contains(iso)) continue;
        for (final geometry in geometries) {
          if (geometry.startsWith('${date.weekday}|')) {
            expected.add('$iso|$geometry');
          }
        }
      }
      final actual = <String>{};
      for (final dynamic m in row['schedules']) {
        expect(m.containsKey('deliveryMode'), isFalse);
        actual.add(
          '${m['date']}|${m['weekday']}|${m['startMinute']}|${m['endMinute']}|${m['classroom']}',
        );
        count++;
      }
      expect(actual, expected);
      expect(actual.length, (row['schedules'] as List).length);
    }
    expect(count, 2069);
  });
  test('actual53 courses all three user modes and full Drive roundtrip', () {
    final schedulable = dataset.courses
        .where((c) => c.hasSchedulableMeetings)
        .toList();
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final classes = schedulable
          .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
          .toList();
      final doc = TimetableSyncDocument.legacy(
        courses: classes,
        termNames: {},
        activeYear: 2026,
        activeSemester: '2',
      );
      final encoded = doc.toJson();
      final restored = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>,
      ).materializeClasses();
      expect(restored, hasLength(53));
      expect(restored.map((c) => c.sourceId).toSet(), hasLength(53));
      expect(restored.fold<int>(0, (n, c) => n + c.meetings.length), 2069);
      final before = {for (final c in classes) c.sourceId: c};
      for (final c in restored) {
        expect(c.defaultMode, mode);
        expect(c.note, contains('물리 캠퍼스는 미확인'));
        expect(
          c.meetings.map((m) => m.toJson()).toList(),
          before[c.sourceId]!.meetings.map((m) => m.toJson()).toList(),
        );
        for (final m in c.meetings) {
          expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
        }
      }
    }
  });
}
