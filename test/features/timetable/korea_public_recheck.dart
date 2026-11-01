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

Set<String> get koreaRecheckChangedIds => _changes.keys.toSet();

// 쉬는 시간 포함 슬롯(#564). 서울 1~6교시 75분+15분, 7~10교시 50분+10분, 세종 50분+10분.
// 근거 문서 미확인: 현재 자료의 연속 교시 시작 간격으로 만든다.
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

/// 바뀐 강좌면 재조회 값으로 고친 사본을, 아니면 원본을 돌려준다. 쉬는 시간 포함 슬롯도 적용한다.
Map<String, dynamic> applyKoreaRecheck(Map<String, dynamic> course) {
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
