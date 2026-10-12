import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-f/pknu-current-20261008';
Map<String, dynamic> read(String file) =>
    jsonDecode(File('$directory/$file').readAsStringSync())
        as Map<String, dynamic>;
void main() {
  final audit = read('candidate-audit.json');
  final raw = <Map<String, dynamic>>[];
  for (final dataset in audit['datasets']) {
    final file = dataset['file'] as String;
    raw.add(
      jsonDecode(File('$directory/$file').readAsStringSync())
          as Map<String, dynamic>,
    );
  }
  final courses = raw
      .expand((d) => UniversityDataset.fromJson(d).courses)
      .toList();
  final records = {
    for (final d in raw)
      for (final c in d['courses']) c['sourceId']: c,
  };
  test('Current native identities closure privacy and campus proof', () {
    for (final dataset in audit['datasets']) {
      final file = dataset['file'] as String;
      expect(
        sha256.convert(File('$directory/$file').readAsBytesSync()).toString(),
        dataset['sha256'],
      );
    }

    for (final d in raw) {
      expect(
        jsonDecode(
          File('assets/timetable/pknu-${d['campus']}-2026-2.json')
              .readAsStringSync(),
        )['researchOnly'],
        false,
      );
      expect(
        jsonDecode(
          File('assets/timetable/pknu-${d['campus']}-2026-2.json')
              .readAsStringSync(),
        )['completionClaim'],
        false,
      );
    }
    expect(courses, hasLength(2720));
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(2720));
    expect(audit['knownClosureCount'], 114);
    expect(audit['knownClosuresStillPresent'], isEmpty);
    expect(courses.where((c) => c.campus == 'unknown'), hasLength(305));
    expect(courses.where((c) => c.campus == 'daeyeon'), hasLength(2415));
    final held = (audit['holds'] as List).map((x) => x['identity']).toSet();
    for (final c in courses) {
      final r = records[c.sourceId];
      final e = r['sourceCurrentEducation'];
      expect(c.code, e['COURSE_NO']);
      expect(c.section, e['DCLSS_NO']);
      expect(c.title, e['SBJT_KOR_NM']);
      expect(c.sourceClassification, e['SBJT_FG_NM']);
      expect((e as Map).containsKey('STAFF_NO'), false);
      expect(e['CLS_CLSS_YN'], 'N');
      expect(c.remarks, contains('실제 출석 확정이 아닙니다'));
      if (held.contains(c.codeAndSection)) {
        expect(c.meetings, isEmpty);
      }
      if (c.meetings.isNotEmpty) {
        expect(c.campus, 'daeyeon');
      }
    }
  });
  test(
    'Exact original current weekday periods room current rule and full date coverage',
    () {
      final holidays = (audit['excludedHolidays'] as List)
          .cast<String>()
          .toSet();
      final explicit = audit['explicitDateProof'] as Map;
      final clockRule = read('../pknu-current-clock-policy-audit.json');
      expect(clockRule['revision'], '2026-01-21');
      expect(clockRule['clockEvidence'], contains('08:00-08:50'));
      expect(clockRule['clockEvidence'], contains('22:00-22:50'));
      expect(clockRule['clockEvidence'], contains('15:00-16:15'));
      expect(clockRule['clockEvidence'], contains('16:30-17:45'));
      var count = 0;
      for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
        final r = records[c.sourceId];
        final source = r['publicPlanEducation']['fields'];
        expect(c.sourceSchedule, source['강의시간']);
        expect(c.sourceClassroom, source['강의실']);
        final native = <Map<String, int>>[];
        final pattern = RegExp(r'([월화수목금토일])\s*([0-9]+(?:\s*[-~,]\s*[0-9]+)*)');
        for (final match in pattern.allMatches(source['강의시간'] as String)) {
          final weekday = '월화수목금토일'.indexOf(match[1]!) + 1;
          for (final part in match[2]!.split(',')) {
            final range = part.trim().split(RegExp('[-~]'));
            final first = int.parse(range.first);
            final last = int.parse(range.last);
            for (var n = first; n <= last; n++) {
              native.add({'weekday': weekday, 'period': n});
            }
          }
        }
        expect(native, isNotEmpty);
        expect(native, r['sourceNativePeriods']);

        if (c.codeAndSection != '114380-101') {
          expect(source['강의형태'], '대면 수업');
          expect(
            (r['sourceNativePeriods'] as List).every(
              (p) => p['weekday'] != 2 && p['weekday'] != 4,
            ),
            true,
          );
        } else {
          final fresh = read('114380-101.selected-education.json');
          expect(
            (fresh['selectedAcademicContexts'] as List).any(
              (x) => (x['text'] as String).contains('75분'),
            ),
            true,
          );
        }
        final dates = <DateTime>[];
        if (explicit.containsKey(c.codeAndSection)) {
          dates.addAll(
            (explicit[c.codeAndSection] as List).map(
              (x) => DateTime.parse('2026-$x'),
            ),
          );
        } else {
          for (
            var d = DateTime(2026, 9, 1);
            !d.isAfter(DateTime(2026, 12, 7));
            d = d.add(const Duration(days: 1))
          ) {
            if (!holidays.contains(timetableDateKey(d))) {
              dates.add(d);
            }
          }
        }
        final expected = <String>{};
        for (final date in dates) {
          for (final p in native) {
            if (date.weekday != p['weekday']) {
              continue;
            }
            final n = p['period'] as int;
            final start = c.codeAndSection == '114380-101'
                ? 540 + 90 * (n - 1)
                : 480 + 60 * n;
            final end = start + (c.codeAndSection == '114380-101' ? 75 : 50);
            expected.add(
              '${timetableDateKey(date)}/${date.weekday}/$start/$end/${source['강의실']}',
            );
          }
        }
        final actual = <String>{};
        for (final m in c.meetings) {
          count++;
          expect(m.weekday, m.teachingDate!.weekday);
          expect(
            actual.add(
              '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            ),
            true,
          );
        }
        expect(actual, expected, reason: c.codeAndSection);
      }
      expect(count, 43018);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(1049));
      expect(
        courses
            .singleWhere((c) => c.codeAndSection == '104866-101')
            .meetings
            .any((m) => m.date == '2026-12-09'),
        false,
      );
      expect(
        courses
            .singleWhere((c) => c.codeAndSection == '114376-101')
            .meetings
            .any((m) => m.date == '2026-09-09'),
        false,
      );
      expect(
        courses.singleWhere((c) => c.codeAndSection == '114380-101').meetings,
        hasLength(8),
      );
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      'Actual 1049 classes 43018 dates full Drive JSON roundtrip ${mode.name}',
      () {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.defaultMode, mode);
          expect(saved.note, c.remarks);
          expect(saved.period!.start, DateTime(2026, 9, 1));
          expect(saved.period!.end, DateTime(2026, 12, 20));
          for (final m in saved.meetings) {
            count++;
            expect(m.isValid, true);
            expect(saved.period!.contains(m.teachingDate!), true);
            expect(saved.modeOn(m, m.teachingDate!), mode);
          }
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(values, hasLength(1049));
        expect(count, 43018);
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(1049));
        for (final c in restored.materializeClasses()) {
          expect(c.isValid, true);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      },
    );
  }
}
