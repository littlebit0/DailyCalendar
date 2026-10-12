import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test(
    'Suwon historical v2 first-three-week source native rows and three full Drive modes',
    () {
      const root =
          'work/university-research/catalog-r/suwon/full-query-partial-v2/';
      final raw =
          jsonDecode(
                File(
                  '${root}suwon-unknown-2026-2.early-planned.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final proof =
          jsonDecode(File('${root}educational-proof.json').readAsStringSync())
              as Map;
      final nativeBySequence = <String, List<dynamic>>{};
      final sourceFiles = (proof['sourceFilesSHA256'] as Map).keys;
      expect(sourceFiles, hasLength(108));
      for (final sourcePath in sourceFiles) {
        final snapshot =
            jsonDecode(File(sourcePath as String).readAsStringSync()) as Map;
        expect(snapshot['year'], '2026');
        expect(snapshot['semester'], '2');
        final all = snapshot['rows'] as List;
        final name = snapshot['query'] as String;
        final complete = ['전체-p1', '전체-p2', '전체-p3', '전체-p4'].contains(name)
            ? all.take(all.length - 1)
            : all;
        for (final row in complete) {
          final value = row as List<dynamic>;
          expect(value, hasLength(22));
          expect(value[2], matches(RegExp(r'^\d{5}$')));
          expect(value[4], matches(RegExp(r'^\d{3}$')));
          final seq = value[0] as String;
          if (nativeBySequence.containsKey(seq)) {
            expect(value, nativeBySequence[seq]);
          }
          nativeBySequence[seq] = value;
        }
      }
      expect(nativeBySequence.length, 2596);
      for (var seq = 1; seq <= 2596; seq++) {
        expect(nativeBySequence.containsKey('$seq'), true);
        expect(
          (proof['nativeRows'] as List)[seq - 1],
          nativeBySequence['$seq'],
        );
      }
      final courses = UniversityDataset.fromJson(raw).courses;
      expect(raw['completionClaim'], false);
      expect(courses, hasLength(2334));
      expect(proof['nativeRows'], hasLength(2596));
      var count = 0;
      for (var i = 0; i < courses.length; i++) {
        final c = courses[i];
        final r = (raw['courses'] as List)[i] as Map;
        final meta = r['metadata'] as Map;
        final originals = meta['originalEducationalRecords'] as List;
        count += originals.length;
        for (final x in originals) {
          final v = x['values'] as List;
          expect(
            v,
            (proof['nativeRows'] as List).singleWhere(
              (dynamic n) => n[0] == v[0],
            ),
          );
          expect(c.code, v[2]);
          expect(c.section, v[4]);
          expect(c.title, (originals.first['values'] as List)[3]);
          expect(c.professor, (originals.first['values'] as List)[18]);
          expect(c.departments, contains(v[10]));
          expect(c.departmentClassifications[v[10]], v[6]);
          expect(c.sourceSchedule, v[12]);
        }
        expect(c.campus, 'unknown');
        expect(meta['actualAttendanceConfirmed'], false);
        final v = originals.first['values'] as List;
        if ((meta['reservationHoldReasons'] as List).isNotEmpty) {
          expect(c.meetings, isEmpty);
          continue;
        }
        expect(v[20], '');
        expect(v[21], '');
        expect(v[14], false);
        expect(v[15], false);
        expect(v[9], '0');
        final expected = <String>{};
        for (final b in RegExp(
          r'([^(),]+)\(([월화수목금])([1-8](?:,[1-8])*)\)',
        ).allMatches(v[12])) {
          final periods = b[3]!.split(',').map(int.parse).toList();
          final clock = proof['clockEvidence']['clock'] as List;
          int minute(String t) {
            final p = t.split(':');
            return int.parse(p[0]) * 60 + int.parse(p[1]);
          }

          final a = minute(clock[periods.first - 1]['start']);
          final z = minute(clock[periods.last - 1]['end']);
          for (
            var d = DateTime(2026, 9, 1);
            !d.isAfter(DateTime(2026, 9, 20));
            d = d.add(const Duration(days: 1))
          ) {
            if (d.weekday != '월화수목금'.indexOf(b[2]!) + 1) continue;
            expected.add(
              '${d.toIso8601String().substring(0, 10)}/$a/$z/${b[1]}',
            );
          }
        }
        expect(
          c.meetings
              .map(
                (m) =>
                    '${m.date}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
              )
              .toSet(),
          expected,
        );
        expect(
          (r['schedules'] as List).every(
            (dynamic m) => !m.containsKey('deliveryMode'),
          ),
          true,
        );
      }
      expect(count, 2596);
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(878));
      expect(courses.fold<int>(0, (a, c) => a + c.meetings.length), 2602);
      final rows =
          proof['calendarEvidence']['calendar']['nativeEducationRows'] as List;
      expect(
        rows.singleWhere(
          (dynamic r) => r['nativeDate'] == '2026.12.08(화) ~ 2026.12.14(월)',
        ),
        {
          'nativeDate': '2026.12.08(화) ~ 2026.12.14(월)',
          'nativeTitle': '학기말고사 (Final)',
        },
      );
      expect(
        proof['calendarEvidence']['datePolicy']['midtermDatesProven'],
        false,
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = courses
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(after, hasLength(878));
        final byId = {for (final c in before) c.sourceId: c};
        for (final c in after) {
          final old = byId[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, old.title);
          expect(c.professor, old.professor);
          expect(c.note, old.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            old.meetings.map((m) => m.toJson()).toList(),
          );
        }
      }
    },
  );
}
