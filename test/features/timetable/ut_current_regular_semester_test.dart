import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

const folder =
    'work/university-research/catalog-c/ut-current-own-regular-planned-dates-v6-20261009';
dynamic read(String name) {
  final actual = '$folder/$name';
  final data = jsonDecode(File(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

Map<String, dynamic> external(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'UT61 own weekly later366 dates;395 exactprefix and complete native restoration',
    () {
      final raw = read('ut-unknown-2026-2.current-own-regular-planned-v6.json');
      final prior = read('prior-v4-frozen-61-395-baseline.json');
      final proof = read(
        'independent-own-source-clock-and-literal-added-dates-proof.json',
      );
      final archive =
          jsonDecode(
                File(
                  '$folder/full-prior-research-note-external-archive.json',
                ).readAsStringSync(),
              )
              as List;
      final priorById = {
        for (final c in prior['courses'] as List) (c as Map)['sourceId']: c,
      };
      final proofs = {
        for (final p in proof['proofs'] as List) (p as Map)['sourceId']: p,
      };
      final notes = {for (final n in archive) (n as Map)['sourceId']: n};
      final cal = external(
        'work/university-research/catalog-c/ut-current-20261008/calendar-educational-dates.json',
      );
      final events = cal['events'] as List;
      final midterm = events.singleWhere(
        (e) =>
            e['startDate'] == '2026-10-20' &&
            (e['subject'] as String).contains('중간'),
      );
      final makeup = events.singleWhere(
        (e) =>
            e['startDate'] == '2026-12-08' &&
            (e['subject'] as String).contains('보강'),
      );
      final startDate = DateTime.parse(
        midterm['endDate'],
      ).add(const Duration(days: 1));
      final endDate = DateTime.parse(
        makeup['startDate'],
      ).subtract(const Duration(days: 1));
      expect(startDate, DateTime(2026, 10, 27));
      expect(endDate, DateTime(2026, 12, 7));
      final bio = external(
        'work/university-research/catalog-c/ut-current-20261008/biotech-original-educational-grid.json',
      );
      final electric = external(
        'work/university-research/catalog-c/ut-current-electri-exact-75-block-v2-20261009/independent-source-clock-column-and-grade-headers.json',
      );
      final rulesPath =
          'work/university-research/catalog-c/ut-current-own-regular-term-rule-proof-v5-20261009/independent-current-own-regular-term-rule-education-proof.json';
      expect(
        sha256.convert(File(rulesPath).readAsBytesSync()).toString(),
        proof['sourceInputsSHA256']['current2026RuleEducationalProof'],
      );
      final rules = external(rulesPath);
      final clauses = (rules['newRuleSourceEvidence'] as List)
          .expand((s) => s['selectedOwnUndergraduateEducationClauses'] as List)
          .map((p) => p['exactOriginalText'] as String)
          .join('\n');
      expect(clauses, contains('주당'));
      expect(clauses, contains('주별 강의계획'));
      expect(clauses, contains('집중이수'));
      expect(raw['completionClaim'], false);
      expect(raw['wholeOperatingVerified'], false);
      expect(raw['courses'], hasLength(61));
      expect(proofs, hasLength(61));
      var oldDates = 0;
      var addedDates = 0;
      for (final item in raw['courses'] as List) {
        final row = item as Map;
        final original = priorById[row['sourceId']] as Map;
        final p = proofs[row['sourceId']] as Map;
        final n = notes[row['sourceId']] as Map;
        expect(p['originalWholeObject'], original);
        expect(row['sourceEducationCell'], original['sourceEducationCell']);
        expect(n['previousWholeResearchRemarks'], original['remarks']);
        expect(
          row['remarks'],
          (original['remarks'] as String).replaceFirst(
            n['exactRemovedResearchScopePhrase'],
            n['exactReplacementResearchScopePhrase'],
          ),
        );
        final meetings = row['schedules'] as List;
        final oldMeetings = original['schedules'] as List;
        expect(meetings.take(oldMeetings.length).toList(), oldMeetings);
        oldDates += oldMeetings.length;
        final added = meetings.skip(oldMeetings.length).toList();
        expect(added, hasLength(6));
        final cell = row['sourceEducationCell'];
        final isBio = (row['sourceId'] as String).startsWith(
          'ut-document290587-',
        );
        late String clock;
        late int weekday;
        if (isBio) {
          final r = cell['row'] as int;
          final c = cell['column'] as int;
          expect(cell['text'], bio['values'][r][c]);
          clock = bio['values'][r][28];
          final header = (bio['merges'] as List).singleWhere(
            (m) => m[0] == 2 && m[1] == 3 && m[2] <= c && c < m[3],
          );
          weekday =
              ['월', '화', '수', '목', '금'].indexOf(bio['values'][2][header[2]]) +
              1;
        } else {
          clock =
              (electric['native75ClockColumn'][cell['native75Period']]['exactOriginalClockColumnText']
                      as String)
                  .split('\n')
                  .last;
          weekday = ((cell['nativeColumnIndex'] as int) - 4) ~/ 5 + 1;
        }
        final hh = RegExp(
          r'\d+',
        ).allMatches(clock).map((m) => int.parse(m[0]!)).toList();
        final literal = <String>[];
        for (
          var d = startDate;
          !d.isAfter(endDate);
          d = d.add(const Duration(days: 1))
        ) {
          if (d.weekday == weekday) {
            literal.add(d.toIso8601String().substring(0, 10));
          }
        }
        expect(literal, p['literalAddedDates']);
        expect(added.map((m) => m['date']).toList(), literal);
        for (final m in added) {
          expect(m['weekday'], weekday);
          expect(DateTime.parse(m['date']).weekday, weekday);
          expect(m['startMinute'], hh[0] * 60 + hh[1]);
          expect(m['endMinute'], hh[2] * 60 + hh[3]);
          expect(m['classroom'], original['sourceClassroom']);
          expect(m.containsKey('deliveryMode'), false);
          addedDates++;
        }
        expect(row['period']['endDate'], '2026-12-07');
        expect(
          row['regularPlannedSemesterScope']['publishedLastClassDateClaim'],
          false,
        );
        final reverted = Map<String, dynamic>.from(row);
        reverted['remarks'] = original['remarks'];
        reverted['period'] = original['period'];
        reverted['schedules'] = oldMeetings;
        reverted.remove('regularPlannedSemesterScope');
        expect(reverted, original);
      }
      expect(oldDates, 395);
      expect(addedDates, 366);
    },
  );
  test('UT full61/761 entirethreeusermodes andDriveJSON restoration', () {
    final dataset = UniversityDataset.fromJson(
      read('ut-unknown-2026-2.current-own-regular-planned-v6.json'),
    );
    expect(dataset.courses, hasLength(61));
    expect(dataset.courses.fold<int>(0, (n, c) => n + c.meetings.length), 761);
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final values = <String, TimetableSyncValue>{};
      for (final c in dataset.courses) {
        final t = c.toTimetable(id: c.sourceId, mode: mode);
        expect(t.isValid, true);
        expect(t.defaultMode, mode);
        for (final m in t.meetings) {
          expect(t.modeOn(m, DateTime.parse(m.date!)), mode);
        }
        final key = timetableCourseSyncKey(t);
        expect(values.containsKey(key), false);
        values[key] = TimetableSyncValue(
          {...t.toJson(), 'id': key},
          DateTime.utc(2026, 10, 9),
          'research',
        );
      }
      expect(values, hasLength(61));
      final doc = TimetableSyncDocument.records(courses: values);
      final restored = TimetableSyncDocument.fromJson(
        jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), doc.toJson());
      for (final e in values.entries) {
        expect(restored.courses[e.key]!.value, e.value.value);
      }
      final classes = restored.materializeClasses();
      expect(classes, hasLength(61));
      expect(classes.map((c) => c.sourceId).toSet(), hasLength(61));
      expect(classes.fold<int>(0, (n, c) => n + c.meetings.length), 761);
      for (final c in classes) {
        expect(c.isValid, true);
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        for (final m in c.meetings) {
          expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
        }
      }
    }
  });
}
