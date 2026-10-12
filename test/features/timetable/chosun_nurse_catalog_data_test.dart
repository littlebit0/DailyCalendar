import 'dart:convert';
import 'dart:io';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'chosun_catalog_data_test.dart' as original;

void main() {
  original.main();
  test(
    'Current nursing native cells, exact hour boundaries, closures and all modes survive full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/chosun/';
      Map<String, dynamic> read(String name) =>
          jsonDecode(
                File(
                  name ==
                          'chosun-unknown-2026-2.future-nurse-native135-partial-v2.json'
                      ? 'work/university-research/catalog-f/chosun/chosun-unknown-2026-2.future-nurse-native135-partial-v2.json'
                      : '$root$name',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final raw = read(
        'chosun-unknown-2026-2.future-nurse-native135-partial-v2.json',
      );
      final old = read('chosun-unknown-2026-2.future-native71-partial-v1.json');
      expect((raw['courses'] as List).take(71).toList(), old['courses']);
      expect(raw.containsKey('termEndDate'), false);
      final ds = UniversityDataset.fromJson(raw);
      expect(ds.courses, hasLength(135));
      expect(ds.courses.map((c) => c.sourceId).toSet(), hasLength(135));
      final source = read(
        'chosun-nurse-current-education-source-20261008.json',
      );
      final rows = {
        for (final r in source['educationRows'] as List) r['sourceId']: r,
      };
      expect(rows, hasLength(64));
      final headers = source['nativeHourHeaders'] as List;
      for (final c in ds.courses.skip(71)) {
        final r = rows[c.sourceId]!;
        final text = (r['nativeCellText'] as String)
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        final m = RegExp(
          r'(.*?)\((\d{2})\)\s*([가-힣]{2,5}|000)\s+(.+)',
        ).firstMatch(text)!;
        final professor = m[3] == '본관' ? '' : m[3]!;
        final room = m[3] == '본관' ? '본관 ${m[4]}' : m[4]!.trim();
        expect(c.title, m[1]!.trim());
        expect(c.section, m[2]);
        expect(c.professor, professor);
        expect(c.sourceClassroom, room);
        expect(c.code, isEmpty);
        expect(c.credits, isNull);
        expect(c.sourceClassification, isEmpty);
        expect(c.campus, 'unknown');
        expect(c.title.replaceAll(' ', ''), isNot(contains('환자안전')));
        expect(c.title.replaceAll(' ', ''), isNot(contains('건강한노화')));
        expect(c.title.replaceAll(' ', ''), isNot(contains('임상영양학')));
        if (c.title.contains('간호학실습') || c.title.contains('건강사정실습')) {
          expect(c.section, isNot('05'));
        }
        if (c.meetings.isEmpty) {
          expect(r['heldReasons'], isNotEmpty);
          continue;
        }
        expect(r['grade'], anyOf(1, 2));
        expect(r['heldReasons'], isEmpty);
        expect(professor, isNot(anyOf('', '000', '본관')));
        expect(c.title, isNot(contains('실습')));
        final bbox = r['bbox'] as List;
        final first = headers.singleWhere(
          (h) => ((h['x0'] as num) - (bbox[0] as num)).abs() < .2,
        );
        final last = headers.singleWhere(
          (h) => ((h['x1'] as num) - (bbox[2] as num)).abs() < .2,
        );
        int minutes(String s) {
          final p = s.split(':');
          return int.parse(p[0]) * 60 + int.parse(p[1]);
        }

        String clock(Map h) => RegExp(
          r'\d{2}:\d{2}~\d{2}:\d{2}',
        ).firstMatch(h['nativeHeader'] as String)!.group(0)!;
        final start = minutes(clock(first).split('~').first),
            end = minutes(clock(last).split('~').last);
        final expected = <String>[];
        for (
          var d = DateTime(2026, 9, 1);
          !d.isAfter(DateTime(2026, 12, 7));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if (d.weekday == r['weekday'] &&
              ![
                '2026-09-24',
                '2026-09-25',
                '2026-09-26',
                '2026-09-29',
                '2026-10-03',
                '2026-10-05',
                '2026-10-09',
              ].contains(date) &&
              !(date.compareTo('2026-10-20') >= 0 &&
                  date.compareTo('2026-10-26') <= 0)) {
            expected.add(date);
          }
        }
        expect(c.meetings.map((m) => m.date).toList(), expected);
        for (final m in c.meetings) {
          expect(m.originalStartMinute, start);
          expect(m.originalEndMinute, end);
          expect(m.classroom, room);
          expect(m.weekday, r['weekday']);
        }
      }
      final eligible = ds.courses.where((c) => c.meetings.isNotEmpty).toList();
      expect(eligible, hasLength(62));
      expect(ds.courses.fold<int>(0, (n, c) => n + c.meetings.length), 724);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = eligible
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
        expect(restored, hasLength(62));
        final lookup = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(
            c.toJson()..remove('id'),
            lookup[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
        }
      }
    },
  );
}
