import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Chosun current native future-college fields and own exam boundaries survive all modes and full Drive JSON',
    () {
      const root = 'work/university-research/catalog-f/chosun/';
      Map<String, dynamic> read(String n) =>
          jsonDecode(fixtureFile('$root$n').readAsStringSync())
              as Map<String, dynamic>;
      final original = read(
        'chosun-future-current-education-source-20261008.json',
      );
      final cells = {
        for (final c in original['courseCells'] as List)
          '${c['sheet']}/${c['cell']}': c,
      };
      final sheets = {
        for (final s in original['sheets'] as List) s['sheet']: s,
      };
      final selected = read(
        'chosun-future-native71-source-selection-20261008.json',
      );
      final rows = {
        for (final r in selected['educationRows'] as List) r['sourceId']: r,
      };
      final ds = UniversityDataset.fromJson({
        ...jsonDecode(
              fixtureFile(
                'work/university-research/catalog-f/chosun/chosun-unknown-2026-2.future-nurse-native135-partial-v2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
        'courses':
            (jsonDecode(
                      fixtureFile(
                        'work/university-research/catalog-f/chosun/chosun-unknown-2026-2.future-nurse-native135-partial-v2.json',
                      ).readAsStringSync(),
                    )['courses']
                    as List)
                .take(71)
                .toList(),
      });
      expect(ds.courses, hasLength(71));
      expect(ds.courses.map((c) => c.sourceId).toSet(), hasLength(71));
      expect(ds.courses.fold<int>(0, (n, c) => n + c.meetings.length), 434);
      final scheduled = ds.courses.where((c) => c.meetings.isNotEmpty).toList();
      expect(scheduled, hasLength(38));
      for (final c in ds.courses) {
        final r = rows[c.sourceId]!,
            source = cells['${r['sheet']}/${r['cell']}']!;
        expect(source['nativeCellText'], r['nativeCellText']);
        expect(source['sheetHeading'], contains('2학기'));
        final lines = (source['nativeCellText'] as String).split('\n');
        final idx = lines.indexWhere((s) => RegExp(r'\d{5}-\d{2}').hasMatch(s));
        final m = RegExp(r'\d{5}-\d{2}').firstMatch(lines[idx])!;
        expect(
          c.title,
          lines.sublist(0, idx).map((s) => s.trim()).join() +
              lines[idx].substring(0, m.start).trim(),
        );
        expect(r['nativeReference'], m.group(0));
        expect(c.professor, lines[idx + 1].trim());
        expect(c.sourceClassroom, lines[idx + 2].trim());
        expect(c.code, isEmpty);
        expect(c.section, isEmpty);
        expect(c.credits, isNull);
        expect(c.campus, 'unknown');
        expect(c.sourceClassification, r['nativeClassification']);
        final legend = (sheets[r['sheet']]['legend'] as List)
            .where((l) => jsonEncode(l['fill']) == jsonEncode(source['fill']))
            .toList();
        expect(
          c.sourceClassification,
          legend.length == 1 ? legend.single['nativeClassification'] : '',
        );
        final sourceClocks = {
          for (final clock in sheets[r['sheet']]['clockRows'] as List)
            clock['row']: clock,
        };
        final first = sourceClocks[source['minRow']]!,
            last = sourceClocks[source['maxRow']]!;
        final weekday = ((source['minColumn'] as int) - 4) ~/ 6 + 1;
        if (c.meetings.isEmpty) {
          expect(r['status'], 'held');
          continue;
        }
        expect(r['nativeDeliveryMode'], '대면');
        expect(r['heldReasons'], isEmpty);
        final expectedDates = <String>[];
        for (
          var d = DateTime(2026, 9, 1);
          !d.isAfter(DateTime(2026, 12, 7));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if (d.weekday == weekday &&
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
            expectedDates.add(date);
          }
        }
        expect(c.meetings.map((m) => m.date).toList(), expectedDates);
        for (final meeting in c.meetings) {
          expect(meeting.weekday, weekday);
          expect(meeting.originalStartMinute, first['startMinute']);
          expect(meeting.originalEndMinute, last['endMinute']);
          expect(meeting.classroom, c.sourceClassroom);
        }
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = scheduled
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(38));
        final lookup = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.note, contains('공개 주간 예약 계획, 실제 운영/날짜 미확인'));
          expect(c.note, contains('내부 원문 문서 위치 식별자는 수강신청 코드가 아닙니다'));
          expect(
            c.toJson()..remove('id'),
            lookup[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.note, contains(rows[c.sourceId]['nativeReference']));
        }
      }
    },
  );
}
