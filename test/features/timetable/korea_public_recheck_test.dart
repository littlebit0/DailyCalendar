import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'korea_public_recheck.dart';

String _flat(String? s) => (s ?? '')
    .replaceAll(RegExp(r'[\r\n]*<br>'), '\n')
    .replaceAll('﻿', '')
    .replaceAll(RegExp(r'\s+'), '');

void main() {
  test(
    '2026-10-23 공개 개설과목 재조회 결과와 고려대 자산의 강좌·교수·강좌명·학점·시간 원문이 일치',
    () {
      final packet = koreaPublicRecheck;
      final queries = packet['queries'] as List;
      final excluded =
          ((packet['excludedNativeIdentities'] as Map)['seoul'] as List)
              .toSet();
      expect(excluded, hasLength(14));
      expect(packet['changes'], hasLength(5));
      for (final campus in ['seoul', 'sejong']) {
        final rows = (packet['rows'] as Map)[campus] as List;
        final scoped = queries.where((q) => q['campus'] == campus).toList();
        expect(scoped, hasLength(campus == 'seoul' ? 132 : 61));
        expect(
          scoped.fold<int>(0, (n, q) => n + (q['rows'] as int)),
          rows.length,
        );
        expect(rows, hasLength(campus == 'seoul' ? 3626 : 1705));
        final fresh = {
          for (final r in rows) '${r['COUR_CD']}-${r['COUR_CLS']}': r as Map,
        };
        expect(fresh, hasLength(rows.length));

        final asset =
            jsonDecode(
                  File(
                    'assets/timetable/korea-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final coded = {
          for (final c in asset['courses'] as List)
            if ((c['courseCode'] as String).isNotEmpty)
              '${c['courseCode']}-${c['section']}': c as Map,
        };
        // 폐강·누락 없음: 기존 제외 범위만 빼면 강좌 식별자가 같다.
        expect(
          coded.keys.toSet(),
          fresh.keys.where((id) => !excluded.contains(id)).toSet(),
        );
        for (final entry in coded.entries) {
          final c = entry.value;
          final r = fresh[entry.key]!;
          expect(_flat(c['professor']), _flat(r['PROF_NM']), reason: entry.key);
          expect(c['classification'], r['ISU_NM'], reason: entry.key);
          expect(c['credits'], double.parse(r['CREDIT'] as String));
          expect(
            _flat(c['sourceSchedule']),
            _flat(r['TIME_ROOM']),
            reason: entry.key,
          );
          final name = c['courseName'] as String;
          final native = (r['COUR_NM'] as String).trim();
          expect(
            name == native ||
                (name.startsWith(native) &&
                    RegExp(
                      r'^(M|FC|T|NM|DL|ES)+$',
                    ).hasMatch(name.substring(native.length))),
            true,
            reason: entry.key,
          );
        }
      }
      for (final change in packet['changes'] as List) {
        final id = (change['sourceId'] as String).split('/').last;
        final campus = (change['sourceId'] as String).split('/')[1];
        final asset =
            jsonDecode(
                  File(
                    'assets/timetable/korea-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        final c = (asset['courses'] as List).singleWhere(
          (c) => '${c['courseCode']}-${c['section']}' == id,
        );
        expect(c[change['field']], change['after']);
        expect(koreaRecheckChangedIds, contains(change['sourceId']));
      }
    },
  );
}
