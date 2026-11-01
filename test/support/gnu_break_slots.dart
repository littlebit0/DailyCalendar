// 경상국립대 교시 슬롯: n교시 시작 = 08:00 + 60n분, 수업 50분 + 쉬는 시간 10분을
// 합쳐 슬롯 끝 = 다음 교시 시작. 산업경영학과 금요일 야간(11~13교시)은 45분+5분.
// 산업경영학과 토요일 수정 공지처럼 원문이 시계 구간을 직접 적은 구간은 바꾸지 않는다.
int gnuSlotEnd(int start, int end) {
  if ((start - 480) % 60 == 0 && (end - 530) % 60 == 0 && start >= 480) {
    return end + 10;
  }
  if (start == 1140 && end == 1285) return 1290;
  return end;
}

/// 수업 시각 수정 전(50분 수업 끝 시각) 자료를 슬롯 규칙으로 바꾼 사본을 만든다.
/// 이 대학 자료에는 합쳐질 연속 구간이 없어 구간 수는 그대로다.
void applyGnuBreakSlots(Map<String, dynamic> data) {
  for (final dynamic course in data['courses'] ?? []) {
    for (final dynamic m in course['schedules'] ?? []) {
      m['endMinute'] = gnuSlotEnd(
        m['startMinute'] as int,
        m['endMinute'] as int,
      );
    }
  }
}

/// 같은 날 같은 강의실이면서 간격이 60분 미만인 구간이 남아 있으면 안 된다.
void expectNoMergeableGnuSegments(Iterable<dynamic> courses) {
  for (final dynamic course in courses) {
    final byDate = <String, List<Map>>{};
    for (final dynamic m in course['schedules'] ?? []) {
      byDate.putIfAbsent(m['date'] as String, () => []).add(m as Map);
    }
    for (final list in byDate.values) {
      list.sort(
        (a, b) => (a['startMinute'] as int) - (b['startMinute'] as int),
      );
      for (var i = 1; i < list.length; i++) {
        final sameRoom = list[i]['classroom'] == list[i - 1]['classroom'];
        final gap =
            (list[i]['startMinute'] as int) - (list[i - 1]['endMinute'] as int);
        if (sameRoom && gap < 60) {
          throw StateError('${course['sourceId']} ${list[i]['date']}');
        }
      }
    }
  }
}
