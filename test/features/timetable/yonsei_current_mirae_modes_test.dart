import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/yonsei-h2-published-mode-segments-v9-20261009';
dynamic read(String name) {
  final data = jsonDecode(File('$dir/$name').readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

const campuses = ['mirae'];
void main() {
  final bases = {
    for (final c in campuses) c: read('baseline-yonsei-$c-2026-2.json') as Map,
  };
  final datasets = {
    for (final c in campuses)
      c: read('yonsei-$c-2026-2.mode-segments-v9.json') as Map<String, dynamic>,
  };
  final all = datasets.values.expand((d) => d['courses'] as List).toList();
  final native =
      jsonDecode(
            File(
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
    'Own H2 mode legend83 native groups1664 literal dates including two exact75 clocks',
    () {
      final page = read('own-h2-current2026-2-mode-source.json');
      expect(
        sha256.convert(File(page['sourceFile']).readAsBytesSync()).toString(),
        page['sourcePDFSHA256'],
      );
      expect(page['H1GuideBorrowed'], false);
      expect(page['physicalPage'], 7);
      expect(page['actualPDFText'], contains('블렌디드 수업'));
      expect(page['actualPDFText'], contains('동영상콘텐츠'));
      expect(page['actualPDFText'], contains('100% 실시간강의'));
      final legend = read('current-mirae-official-legend.json');
      expect(legend['scope'], '<미래캠퍼스>');
      expect(legend['currentSemester'], '2026-2');
      expect(legend['literal'], contains('(월1) → 월요일 1교시 실습'));
      final changed = all.where((c) => c['partialCoverage'] == true).toList();
      expect(changed, hasLength(83));
      var total = 0, special = 0, practice = 0, fc = 0;
      for (final c in changed) {
        final e = c['sourceEducation'][0];
        expect(e['sysinstDivCd'], 'H2');
        expect(e['campsDivNm'], '미래');
        expect(c['courseCode'] == 'YHE1102', false);
        expect(c['publishedModeProof']['H1GuideBorrowed'], false);
        final ns = (native['records'] as List)
            .where(
              (r) =>
                  r['sysinstDivCd'] == 'H2' &&
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
            'atntnMattrDesc',
          ]) {
            expect(e[k], r[k]);
          }
          expect(r['rmvlcYn'], '0');
        }
        if ((e['atntnMattrDesc'] ?? '').contains('FC (')) fc++;
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
          if (['동영상(미래,중복수강가능)', '동영상(중복수강불가)'].contains(room)) {
            expect(seg['operation'], 'recordedVideoHeld');
            expect(seg['overlapPermitted'], room == '동영상(미래,중복수강가능)');
            expect(seg['timedReservationsGenerated'], false);
            expect(c['remarks'], contains(time));
            expect(c['remarks'], contains(room));
            continue;
          }
          expect(seg['operation'], 'inPerson');
          if ([
            'yonsei/H2/2026-2/MGT2007-03-00',
            'yonsei/H2/2026-2/MGT3013-01-00',
          ].contains(c['sourceId'])) {
            final org = c['courseCode'] == 'MGT2007';
            final start = org ? 660 : 960,
                end = org ? 735 : 1035,
                periods = org ? '3,4' : '8,9',
                raw = org ? '75분 수업(11:00-12:15)' : '75분 수업(16:00-17:15)';
            expect(group, 0);
            expect(time, org ? '화3,4' : '화8,9');
            expect(room, '정514');
            expect(e['atntnMattrDesc'], contains(raw));
            expect(seg['explicit75SourceHH'], raw);
            expect(seg['general50MinuteClockApplied'], false);
            expect(
              (c['publishedModeSegments'] as List).where(
                (s) => s['timedReservationsGenerated'] == true,
              ),
              hasLength(1),
            );
            for (final date in dates[2]!) {
              expected.add(
                '$date|2|$start|$end|정514|inPerson|$group|lecture|$periods',
              );
            }
            special++;
            continue;
          }
          final tg = <Map<String, String>>[], rg = <Map<String, String>>[];
          for (final target in [(time, tg), (room, rg)]) {
            final text = target.$1;
            var cursor = 0;
            for (final m in RegExp(r'\([^()]*\)').allMatches(text)) {
              if (m.start > cursor) {
                target.$2.add({
                  'kind': 'lecture',
                  'text': text.substring(cursor, m.start),
                });
              }
              target.$2.add({
                'kind': 'practice',
                'text': m[0]!.substring(1, m[0]!.length - 1),
              });
              cursor = m.end;
            }
            if (cursor < text.length) {
              target.$2.add({
                'kind': 'lecture',
                'text': text.substring(cursor),
              });
            }
          }
          expect(
            tg.map((g) => g['kind']).toList(),
            rg.map((g) => g['kind']).toList(),
          );
          for (var k = 0; k < tg.length; k++) {
            final t = tg[k]['text']!,
                where = rg[k]['text']!,
                kind = tg[k]['kind']!;
            final matches = RegExp(
              r'([월화수목금토])(\d+(?:,\d+)*)',
            ).allMatches(t).toList();
            expect(matches.map((m) => m[0]).join(','), t);
            for (final m in matches) {
              final wd = '월화수목금토'.indexOf(m[1]!) + 1;
              for (final period in m[2]!.split(',').map(int.parse)) {
                expect(clocks.containsKey(period), true);
                for (final date in dates[wd]!) {
                  expected.add(
                    '$date|$wd|${clocks[period]![0]}|${clocks[period]![1]}|$where|inPerson|$group|$kind|$period',
                  );
                  if (kind == 'practice') practice++;
                }
              }
            }
          }
        }
        final actual = <String>{};
        for (final s in c['schedules']) {
          expect(DateTime.parse(s['date']).weekday, s['weekday']);
          final ps = (s['sourcePeriods'] ?? [s['sourcePeriod']]) as List;
          actual.add(
            '${s['date']}|${s['weekday']}|${s['startMinute']}|${s['endMinute']}|${s['classroom']}|${s['deliveryMode']}|${s['sourceGroupIndex']}|${s['sourceGroupKind']}|${ps.join(',')}',
          );
        }
        expect(actual, expected);
        expect(actual.length, (c['schedules'] as List).length);
        total += actual.length;
      }
      expect(total, 1664);
      expect(special, 2);
      expect(practice, 13);
      expect(fc, 54);
    },
  );
  test(
    'All1135 otherwhole objects and prior911whole33308 meetings preserved',
    () {
      var unchanged = 0, priorCourses = 0, priorPlans = 0;
      for (final b in bases['mirae']!['courses']) {
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
      expect(unchanged, 1135);
      expect(priorCourses, 911);
      expect(priorPlans, 33308);
    },
  );
  test(
    'All994 actual models34972 meetings three defaults andfullDrive v2 roundtrip',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        var total = 0;
        for (final c in UniversityDataset.fromJson(
          datasets['mirae']!,
        ).courses) {
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
        expect(total, 34972);
        expect(values, hasLength(994));
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
        expect(restored, hasLength(994));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          expect(c.isValid, true);
        }
      }
    },
  );
}
