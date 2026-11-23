import 'dart:convert';
import 'dart:io';

/// 2026-10-23 공개 개설과목 재조회 결과(교수·강좌명 변경)를 이전 검토본에 덮어
/// 현재 자산과 비교할 수 있게 한다.
final Map<String, dynamic> koreaPublicRecheck =
    jsonDecode(
          File(
            'test/fixtures/korea_timetable_public_recheck_20261023.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

final Map<String, List<Map<String, dynamic>>> _changes = () {
  final byId = <String, List<Map<String, dynamic>>>{};
  for (final change in koreaPublicRecheck['changes'] as List) {
    final record = change as Map<String, dynamic>;
    byId.putIfAbsent(record['sourceId'] as String, () => []).add(record);
  }
  return byId;
}();

// 쉬는 시간 포함 슬롯(#564). 서울 1~6교시 75분+15분, 7~10교시 50분+10분, 세종 50분+10분.
// 근거 문서 미확인: 현재 자료의 연속 교시 시작 간격으로 만든다. 그래서 이 표를 쓰는
// 검사는 원문 대조가 아니라 자료 안의 자기 일관성 검사다(#948).
const koreaSlotStarts = {
  'seoul': [540, 630, 720, 810, 900, 990, 1080, 1140, 1200, 1260],
  'sejong': [
    540,
    600,
    660,
    720,
    780,
    840,
    900,
    960,
    1020,
    1080,
    1140,
    1200,
    1260,
  ],
};
const koreaSlotPeriodEnds = {
  'seoul': [615, 705, 795, 885, 975, 1065, 1130, 1190, 1250, 1310],
  'sejong': [
    590,
    650,
    710,
    770,
    830,
    890,
    950,
    1010,
    1070,
    1130,
    1190,
    1250,
    1310,
  ],
};
const koreaSlotEnds = {
  'seoul': [630, 720, 810, 900, 990, 1080, 1140, 1200, 1260, 1320],
  'sejong': [
    600,
    660,
    720,
    780,
    840,
    900,
    960,
    1020,
    1080,
    1140,
    1200,
    1260,
    1320,
  ],
};
const koreaOldBreakRemark = '교시 사이의 공표 휴식은 합치지 않았습니다';
const koreaNewBreakRemark =
    '교시는 다음 교시 시작까지(쉬는 시간 포함)를 한 슬롯으로 보고 같은 강의실의 연속 교시는 한 구간으로 합쳤습니다';

/// 교시 구간을 슬롯 끝으로 늘리고 같은 날짜·요일·강의실에서 간격 60분 미만인 구간을 합친다.
/// 시계 시각 구간과 0교시(08:00 시작)는 늘리지도 합치지도 않는다.
List<Map<String, dynamic>> koreaSlotSchedules(
  String campus,
  List<Map<String, dynamic>> schedules,
) {
  final starts = koreaSlotStarts[campus]!;
  final periodEnds = koreaSlotPeriodEnds[campus]!;
  final slotEnds = koreaSlotEnds[campus]!;
  final copies = [for (final s in schedules) Map<String, dynamic>.from(s)];
  for (final s in copies) {
    final startIndex = starts.indexOf(s['startMinute'] as int);
    final endIndex = periodEnds.indexOf(s['endMinute'] as int);
    if (startIndex >= 0 && endIndex >= startIndex) {
      s['endMinute'] = slotEnds[endIndex];
    }
  }
  final groups = <String, List<Map<String, dynamic>>>{};
  var unique = 0;
  for (final s in copies) {
    final key = s['startMinute'] == 480
        ? 'keep${unique++}'
        : '${s['date']}|${s['weekday']}|${s['classroom']}';
    groups.putIfAbsent(key, () => []).add(s);
  }
  final out = <Map<String, dynamic>>[];
  for (final group in groups.values) {
    final indexed = [for (var i = 0; i < group.length; i++) (i, group[i])]
      ..sort((a, b) {
        final c = (a.$2['startMinute'] as int).compareTo(
          b.$2['startMinute'] as int,
        );
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    var current = indexed.first.$2;
    for (final (_, next) in indexed.skip(1)) {
      if ((next['startMinute'] as int) - (current['endMinute'] as int) < 60) {
        final end = next['endMinute'] as int;
        if (end > (current['endMinute'] as int)) current['endMinute'] = end;
      } else {
        out.add(current);
        current = next;
      }
    }
    out.add(current);
  }
  return out;
}

String koreaFixRemark(String remarks) =>
    remarks.replaceAll(koreaOldBreakRemark, koreaNewBreakRemark);

Map<String, dynamic> _applyKoreaSlots(Map<String, dynamic> course) {
  final copy = jsonDecode(jsonEncode(course)) as Map<String, dynamic>;
  final remarks = copy['remarks'];
  if (remarks is String) copy['remarks'] = koreaFixRemark(remarks);
  final schedules = copy['schedules'] as List?;
  if (schedules != null && schedules.isNotEmpty) {
    copy['schedules'] = koreaSlotSchedules(copy['campus'] as String, [
      for (final s in schedules) s as Map<String, dynamic>,
    ]);
  }
  return copy;
}

/// 2026-11-23 공식 교시표 확정(tool/timetable/apply_korea_official_times.py) 기록.
final Map<String, Map<String, dynamic>> koreaOfficialTimes = {
  for (final r
      in (jsonDecode(
                File(
                  'test/fixtures/korea_official_times_20261123.json',
                ).readAsStringSync(),
              )
              as Map)['records']
          as List)
    (r as Map<String, dynamic>)['sourceId'] as String: r,
};

const _koreaWeekdays = '월화수목금토일';
const _koreaExcludedDates = {
  '2026-09-24', '2026-09-25', '2026-09-26', '2026-10-03', '2026-10-05', //
  '2026-10-09', '2026-10-20', '2026-10-21', '2026-10-22', '2026-10-23',
  '2026-10-24', '2026-10-25', '2026-10-26', '2026-12-14', '2026-12-15',
  '2026-12-16', '2026-12-17', '2026-12-18',
};

(int, int) _koreaSlot(String campus, int period) {
  if (period == 0) return (480, 530);
  final starts = koreaSlotStarts[campus]!;
  final start = period <= starts.length
      ? starts[period - 1]
      : starts.last + 60 * (period - starts.length);
  final end = period < starts.length ? starts[period] : start + 60;
  return (start, end);
}

/// 원문 요일·교시를 공식 교시표 슬롯으로 바꾼 주간 구간을 학기 날짜로 펼친다(파이썬 변환기와 독립 구현).
List<Map<String, dynamic>> koreaOfficialSchedules(Map<String, dynamic> c) {
  final campus = c['campus'] as String;
  final room = c['sourceClassroom'] as String;
  final lines = <(int, int, int, String)>[];
  final raw = (c['sourceSchedule'] as String).trim();
  final cells = RegExp(r'([월화수목금토일])(\d+)교시').allMatches(raw).toList();
  if (cells.isNotEmpty) {
    for (final m in cells) {
      final p = int.parse(m[2]!);
      lines.add((_koreaWeekdays.indexOf(m[1]!) + 1, p, p, room));
    }
  } else {
    for (final line in raw.split('\n').map((l) => l.trim())) {
      final m = RegExp(
        r'^([월화수목금토일])\((\d+)(?:-(\d+))?\)\s*(.*)$',
      ).firstMatch(line);
      if (m == null) continue; // 빈 줄·'미정(1-2)'
      final a = int.parse(m[2]!);
      lines.add((
        _koreaWeekdays.indexOf(m[1]!) + 1,
        a,
        int.parse(m[3] ?? m[2]!),
        m[4]!.trim().isEmpty && !room.contains(' / ') ? room : m[4]!.trim(),
      ));
    }
  }
  final weekly = <(int, int, int, String)>[];
  final open = <(int, int, int, String)>[];
  for (var (wd, a, b, r) in lines) {
    if (a == 0) {
      weekly.add((wd, 480, 530, r));
      a = 1;
    }
    if (b >= a) {
      open.add((wd, _koreaSlot(campus, a).$1, _koreaSlot(campus, b).$2, r));
    }
  }
  final keys = <String>[];
  for (final s in open) {
    final k = '${s.$1}|${s.$4}';
    if (!keys.contains(k)) keys.add(k);
  }
  for (final k in keys) {
    final group = open.where((s) => '${s.$1}|${s.$4}' == k).toList()
      ..sort((x, y) => x.$2.compareTo(y.$2));
    var cur = group.first;
    for (final s in group.skip(1)) {
      if (s.$2 - cur.$3 < 60) {
        cur = (cur.$1, cur.$2, s.$3 > cur.$3 ? s.$3 : cur.$3, cur.$4);
      } else {
        weekly.add(cur);
        cur = s;
      }
    }
    weekly.add(cur);
  }
  final period = c['period'] as Map;
  final out = <(String, int, int, Map<String, dynamic>)>[];
  final last = DateTime.parse('${period['endDate']}T00:00:00Z');
  for (
    var day = DateTime.parse('${period['startDate']}T00:00:00Z');
    !day.isAfter(last);
    day = day.add(const Duration(days: 1))
  ) {
    final iso = day.toIso8601String().substring(0, 10);
    if (_koreaExcludedDates.contains(iso)) continue;
    for (var i = 0; i < weekly.length; i++) {
      final (wd, s, e, r) = weekly[i];
      if (wd != day.weekday) continue;
      out.add((
        iso,
        s,
        i,
        {
          'weekday': wd,
          'startMinute': s,
          'endMinute': e,
          'classroom': r,
          'date': iso,
        },
      ));
    }
  }
  out.sort((x, y) {
    final d = x.$1.compareTo(y.$1);
    if (d != 0) return d;
    final s = x.$2.compareTo(y.$2);
    return s != 0 ? s : x.$3.compareTo(y.$3);
  });
  return [for (final o in out) o.$4];
}

Map<String, dynamic> _applyOfficialTimes(Map<String, dynamic> course) {
  final record = koreaOfficialTimes[course['sourceId']];
  if (record == null) return course;
  final copy = jsonDecode(jsonEncode(course)) as Map<String, dynamic>;
  final before = record['before'] as Map<String, dynamic>;
  for (final e in before.entries) {
    if (copy[e.key] != e.value) {
      throw StateError('${course['sourceId']} ${e.key} 확정 전 값 불일치');
    }
  }
  copy.addAll(record['after'] as Map<String, dynamic>);
  final remarks = copy['remarks'] as String;
  final tail = record['remarksTailBefore'] as String;
  if (!remarks.endsWith(tail)) {
    throw StateError('${course['sourceId']} 비고 확정 전 값 불일치');
  }
  copy['remarks'] =
      remarks.substring(0, remarks.length - tail.length) +
      (record['remarksTailAfter'] as String);
  copy['schedules'] = copy['scheduleStatus'] == 'scheduled'
      ? koreaOfficialSchedules(copy)
      : <Map<String, dynamic>>[];
  return copy;
}

/// 바뀐 강좌면 재조회 값으로 고친 사본을, 아니면 원본을 돌려준다. 쉬는 시간 포함 슬롯과
/// 2026-11-23 공식 교시표 확정도 적용한다.
Map<String, dynamic> applyKoreaRecheck(Map<String, dynamic> course) =>
    _applyOfficialTimes(_applyKoreaRecheck(course));

Map<String, dynamic> _applyKoreaRecheck(Map<String, dynamic> course) {
  final records = _changes[course['sourceId']];
  if (records == null) return _applyKoreaSlots(course);
  final copy =
      jsonDecode(jsonEncode(_applyKoreaSlots(course))) as Map<String, dynamic>;
  final metadata = copy['sourceEducationalMetadata'] as Map<String, dynamic>;
  for (final r in records) {
    if (copy[r['field']] != r['before']) {
      throw StateError('${course['sourceId']} ${r['field']} 이전 값 불일치');
    }
    copy[r['field']] = r['after'];
    final native = r['nativeField'] as String;
    if (native == 'COUR_NM') {
      final name = metadata['COUR_NM'] as String;
      final cut = name.indexOf('\n');
      metadata['COUR_NM'] =
          '${r['after']}${cut < 0 ? '' : name.substring(cut)}';
    } else {
      metadata[native] = r['after'];
    }
  }
  return copy;
}
