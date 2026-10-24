// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-e/nsu-two-images-semester-v2-20261009';
Map<String, dynamic> read(String name) {
  final path = name == 'nsu-unknown-2026-2.two-images-semester-v2.json'
      ? 'work/university-research/resume-batch-20261010/before-projection/nsu-unknown-2026-2.json'
      : '$dir/$name';
  final data =
      jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  final raw = read('nsu-unknown-2026-2.two-images-semester-v2.json');
  final base = read('baseline39-current-asset.json') as Map;
  final annotation = read('visual-image-literal-items.json') as Map;
  final proof = read('literal-semester-source-proof.json') as Map;
  final model = UniversityDataset.fromJson(raw);
  const dates = <int, List<String>>{
    1: [
      '2026-08-31',
      '2026-09-07',
      '2026-09-14',
      '2026-09-21',
      '2026-09-28',
      '2026-10-12',
      '2026-10-19',
      '2026-10-26',
      '2026-11-02',
      '2026-11-09',
      '2026-11-16',
      '2026-11-23',
      '2026-11-30',
      '2026-12-07',
      '2026-12-14',
    ],
    2: [
      '2026-09-01',
      '2026-09-08',
      '2026-09-15',
      '2026-09-22',
      '2026-09-29',
      '2026-10-06',
      '2026-10-13',
      '2026-10-20',
      '2026-10-27',
      '2026-11-03',
      '2026-11-10',
      '2026-11-17',
      '2026-11-24',
      '2026-12-01',
      '2026-12-08',
      '2026-12-15',
    ],
    3: [
      '2026-09-02',
      '2026-09-09',
      '2026-09-16',
      '2026-09-23',
      '2026-09-30',
      '2026-10-07',
      '2026-10-14',
      '2026-10-21',
      '2026-10-28',
      '2026-11-04',
      '2026-11-11',
      '2026-11-18',
      '2026-11-25',
      '2026-12-02',
      '2026-12-09',
      '2026-12-16',
    ],
    4: [
      '2026-09-03',
      '2026-09-10',
      '2026-09-17',
      '2026-10-01',
      '2026-10-08',
      '2026-10-15',
      '2026-10-22',
      '2026-10-29',
      '2026-11-05',
      '2026-11-12',
      '2026-11-19',
      '2026-11-26',
      '2026-12-03',
      '2026-12-10',
      '2026-12-17',
    ],
    5: [
      '2026-09-04',
      '2026-09-11',
      '2026-09-18',
      '2026-10-02',
      '2026-10-16',
      '2026-10-23',
      '2026-10-30',
      '2026-11-06',
      '2026-11-13',
      '2026-11-20',
      '2026-11-27',
      '2026-12-04',
      '2026-12-11',
      '2026-12-18',
    ],
  };
  test('Native source image58 items41 clear and closure BIM02 held', () {
    expect(model.courses, hasLength(97));
    expect(annotation['items'], hasLength(58));
    expect(
      (raw['courses'] as List).where(
        (c) => (c['schedules'] as List).isNotEmpty,
      ),
      hasLength(76),
    );
    var imagePlans = 0;
    for (final c in (raw['courses'] as List).skip(39)) {
      final a = (annotation['items'] as List).singleWhere(
        (v) => v['sourceId'] == c['sourceId'],
      );
      expect(c['publicImageEducation'], a);
      expect(c['courseName'], a['courseName']);
      expect(c['professor'], a['professor']);
      expect(c['section'], a['section']);
      expect(c['courseCode'], '');
      expect(c['credits'], null);
      expect(c['classification'], '');
      expect(c['campus'], 'unknown');
      final image = a['noticeId'] == 102907
          ? 'notice-102907-file0.jpg'
          : 'notice-103190-image0.png';
      expect(
        sha256.convert(fixtureFile('$dir/$image').readAsBytesSync()).toString(),
        c['sourceImageSHA256'],
      );
      if ((c['schedules'] as List).isEmpty) continue;
      final expected = <String>{};
      for (final date in dates[a['weekday']]!) {
        for (final p in a['periods']) {
          // Source images directly print periods1-9 / periods2-9 with these HH.
          const clocks = <int, List<int>>{
            1: [540, 590],
            2: [600, 650],
            3: [660, 710],
            4: [720, 770],
            5: [780, 830],
            6: [840, 890],
            7: [900, 950],
            8: [960, 1010],
            9: [1020, 1070],
          };
          expected.add(
            '$date|${a['weekday']}|${clocks[p]![0]}|${clocks[p]![1]}|${a['room']}|$p|${a['periodProfessors']['$p']}',
          );
        }
      }
      final actual = <String>{};
      for (final s in c['schedules']) {
        expect(DateTime.parse(s['date']).weekday, s['weekday']);
        expect(s['sourceGrade'], a['grade']);
        actual.add(
          '${s['date']}|${s['weekday']}|${s['startMinute']}|${s['endMinute']}|${s['classroom']}|${s['sourcePeriod']}|${s['sourceProfessor']}',
        );
      }
      expect(actual, expected);
      expect(actual.length, (c['schedules'] as List).length);
      imagePlans += actual.length;
    }
    expect(imagePlans, 1978);
    final bim = (raw['courses'] as List).singleWhere(
      (c) =>
          c['sourceNoticeId'] == 102907 &&
          c['courseName'] == 'BIM및실습' &&
          c['section'] == '02',
    );
    expect(bim['schedules'], isEmpty);
    expect(bim['closureExactTitleSectionTeacherMatches'], hasLength(1));
    expect(
      bim['closureExactTitleSectionTeacherMatches'][0]['courseCode'],
      '14712',
    );
    expect(bim['courseCode'], '');
  });
  test(
    'Prior39 fields255 objects preserved and35 expanded1687 through own16weeks',
    () {
      var plans = 0;
      for (final b in base['courses']) {
        final c = (raw['courses'] as List).singleWhere(
          (v) => v['sourceId'] == b['sourceId'],
        );
        for (final k in (b as Map).keys) {
          if (!['schedules', 'period', 'remarks'].contains(k)) {
            expect(c[k], b[k]);
          }
        }
        expect(
          (c['schedules'] as List)
              .take((b['schedules'] as List).length)
              .toList(),
          b['schedules'],
        );
        if ((b['schedules'] as List).isEmpty) {
          expect(c['schedules'], isEmpty);
          continue;
        }
        final expected = <String>{};
        final periods = (read('nsu-clock-evidence.json')['periods'] as List);
        for (final r in c['publicEducationCells']) {
          final clock = periods.singleWhere((v) => v['period'] == r['period']);
          for (final date in dates[r['weekday']]!) {
            expected.add(
              '$date|${r['weekday']}|${clock['startMinutes']}|${clock['endMinutes']}|${r['room']}|${r['row']}|${r['column']}',
            );
          }
        }
        final actual = <String>{};
        for (final s in c['schedules']) {
          actual.add(
            '${s['date']}|${s['weekday']}|${s['startMinute']}|${s['endMinute']}|${s['classroom']}|${s['sourceRow']}|${s['sourceColumn']}',
          );
        }
        expect(actual, expected);
        plans += actual.length;
        expect(c['period'], {
          'startDate': '2026-08-31',
          'endDate': '2026-12-19',
        });
      }
      expect(plans, 1687);
      expect(proof['makeupMappingsUnverifiedGenerated0'], true);
      expect(raw['completionClaim'], false);
    },
  );
  test(
    'All76 scheduled3665 actual models three modes fullDrive v2 roundtrip',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in model.courses) {
          final plans =
              (raw['courses'] as List).singleWhere(
                    (v) => v['sourceId'] == c.sourceId,
                  )['schedules']
                  as List;
          if (plans.isEmpty) continue;
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.meetings, hasLength(plans.length));
          for (var i = 0; i < plans.length; i++) {
            final m = saved.meetings[i], p = plans[i];
            expect(m.date, p['date']);
            expect(m.weekday, p['weekday']);
            expect(m.originalStartMinute, p['startMinute']);
            expect(m.originalEndMinute, p['endMinute']);
            expect(m.classroom, p['classroom']);
            expect(saved.modeOn(m, m.teachingDate!), mode);
            expect(saved.period!.contains(m.teachingDate!), true);
            count++;
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        expect(count, 3665);
        expect(values, hasLength(76));
        final encoded =
            jsonDecode(
                  jsonEncode(
                    TimetableSyncDocument.records(
                      courses: values,
                      schemaVersion: 2,
                    ).toJson(),
                  ),
                )
                as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          encoded,
        ).materializeClasses();
        expect(restored, hasLength(76));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          expect(c.isValid, true);
        }
      }
    },
  );
}
