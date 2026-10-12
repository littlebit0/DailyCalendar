import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-c/chosun-upper-theory-source-semantic-v5-20261009/';
  Map<String, dynamic> read(String path) {
    final actual = path;
    final data =
        jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
    if (data['courses'] is List) {
      data['researchOnly'] = false;
      for (final row in data['courses']) {
        if (row['metadata']?.containsKey('researchOnly') == true) {
          row['metadata']['researchOnly'] = false;
        }
      }
    }
    return data;
  }

  test(
    'all20 current theory cells exact native join, own semester bounds, prior115 full unchanged',
    () {
      final raw = read(
        '${root}chosun-unknown-2026-2.upper-theory-source-semantic-candidate-v5.json',
      );
      final prior = read('${root}baseline-v4-frozen.json');
      final native = read(
        '${root}current-nursing-educational-source-frozen.json',
      );
      final proof =
          jsonDecode(
                File(
                  '${root}independent-current-20-theory-semantic-proof.json',
                ).readAsStringSync(),
              )
              as List;
      expect(proof, hasLength(20));
      expect(
        native['sourceSHA256'],
        '33aeea14356f441115900f77709f5a84975134f65830b0d321c693cf08589e8b',
      );
      final byid = {
        for (final r in native['educationRows'] as List) r['sourceId']: r,
      };
      final old = {for (final c in prior['courses'] as List) c['sourceId']: c};
      final changed = {for (final p in proof) p['sourceId']: p};
      final courses = raw['courses'] as List;
      expect(courses, hasLength(135));
      expect(courses.map((c) => c['sourceId']).toSet(), old.keys.toSet());
      final own = read('${root}own-current-calendar-frozen.json');
      final events = own['educationalEvents'] as List;
      expect(
        events.any(
          (e) =>
              e['startDate'] == '2026-09-01' &&
              e['nativeTitle'] == '2학기 개강(2학기 개시)',
        ),
        true,
      );
      expect(
        events.any(
          (e) =>
              e['startDate'] == '2026-10-20' &&
              e['endDate'] == '2026-10-26' &&
              e['nativeTitle'] == '중간고사',
        ),
        true,
      );
      expect(
        events.any(
          (e) =>
              e['startDate'] == '2026-12-08' &&
              (e['nativeTitle'] as String).startsWith('[휴업일에 따른 수업일]'),
        ),
        true,
      );
      final holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-09-29',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      for (final c in courses) {
        final p = changed[c['sourceId']];
        if (p == null) {
          expect(c, old[c['sourceId']]);
          continue;
        }
        final before = old[c['sourceId']];
        final n = byid[c['sourceId']];
        expect(before['schedules'], isEmpty);
        expect(n['heldReasons'], [
          'upperGradeClinicalIntensiveDatesUnverified',
        ]);
        expect(p['nativeCellText'], n['nativeCellText']);
        expect(p['nativeTableRow'], n['nativeTableRow']);
        expect(p['nativeTableColumn'], n['nativeTableColumn']);
        expect(p['printedGroup']['nativeGradeLabel'], '${n['grade']}');
        expect(
          p['printedGroup']['nativeWeekdayLabel'],
          '월화수목금'[(n['weekday'] as int) - 1],
        );
        expect(
          c['sourceEducation']['nativePublicBlock'],
          before['sourceEducation']['nativePublicBlock'],
        );
        expect(c['courseName'], n['courseName']);
        expect(c['section'], n['section']);
        expect(c['professor'], n['professor']);
        expect(c['sourceClassroom'], n['classroom']);
        expect(c['courseCode'], '');
        expect(c['credits'], isNull);
        expect(c['classification'], '');
        expect(c['campus'], 'unknown');
        expect(c['departments'], ['간호학과 ${n['grade']}학년']);
        final start = n['firstHeader']['startMinute'] as int,
            end = n['lastHeader']['endMinute'] as int,
            day = n['weekday'] as int;
        expect(p['firstIndependentHeader']['startMinute'], start);
        expect(p['lastIndependentHeader']['endMinute'], end);
        expect(day == 3 && start < 780 && end > 720, false);
        final expected = <Map<String, dynamic>>[];
        for (
          var d = DateTime(2026, 9, 1);
          !d.isAfter(DateTime(2026, 12, 7));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if (d.weekday == day &&
              !holidays.contains(date) &&
              !(date.compareTo('2026-10-20') >= 0 &&
                  date.compareTo('2026-10-26') <= 0)) {
            expected.add({
              'date': date,
              'weekday': day,
              'startMinute': start,
              'endMinute': end,
              'classroom': n['classroom'],
            });
          }
        }
        expect(c['schedules'], expected);
        expect(c['period'], {
          'startDate': '2026-09-01',
          'endDate': '2026-12-07',
        });
      }
    },
  );
  test(
    'actual93/1097 prior73 preserved and all three user modes whole Drive JSON',
    () {
      final dataset = UniversityDataset.fromJson(
        read(
          '${root}chosun-unknown-2026-2.upper-theory-source-semantic-candidate-v5.json',
        ),
      );
      expect(dataset.courses, hasLength(135));
      final scheduled = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(scheduled, hasLength(93));
      expect(scheduled.fold<int>(0, (n, c) => n + c.meetings.length), 1097);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(93));
        final expected = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(
            c.toJson()..remove('id'),
            expected[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.meetings.every((m) => m.date != null), true);
        }
      }
    },
  );
}
