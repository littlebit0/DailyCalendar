import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-semantic-operating-followup-v4-20261009';
const baseline =
    'work/university-research/catalog-c/khu-semantic-operating-followup-v3-20261009';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(fixtureFile(actual).readAsStringSync())
          as Map<String, dynamic>;
  for (final row in data['courses'] ?? []) {
    if (row['metadata']?.containsKey('researchOnly') == true) {
      row['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  test(
    'KHU semantic pedagogy review native4666 prior1858 deep and43 neutral direct-clock sources full three modes Drive',
    () {
      final audit = read('$dir/semantic-native-operating-audit.json');
      final calendar = read(audit['ownPeriodProof']['file']);
      expect(calendar['checkedAt'], '2026-10-08');
      expect(
        (calendar['relevantRows'] as List).any(
          (r) => r.contains('9. 1.(화)') && r.contains('개강 (학기 개시일)'),
        ),
        true,
      );
      expect(
        (calendar['relevantRows'] as List).any(
          (r) => r.contains('12.22.(화)') && r.contains('동계 방학'),
        ),
        true,
      );
      final proofs = {for (final p in audit['proofs']) p['sourceId']: p};
      expect(proofs, hasLength(43));
      for (final item in (audit['inputSHA256'] as Map).entries) {
        expect(
          sha256
              .convert(fixtureFile(item.key as String).readAsBytesSync())
              .toString(),
          item.value,
        );
      }
      final raw = <String, dynamic>{};
      final old = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final campus in ['seoul', 'global']) {
        final previous = read(
          '$baseline/khu-$campus-2026-2.semantic-operating-research-v3-20261009.json',
        );
        final candidate = read(
          '$dir/khu-$campus-2026-2.semantic-operating-research-v4-20261009.json',
        );
        for (final c in previous['courses']) {
          old[c['sourceId']] = c;
        }
        for (final c in candidate['courses']) {
          raw[c['sourceId']] = c;
        }
        courses.addAll(UniversityDataset.fromJson(candidate).courses);
      }
      expect(raw.keys.toSet(), old.keys.toSet());
      expect(raw, hasLength(4666));
      var preservedClasses = 0;
      var preservedDates = 0;
      var addedDates = 0;
      final slot = RegExp(
        r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)',
      );
      final exception = RegExp(
        r'시험|고사|추석|공휴일|연휴|휴강|휴일|midterm|final\s*(exam|test)|no\s*class|holiday|vacation',
        caseSensitive: false,
      );
      const holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      for (final c in courses) {
        final previous = old[c.sourceId];
        if (!proofs.containsKey(c.sourceId)) {
          expect(raw[c.sourceId], previous, reason: c.sourceId);
          if ((previous['schedules'] as List).isNotEmpty) {
            preservedClasses++;
            preservedDates += (previous['schedules'] as List).length;
          }
          continue;
        }
        expect(previous['schedules'], isEmpty);
        for (final entry in (previous as Map).entries) {
          if (!{
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
          }.contains(entry.key)) {
            expect(
              raw[c.sourceId][entry.key],
              entry.value,
              reason: '${c.sourceId}/${entry.key}',
            );
          }
        }
        final intervals = <List<DateTime>>[
          [DateTime(2026, 10, 20), DateTime(2026, 10, 26)],
          [DateTime(2026, 12, 15), DateTime(2026, 12, 21)],
        ];
        for (final source in proofs[c.sourceId]['sourceProofs']) {
          final plan = read(source['file']);
          expect(plan['header'], ['2026학년도 2학기 강의계획서']);
          expect(
            plan['lectureCode'],
            previous['sourceEducationalVariants'][0]['lecture_cd'],
          );
          expect(
            (previous['sourceEducationalVariants'] as List).map(
              (v) => v['teach_na'],
            ),
            contains(plan['queriedProfessorName']),
          );
          for (final section in plan['educationalSections']) {
            if (section['section'] != '주별강의내용') {
              continue;
            }
            for (final row in section['rows']) {
              if (row.length < 3 ||
                  !RegExp(r'^\d+주$').hasMatch(row[0]) ||
                  !exception.hasMatch(row.sublist(2).join(' '))) {
                continue;
              }
              final r = RegExp(
                r'^(\d+)/(\d+)\s*~\s*(\d+)/(\d+)$',
              ).firstMatch(row[1])!;
              intervals.add([
                DateTime(2026, int.parse(r[1]!), int.parse(r[2]!)),
                DateTime(2026, int.parse(r[3]!), int.parse(r[4]!)),
              ]);
            }
          }
        }
        final expected = <String>{};
        for (final s in slot.allMatches(previous['sourceSchedule'])) {
          final weekday = '월화수목금토일'.indexOf(s[1]!) + 1;
          final start = int.parse(s[2]!) * 60 + int.parse(s[3]!);
          final end = int.parse(s[4]!) * 60 + int.parse(s[5]!);
          final room = s[6]!.trim();
          expect(room, isNotEmpty);
          for (
            var date = DateTime(2026, 9, 1);
            !date.isAfter(DateTime(2026, 12, 21));
            date = date.add(const Duration(days: 1))
          ) {
            final day = date.toIso8601String().substring(0, 10);
            if (date.weekday != weekday ||
                holidays.contains(day) ||
                intervals.any(
                  (r) => !date.isBefore(r[0]) && !date.isAfter(r[1]),
                )) {
              continue;
            }
            expected.add('$day/$weekday/$start/$end/$room');
          }
        }
        expect(
          c.meetings
              .map(
                (m) =>
                    '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
              )
              .toSet(),
          expected,
          reason: c.sourceId,
        );
        addedDates += c.meetings.length;
        expect(
          (raw[c.sourceId]['schedules'] as List).every(
            (m) => m['deliveryMode'] == null,
          ),
          true,
        );
      }
      expect(preservedClasses, 1858);
      expect(preservedDates, 35021);
      expect(addedDates, 874);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(1901));
      expect(courses.fold<int>(0, (n, c) => n + c.meetings.length), 35895);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          for (var i = 0; i < saved.meetings.length; i++) {
            final m = saved.meetings[i];
            final published = raw[c.sourceId]['schedules'][i]['deliveryMode'];
            final expected = published == 'inPerson'
                ? LectureMode.inPerson
                : published == 'liveOnline'
                ? LectureMode.liveOnline
                : mode;
            expect(saved.modeOn(m, m.teachingDate!), expected);
            expect(saved.period!.contains(m.teachingDate!), true);
          }
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
        final document = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          json,
        ).materializeClasses();
        expect(restored, hasLength(1901));
        for (final c in restored) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
