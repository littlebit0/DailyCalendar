import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';

import 'korea_public_recheck.dart';

void main() {
  test(
    'KU current Sejong source clocks and dates preserve user modes through full Drive JSON',
    () {
      const root = 'work/university-research/catalog-r/ku/';
      final proof =
          jsonDecode(
                fixtureFile(
                  '${root}ku-sejong-current-educational-proof-v1.json',
                ).readAsStringSync(),
              )
              as Map;
      final cells = (proof['tables'] as List).single['cells'] as List;
      final sourceCells = {for (final c in cells) '${c['row']}/${c['col']}': c};
      final clockCells =
          proof['currentSejongClockGuide']['nativeTable']['cells'] as List;
      final clocks = <int, List<int>>{};
      expect(
        clockCells.where((dynamic c) => c['row'] == 3).single['paragraphs'],
        ['강의시간 (세종캠퍼스)'],
      );
      for (final c in clockCells.where(
        (dynamic c) => c['row'] >= 4 && c['col'] % 2 == 0,
      )) {
        final labels = c['paragraphs'] as List;
        if (labels.isEmpty) {
          continue;
        }
        final m = RegExp(r'^(\d+)교시$').firstMatch(labels.single as String);
        if (m == null) {
          continue;
        }
        final clock = clockCells
            .where(
              (dynamic x) => x['row'] == c['row'] && x['col'] == c['col'] + 1,
            )
            .single;
        final text = (clock['paragraphs'] as List).single as String;
        clocks[int.parse(m[1]!)] = text.split('-').map((s) {
          final parts = s.split(':');
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }).toList();
      }
      expect(clocks, hasLength(10));
      final calendar = (proof['calendars'] as List)
          .map((dynamic c) => c['nativeEducationalCalendarText'])
          .join(' ');
      expect(calendar, contains('09.01 2026학년도 제2학기 개강'));
      expect(calendar, contains('12.14 ~ 12.18 제2학기 기말고사'));
      expect(calendar, contains('12.18 제2학기 종강'));
      expect(calendar, contains('10.20 ~ 10.26 제2학기 중간고사'));
      expect(proof['midtermNotice']['nativeText'], contains('별도의 휴강 없이'));
      final raw =
          jsonDecode(
                fixtureFile(
                  'work/university-research/catalog-r/ku/current-public-sejong-followup-v8-20261009/baseline-sejong22-18-701.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      raw['researchOnly'] = false;
      final dataset = UniversityDataset.fromJson(raw);
      expect(raw['researchOnly'], isFalse);
      expect(raw['completionClaim'], isFalse);
      final scheduled = <UniversityCourse>[];
      var count = 0;
      for (var i = 0; i < dataset.courses.length; i++) {
        final c = dataset.courses[i];
        final r = (raw['courses'] as List)[i] as Map;
        final meta = r['metadata'] as Map;
        expect(c.code, isEmpty);
        expect(c.section, meta['nativeSection']);
        expect(c.sourceClassification, isEmpty);
        expect(c.campus, 'sejong');
        expect(meta['sourceCodePublished'], isFalse);
        expect(meta['actualAttendanceConfirmed'], isFalse);
        expect(meta['currentWholeClosureVerified'], isFalse);
        final native = meta['originalEducationalCells'] as List;
        for (final x in native) {
          final cell = x['nativeCell'] as Map;
          expect(cell, sourceCells['${cell['row']}/${cell['col']}']);
          expect(x['weekday'], cell['col']);
          expect(x['period'], cell['row']);
          expect(
            (cell['paragraphs'] as List).join(' '),
            contains(x['professor']),
          );
          expect(
            (cell['paragraphs'] as List).join(' '),
            contains(x['classroom']),
          );
        }
        if (!c.hasSchedulableMeetings) {
          expect(c.title, '창업과진로');
          expect(meta['heldReason'], contains('통합운영'));
          continue;
        }
        scheduled.add(c);
        final expected = <String>{};
        for (
          var date = DateTime(2026, 9, 1);
          !date.isAfter(DateTime(2026, 12, 13));
          date = DateTime(date.year, date.month, date.day + 1)
        ) {
          final day = date.toIso8601String().substring(0, 10);
          if ([
            '2026-09-24',
            '2026-09-25',
            '2026-09-26',
            '2026-10-03',
            '2026-10-05',
            '2026-10-09',
          ].contains(day)) {
            continue;
          }
          if (!date.isBefore(DateTime(2026, 10, 20)) &&
              !date.isAfter(DateTime(2026, 10, 26))) {
            continue;
          }
          for (final x in native.where(
            (dynamic x) => x['weekday'] == date.weekday,
          )) {
            final clock = clocks[x['period']]!;
            expected.add('$day/${clock[0]}/${clock[1]}/${x['classroom']}');
          }
        }
        final actual = <String>{};
        for (final m in c.meetings) {
          count++;
          final date = DateTime.parse(m.date!);
          expect(date.weekday, m.weekday);
          actual.add(
            '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
          );
          expect(
            (r['schedules'] as List).every(
              (dynamic x) => !(x as Map).containsKey('deliveryMode'),
            ),
            isTrue,
          );
        }
        expect(actual, expected);
        expect(actual, hasLength(c.meetings.length));
      }
      expect(dataset.courses, hasLength(22));
      expect(scheduled, hasLength(18));
      expect(count, 701);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(18));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          final prior = before[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, prior.note);
          expect(c.title, prior.title);
          expect(c.professor, prior.professor);
          expect(c.note, contains('공개 예약 계획, 실제 등교'));
          expect(c.note, contains('과목코드·학점·개설분반 이수구분은 미공개'));
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            prior.meetings.map((m) => m.toJson()).toList(),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );

  // 쉬는 시간 포함 슬롯(#564): 서울 1~6교시 75분+15분(90분), 7~10교시 50분+10분(60분),
  // 세종 50분+10분(60분). 근거 문서 미확인이라 현재 자료의 연속 교시 시작 간격을 쓴다.
  test('KU 교시 구간은 쉬는 시간을 포함한 슬롯이고 연속 교시는 합쳐져 있다', () {
    const slots = {
      'seoul': (
        [540, 630, 720, 810, 900, 990, 1080, 1140, 1200, 1260],
        [615, 705, 795, 885, 975, 1065, 1130, 1190, 1250, 1310],
        63797,
      ),
      'sejong': (
        [540, 600, 660, 720, 780, 840, 900, 960, 1020, 1080, 1140, 1200, 1260],
        [590, 650, 710, 770, 830, 890, 950, 1010, 1070, 1130, 1190, 1250, 1310],
        28166,
      ),
    };
    for (final entry in slots.entries) {
      final (starts, periodEnds, total) = entry.value;
      final data =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/korea-${entry.key}-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      var count = 0;
      for (final course in data['courses'] as List) {
        final groups = <String, List<Map>>{};
        for (final s in course['schedules'] as List) {
          count++;
          final start = s['startMinute'] as int;
          final end = s['endMinute'] as int;
          // 480은 서울 일반 0교시(08:00~08:50)로, 체육교육과 주말 4개 강좌(SAEK232·SAEK242
          // `토(0-1)`, SAEK334·SAEK434 `일(0-1)`)와 지리교육과 `토(0)` 3개 강좌(GEOG172·272·372,
          // 2026-11-23 확정)가 쓴다. 근거는 수강신청 교시표 사본
          // (source-current-ui-regular-campus-clock-education.json의 0교시 행)이다.
          // 교직 0교시 강좌 12개는 교직과목 0교시(08:40~) 원문으로 520에서 시작해 여기 오지 않는다.
          if (start == 480) continue;
          expect(
            starts.contains(start) && periodEnds.contains(end),
            isFalse,
            reason: '${course['sourceId']} ${s['date']} 쉬는 시간이 빠진 교시 구간',
          );
          groups.putIfAbsent('${s['date']}|${s['classroom']}', () => []).add(s);
        }
        for (final list in groups.values) {
          list.sort(
            (a, b) =>
                (a['startMinute'] as int).compareTo(b['startMinute'] as int),
          );
          for (var i = 1; i < list.length; i++) {
            expect(
              (list[i]['startMinute'] as int) -
                  (list[i - 1]['endMinute'] as int),
              greaterThanOrEqualTo(60),
              reason: '${course['sourceId']} ${list[i]['date']} 합치지 않은 연속 구간',
            );
          }
        }
      }
      expect(count, total, reason: entry.key);
    }
  });

  test('KU 2026-11-23 공식 교시표 확정 강좌는 원문 요일·교시 그대로 구간을 만든다', () {
    final byId = <String, Map<String, dynamic>>{};
    for (final campus in ['seoul', 'sejong']) {
      final data =
          jsonDecode(
                fixtureFile(
                  'assets/timetable/korea-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(
        data['periodEvidence']['sourceUrl'],
        'https://koreanstudies.korea.ac.kr/bbs/software/352/181231/download.do',
      );
      for (final c in data['courses'] as List) {
        byId[c['sourceId'] as String] = c as Map<String, dynamic>;
      }
    }
    final statuses = <String, int>{};
    for (final id in koreaOfficialTimes.keys) {
      final c = byId[id]!;
      final status = c['scheduleStatus'] as String;
      statuses[status] = (statuses[status] ?? 0) + 1;
      expect(
        c['schedules'],
        status == 'scheduled' ? koreaOfficialSchedules(c) : isEmpty,
        reason: id,
      );
      if (status == 'scheduled') {
        expect(c['remarks'], contains('공식 요일·교시 기준 확정'), reason: id);
        expect(c['remarks'], isNot(contains('일정 보류')), reason: id);
      } else {
        expect(c['remarks'], contains('원문 교시 표기를 보존한 채 시간 미정'), reason: id);
      }
    }
    expect(statuses, {'scheduled': 95, 'unscheduled': 6});

    // 교직 0교시는 08:40 시작, 1교시 시작(09:00)까지를 0교시 슬롯으로 보고 1교시와 합친다.
    final teaching = byId['korea/seoul/2026-2/SEDU101-01']!;
    expect(teaching['sourceSchedule'], '수(0-1) 교육관 501호');
    expect(
      {
        for (final s in teaching['schedules'] as List)
          (s['weekday'], s['startMinute'], s['endMinute'], s['classroom']),
      },
      {(3, 520, 630, '교육관 501호')},
    );

    // 서울 화(10-12): 10교시 21:00 시작, 표 밖 11·12교시는 60분 슬롯으로 이어 24:00까지.
    final lab = byId['korea/seoul/2026-2/KMSE302-01']!;
    expect(lab['sourceSchedule'], '화(10-12)');
    expect(
      {
        for (final s in lab['schedules'] as List)
          (s['weekday'], s['startMinute'], s['endMinute']),
      },
      {(2, 1260, 1440)},
    );
    // 같은 시각에 강의실이 둘이면 원문 강의실마다 구간을 둔다.
    final twoRooms = byId['korea/seoul/2026-2/ACEE232-00']!;
    expect(
      {
        for (final s in twoRooms['schedules'] as List)
          (s['weekday'], s['startMinute'], s['endMinute'], s['classroom']),
      },
      {
        (2, 720, 810, '신공학관 B105호'),
        (2, 720, 810, '신공학관 B109호-전산실습실'),
        (4, 720, 810, '신공학관 B105호'),
      },
    );
    // 세종 목9교시(17:00~17:50)는 분반별 강의실로 주간 반복 확정.
    final sejong = byId['korea/sejong/2026-2/spa-181339-t0-r9-c4-item20']!;
    expect(sejong['scheduleStatus'], 'scheduled');
    final first = (sejong['schedules'] as List).first as Map;
    expect(first, {
      'weekday': 4,
      'startMinute': 1020,
      'endMinute': 1080,
      'classroom': '2-329',
      'date': '2026-09-03',
    });
    // 24시를 넘는 교시 번호(약학과 토(8-17) 등)는 시각을 만들지 않고 원문을 보존한 시간 미정으로 둔다.
    final pharmacy = byId['korea/sejong/2026-2/PHAR528-00']!;
    expect(pharmacy['scheduleStatus'], 'unscheduled');
    expect(pharmacy['schedules'], isEmpty);
    expect(pharmacy['sourceSchedule'], contains('토(8-17)'));
  });

  test('KU 의학과 공개 강의계획서 첨부의 회차별 날짜·교시로 확정한 강좌', () {
    final data =
        jsonDecode(
              fixtureFile(
                'assets/timetable/korea-seoul-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final evidence =
        jsonDecode(
              fixtureFile(
                'tool/timetable/korea_medicine_sessions_2026_2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final byId = {
      for (final c in data['courses'] as List)
        c['sourceId'] as String: c as Map<String, dynamic>,
    };
    final courses = evidence['courses'] as Map<String, dynamic>;
    expect(courses, hasLength(15));
    for (final entry in courses.entries) {
      final c = byId[entry.key]!;
      expect(c['scheduleStatus'], 'scheduled', reason: entry.key);
      expect(c['sourceSchedule'], '', reason: entry.key);
      final period = c['period'] as Map;
      for (final s in c['schedules'] as List) {
        final date = s['date'] as String;
        expect(
          date.compareTo(period['startDate'] as String) >= 0 &&
              date.compareTo(period['endDate'] as String) <= 0,
          isTrue,
          reason: '${entry.key} $date',
        );
        expect(
          DateTime.parse(date).weekday,
          s['weekday'],
          reason: '${entry.key} $date',
        );
      }
    }
    // 응급의학: 11.24(화) 1·2교시, 11.27(금) 1~6교시, 12.7(월) 1~5교시, 12.10(목) 4·5교시.
    // 교시 슬롯은 50분+10분, 4교시 뒤 점심(50분)은 60분 미만이라 합친다.
    expect(
      [
        for (final s
            in byId['korea/seoul/2026-2/MEDI230-00']!['schedules'] as List)
          (s['date'], s['startMinute'], s['endMinute']),
      ],
      [
        ('2026-11-24', 510, 630),
        ('2026-11-27', 510, 920),
        ('2026-12-07', 510, 860),
        ('2026-12-10', 690, 860),
      ],
    );
    // 미생물학은 8월 24일 개강이라 강좌 기간 시작을 첫 회차로 넓혔다.
    final micro = byId['korea/seoul/2026-2/MEDI108-00']!;
    expect(micro['period']['startDate'], '2026-08-24');
    expect((micro['schedules'] as List).first, {
      'weekday': 1,
      'startMinute': 510,
      'endMinute': 630,
      'classroom': '',
      'date': '2026-08-24',
    });
  });
}
