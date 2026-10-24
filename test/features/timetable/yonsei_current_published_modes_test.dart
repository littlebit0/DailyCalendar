// Historical frozen-source packet regression. Latest packaged sources are
// checked by packaged_asset_source_integrity_test and resumed_batch_changed_courses_test.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/yonsei-h1-published-mode-segments-v8-20261009';
dynamic read(String name) {
  final actual = '$dir/$name';
  final data = jsonDecode(fixtureFile(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

const campuses = ['sinchon', 'international', 'mirae', 'unknown'];
void main() {
  final bases = {
    for (final c in campuses) c: read('baseline-yonsei-$c-2026-2.json') as Map,
  };
  final datasets = {
    for (final c in campuses)
      c: read('yonsei-$c-2026-2.mode-segments-v8.json') as Map<String, dynamic>,
  };
  final all = datasets.values.expand((d) => d['courses'] as List).toList();
  final native =
      jsonDecode(
            fixtureFile(
              'work/university-research/catalog-d/yonsei-2026-2-public-all.json',
            ).readAsStringSync(),
          )
          as Map;
  const dates = <int, List<String>>{
    1: [
      '2026-09-07',
      '2026-09-14',
      '2026-09-21',
      '2026-09-28',
      '2026-10-12',
      '2026-10-19',
      '2026-11-02',
      '2026-11-09',
      '2026-11-16',
      '2026-11-23',
      '2026-11-30',
      '2026-12-07',
    ],
    2: [
      '2026-09-01',
      '2026-09-08',
      '2026-09-15',
      '2026-09-22',
      '2026-09-29',
      '2026-10-06',
      '2026-10-13',
      '2026-10-27',
      '2026-11-03',
      '2026-11-10',
      '2026-11-17',
      '2026-11-24',
      '2026-12-01',
    ],
    3: [
      '2026-09-02',
      '2026-09-09',
      '2026-09-16',
      '2026-09-23',
      '2026-09-30',
      '2026-10-07',
      '2026-10-14',
      '2026-10-28',
      '2026-11-04',
      '2026-11-11',
      '2026-11-18',
      '2026-11-25',
      '2026-12-02',
    ],
    4: [
      '2026-09-03',
      '2026-09-10',
      '2026-09-17',
      '2026-10-01',
      '2026-10-08',
      '2026-10-15',
      '2026-10-29',
      '2026-11-05',
      '2026-11-12',
      '2026-11-19',
      '2026-11-26',
      '2026-12-03',
    ],
    5: [
      '2026-09-04',
      '2026-09-11',
      '2026-09-18',
      '2026-10-02',
      '2026-10-16',
      '2026-10-30',
      '2026-11-06',
      '2026-11-13',
      '2026-11-20',
      '2026-11-27',
      '2026-12-04',
    ],
  };
  const clocks = <int, List<int>>{
    0: [480, 530],
    1: [540, 590],
    2: [600, 650],
    3: [660, 710],
    4: [720, 770],
    5: [780, 830],
    6: [840, 890],
    7: [900, 950],
    8: [960, 1010],
    9: [1020, 1070],
    10: [1080, 1130],
  };
  test(
    'Own H1 guide and359 native exact-index mode groups6607 independent literal dates',
    () {
      final page = read('own-h1-2026-2-mode-page7-source.json') as Map;
      expect(
        sha256
            .convert(fixtureFile(page['sourceFile']).readAsBytesSync())
            .toString(),
        page['sourcePDFSHA256'],
      );
      expect(page['physicalPage'], 7);
      expect(page['actualPDFText'], contains('대면수업'));
      expect(page['actualPDFText'], contains('실시간온라인'));
      expect(page['actualPDFText'], contains('동영상콘텐츠'));
      expect(page['actualPDFText'], contains('중복하여 수강 가능'));
      expect(native['capped'], isEmpty);
      expect(native['scopes'], hasLength(329));
      final changed = all.where((c) => c['partialCoverage'] == true).toList();
      expect(changed, hasLength(359));
      var total = 0;
      for (final c in changed) {
        final e = c['sourceEducation'][0];
        expect(e['sysinstDivCd'], 'H1');
        expect(c['courseCode'].startsWith('UCR'), false);
        expect(c['publishedModeProof']['H2LegendBorrowed'], false);
        final ns = (native['records'] as List)
            .where(
              (r) =>
                  r['sysinstDivCd'] == 'H1' &&
                  r['subjtnbCorsePrcts'] == e['subjtnbCorsePrcts'],
            )
            .toList();
        expect(ns, isNotEmpty);
        for (final r in ns) {
          for (final k in [
            'lctreTimeNm',
            'lecrmNm',
            'subjtClNm',
            'lessnSessnDivNm',
            'cgprfNm',
            'rmvlcYn',
          ]) {
            expect(e[k], r[k]);
          }
          expect(r['rmvlcYn'], '0');
        }
        final times = (c['sourceSchedule'] as String).split('/'),
            rooms = (c['sourceClassroom'] as String).split('/');
        expect(times.length, rooms.length);
        expect(c['publishedModeSegments'], hasLength(times.length));
        final expected = <String>{};
        for (var group = 0; group < times.length; group++) {
          final time = times[group],
              room = rooms[group],
              seg = c['publishedModeSegments'][group];
          expect(seg['index'], group);
          expect(seg['nativeTime'], time);
          expect(seg['nativeRoom'], room);
          if (['동영상콘텐츠', '동영상(중복수강불가)'].contains(room)) {
            expect(seg['operation'], 'recordedVideoHeld');
            expect(seg['overlapPermitted'], room == '동영상콘텐츠');
            expect(seg['timedReservationsGenerated'], false);
            expect(c['remarks'], contains(time));
            expect(c['remarks'], contains(room));
            continue;
          }
          if (time.contains('(') ||
              time.contains(')') ||
              room.contains('(') ||
              room.contains(')') ||
              room.isEmpty ||
              ['미정', '미배정', '동영상', '콘텐츠'].any(room.contains)) {
            expect(seg['operation'], 'unconfirmedHeld');
            continue;
          }
          final matches = RegExp(
            r'([월화수목금토])(\d+(?:,\d+)*)',
          ).allMatches(time).toList();
          final periods = matches
              .expand((m) => m[2]!.split(',').map(int.parse))
              .toList();
          if (matches.map((m) => m[0]).join(',') != time ||
              matches.isEmpty ||
              periods.any((p) => !clocks.containsKey(p))) {
            expect(seg['operation'], 'unconfirmedHeld');
            continue;
          }
          final mode = room == '실시간온라인' ? 'liveOnline' : 'inPerson';
          expect(seg['operation'], mode);
          for (final m in matches) {
            final wd = '월화수목금토'.indexOf(m[1]!) + 1;
            for (final period in m[2]!.split(',').map(int.parse)) {
              for (final date in dates[wd]!) {
                expected.add(
                  '$date|$wd|${clocks[period]![0]}|${clocks[period]![1]}|$room|$mode|$group|$period',
                );
              }
            }
          }
        }
        final actual = <String>{};
        for (final s in c['schedules']) {
          expect(DateTime.parse(s['date']).weekday, s['weekday']);
          actual.add(
            '${s['date']}|${s['weekday']}|${s['startMinute']}|${s['endMinute']}|${s['classroom']}|${s['deliveryMode']}|${s['sourceGroupIndex']}|${s['sourcePeriod']}',
          );
        }
        expect(actual, expected);
        expect(actual.length, (c['schedules'] as List).length);
        total += actual.length;
      }
      expect(total, 6607);
    },
  );
  test(
    'All4351 other objects and2722 prior whole97066 schedules preserved; two campuses bytes equal',
    () {
      var unchanged = 0, priorCourses = 0, priorPlans = 0;
      for (final campus in campuses) {
        for (final b in bases[campus]!['courses']) {
          final c = all.singleWhere((c) => c['sourceId'] == b['sourceId']);
          if (c['partialCoverage'] != true) {
            expect(c, b);
            unchanged++;
            if ((b['schedules'] as List).isNotEmpty) {
              priorCourses++;
              priorPlans += (b['schedules'] as List).length;
            }
            continue;
          }
          expect(b['schedules'], isEmpty);
          for (final k in (b as Map).keys) {
            if (![
              'schedules',
              'scheduleStatus',
              'remarks',
              'departmentRemarks',
            ].contains(k)) {
              expect(c[k], b[k]);
            }
          }
          expect(c['priorHeldResearchRemarks'], b['remarks']);
          expect(c['priorHeldDepartmentRemarks'], b['departmentRemarks']);
          expect(c['sourceEducation'], b['sourceEducation']);
        }
      }
      expect(unchanged, 4351);
      expect(priorCourses, 2722);
      expect(priorPlans, 97066);
      for (final campus in ['mirae', 'unknown']) {
        expect(
          fixtureFile(
            '$dir/yonsei-$campus-2026-2.mode-segments-v8.json',
          ).readAsBytesSync(),
          fixtureFile(
            '$dir/baseline-yonsei-$campus-2026-2.json',
          ).readAsBytesSync(),
        );
      }
    },
  );
  test(
    'All3081 actual courses103673 meetings three user defaults and completeDrive v2 roundtrip',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        var total = 0;
        for (final dataset in datasets.values) {
          for (final c in UniversityDataset.fromJson(dataset).courses) {
            final plans =
                all.singleWhere((v) => v['sourceId'] == c.sourceId)['schedules']
                    as List;
            if (plans.isEmpty) continue;
            final saved = c.toTimetable(id: c.sourceId, mode: mode);
            expect(saved.note, c.remarks);
            expect(saved.isValid, true);
            expect(saved.defaultMode, mode);
            expect(saved.meetings, hasLength(plans.length));
            for (var i = 0; i < plans.length; i++) {
              final m = saved.meetings[i], p = plans[i];
              expect(m.date, p['date']);
              expect(m.weekday, p['weekday']);
              expect(m.originalStartMinute, p['startMinute']);
              expect(m.originalEndMinute, p['endMinute']);
              expect(m.classroom, p['classroom']);
              final forced = switch (p['deliveryMode']) {
                'inPerson' => LectureMode.inPerson,
                'liveOnline' => LectureMode.liveOnline,
                _ => mode,
              };
              expect(saved.modeOn(m, m.teachingDate!), forced);
              expect(saved.period!.contains(m.teachingDate!), true);
              total++;
            }
            final key = timetableCourseSyncKey(saved);
            expect(values.containsKey(key), false);
            values[key] = TimetableSyncValue(
              {...saved.toJson(), 'id': key},
              DateTime.utc(2026, 10, 9),
              'research',
            );
          }
        }
        expect(total, 103673);
        expect(values, hasLength(3081));
        final document =
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
          document,
        ).materializeClasses();
        expect(restored, hasLength(3081));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          expect(c.isValid, true);
        }
      }
    },
  );
}
