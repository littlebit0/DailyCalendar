import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-stale-research-note-preservation-v7-20261009';
const prior =
    'work/university-research/catalog-c/khu-empty-room-ordinary-followup-v6-20261009';
const warning =
    '강좌의 현재 공개 목록은 확인했으나 개별 수업 운영 방식·집중 기간은 아직 검토 중입니다. 시간표 자동 배치는 보류됩니다.';
Map<String, dynamic> read(String p) {
  final actual = p;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  test(
    'KHU v7 exact non-school stale warning correction only, previous notes lossless, all native and dates unchanged',
    () {
      final proof = read('$dir/independent-note-preservation-receipt.json');
      final changed = {for (final p in proof['proofs']) p['sourceId']: p};
      expect(changed, hasLength(41));
      for (final e in (proof['sourceSHA256'] as Map).entries) {
        expect(
          sha256
              .convert(fixtureFile(e.key as String).readAsBytesSync())
              .toString(),
          e.value,
        );
      }
      var native = 0;
      var scheduled = 0;
      var dates = 0;
      var corrections = 0;
      for (final campus in ['seoul', 'global']) {
        final old = read(
          '$prior/khu-$campus-2026-2.empty-room-research-v6-20261009.json',
        );
        final next = read(
          '$dir/khu-$campus-2026-2.research-note-corrected-v7-20261009.json',
        );
        final baseline = {for (final c in old['courses']) c['sourceId']: c};
        expect(
          (next['courses'] as List).map((c) => c['sourceId']).toSet(),
          baseline.keys.toSet(),
        );
        for (final value in next['courses']) {
          final c = value as Map<String, dynamic>;
          final before = baseline[c['sourceId']] as Map<String, dynamic>;
          native++;
          dates += (c['schedules'] as List).length;
          if ((c['schedules'] as List).isNotEmpty) {
            scheduled++;
          }
          if (!changed.containsKey(c['sourceId'])) {
            expect(c, before);
            continue;
          }
          corrections++;
          expect(
            c['previousResearchDepartmentRemarks'],
            before['departmentRemarks'],
          );
          expect(c['departmentRemarks'], {
            for (final e in (before['departmentRemarks'] as Map).entries)
              e.key: (e.value as String).replaceAll(warning, ''),
          });
          final restored = Map<String, dynamic>.from(c)
            ..remove('previousResearchDepartmentRemarks');
          restored['departmentRemarks'] = before['departmentRemarks'];
          expect(restored, before, reason: c['sourceId']);
          expect(c['schedules'], before['schedules']);
          for (final text in (c['departmentRemarks'] as Map).values) {
            expect((text as String).contains(warning), false);
          }
        }
      }
      expect(native, 4666);
      expect(scheduled, 1947);
      expect(dates, 36548);
      expect(corrections, 41);
    },
  );
}
