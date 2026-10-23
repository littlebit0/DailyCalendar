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

/// 바뀐 강좌면 재조회 값으로 고친 사본을, 아니면 원본을 돌려준다.
Map<String, dynamic> applyKoreaRecheck(Map<String, dynamic> course) {
  final records = _changes[course['sourceId']];
  if (records == null) return course;
  final copy =
      jsonDecode(jsonEncode(course)) as Map<String, dynamic>;
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
