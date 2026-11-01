import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-c/ordinary-weekly-held-audit-20261008';
// Historical v1 source proof; current assets are verified by khu_current_ordinary_test.
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
void main() {
  final audit = read('$folder/khu-ordinary-reservation-v1-audit.json');
  final raws = [
    for (final d in audit['datasets']) read('$folder/${d['file']}'),
  ];
  final models = raws.map(UniversityDataset.fromJson).toList();
  final courses = models.expand((d) => d.courses).toList();
  final changed = {for (final p in audit['proofs']) p['sourceId']: p};
  test(
    'all 4666 native offerings; existing 50 and every held field unchanged',
    () {
      expect(courses, hasLength(4666));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(4666));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(556));
      expect(courses.expand((c) => c.meetings), hasLength(12165));
      expect(changed, hasLength(506));
      for (final d in audit['datasets']) {
        final path = '$folder/${d['file']}';
        expect(
          sha256.convert(fixtureFile(path).readAsBytesSync()).toString(),
          d['sha256'],
        );
        final campus = read(path)['campus'];
        final basePath = '$folder/baseline-khu-$campus-2026-2.json';
        expect(
          sha256.convert(fixtureFile(basePath).readAsBytesSync()).toString(),
          d['baselineSHA256'],
        );
        final base = read(basePath)['courses'] as List;
        final current = read(path)['courses'] as List;
        for (var i = 0; i < base.length; i++) {
          expect(current[i]['sourceId'], base[i]['sourceId']);
          if (!changed.containsKey(base[i]['sourceId'])) {
            expect(current[i], base[i]);
          } else {
            final copied = Map<String, dynamic>.from(current[i] as Map);
            copied.remove('reservationEvidence');
            copied['scheduleStatus'] = base[i]['scheduleStatus'];
            copied['schedules'] = base[i]['schedules'];
            copied['departmentRemarks'] = base[i]['departmentRemarks'];
            expect(copied, base[i]);
          }
        }
      }
      expect(
        courses
            .singleWhere((c) => c.codeAndSection == 'ECON2043-00')
            .hasSchedulableMeetings,
        false,
      );
    },
  );
  test(
    'every new meeting independently matches native clock, room, campus and source exceptions',
    () {
      final pattern = RegExp(
        r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)',
      );
      for (final course in courses.where(
        (c) => changed.containsKey(c.sourceId),
      )) {
        final proof = changed[course.sourceId];
        expect(proof['screenReasons'], isEmpty);
        expect(course.campus, proof['campus']);
        final slots = pattern
            .allMatches(proof['sourceSchedule'] as String)
            .toList();
        for (final p in proof['planProofs']) {
          expect(
            sha256.convert(fixtureFile(p['file']).readAsBytesSync()).toString(),
            p['sha256'],
          );
          final source = read(p['file']);
          expect(source['header'], ['2026학년도 2학기 강의계획서']);
          expect(p['selectedSpecialRows'], isEmpty);
        }
        for (final m in course.meetings) {
          expect(
            slots.any(
              (s) =>
                  '월화수목금토일'.indexOf(s[1]!) + 1 == m.weekday &&
                  int.parse(s[2]!) * 60 + int.parse(s[3]!) ==
                      m.originalStartMinute &&
                  int.parse(s[4]!) * 60 + int.parse(s[5]!) ==
                      m.originalEndMinute &&
                  s[6]!.trim() == m.classroom,
            ),
            true,
          );
          final date = DateTime.parse(m.date!);
          expect(date.weekday, m.weekday);
          expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
          expect(m.date!.compareTo('2026-12-21'), lessThanOrEqualTo(0));
          expect([
            '2026-09-24',
            '2026-09-25',
            '2026-09-26',
            '2026-10-03',
            '2026-10-05',
            '2026-10-09',
          ], isNot(contains(m.date)));
          expect(
            m.date!.compareTo('2026-10-20') >= 0 &&
                m.date!.compareTo('2026-10-26') <= 0,
            false,
          );
          expect(m.date!.compareTo('2026-12-15') >= 0, false);
          for (final exception in proof['sourceExceptionRanges']) {
            final range = exception['reservationExcludedRange'];
            expect(
              m.date!.compareTo(range[0]) >= 0 &&
                  m.date!.compareTo(range[1]) <= 0,
              false,
            );
          }
        }
      }
    },
  );
  test(
    'three actual modes and entire Drive schema 2 document preserve every field',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
          final t = c.toTimetable(id: c.sourceId, mode: mode);
          expect(t.isValid, true);
          expect(t.defaultMode, mode);
          final key = timetableCourseSyncKey(t);
          values[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(values, hasLength(556));
        final original = TimetableSyncDocument.records(courses: values);
        final decoded = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
        );
        expect(decoded.toJson(), original.toJson());
        for (final entry in values.entries) {
          expect(decoded.courses[entry.key]!.value, entry.value.value);
        }
      }
    },
  );
}
