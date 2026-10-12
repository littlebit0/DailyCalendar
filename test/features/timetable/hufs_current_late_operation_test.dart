import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-t/hufs-late-operation-v5-20261009';
const v4 =
    'work/university-research/catalog-t/hufs-partial-operation-v4-20261009';
const prior = 'work/university-research/catalog-t';
Map<String, dynamic> read(String path) {
  final actual = path;
  final data =
      jsonDecode(File(actual).readAsStringSync()) as Map<String, dynamic>;
  if (data['courses'] is List) {
    data['researchOnly'] = false;
    for (final row in data['courses']) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  final sourceValidation = read(
    '$folder/source-only-independent-validation.json',
  );
  final proofs = {
    for (final p
        in jsonDecode(
              File('$v4/reviewed-source-proofs.json').readAsStringSync(),
            )
            as List)
      p['sourceId']: p,
  };
  final additions = {
    for (final p
        in jsonDecode(
              File('$folder/added174-source-proofs.json').readAsStringSync(),
            )
            as List)
      p['sourceId']: p,
  };
  final changed = {...proofs.keys, ...additions.keys};
  final raw = {
    for (final campus in ['seoul', 'global'])
      campus: read(
        '$folder/hufs-$campus-2026-2.late-operation-v5-research.json',
      ),
  };
  final all = [
    for (final doc in raw.values) ...UniversityDataset.fromJson(doc).courses,
  ];
  test('whole3372 prior2196deep and known other operations unchanged', () {
    expect(all, hasLength(3372));
    expect(all.map((c) => c.sourceId).toSet(), hasLength(3372));
    expect(all.where((c) => c.hasSchedulableMeetings), hasLength(2380));
    expect(all.expand((c) => c.meetings), hasLength(34568));
    expect(proofs, hasLength(10));
    for (final entry in (sourceValidation['sourceSha256'] as Map).entries) {
      expect(
        sha256.convert(File(entry.key as String).readAsBytesSync()).toString(),
        entry.value,
      );
    }
    var oldScheduled = 0;
    var oldMeetings = 0;
    for (final campus in ['seoul', 'global']) {
      final baseline = read(
        '$prior/hufs-$campus-2026-2.checkpoint-review-3.json',
      );
      final old = baseline['courses'] as List;
      final current = raw[campus]!['courses'] as List;
      expect(current, hasLength(old.length));
      for (var i = 0; i < old.length; i++) {
        final c = current[i] as Map<String, dynamic>;
        expect(c['sourceId'], old[i]['sourceId']);
        oldScheduled += (old[i]['schedules'] as List).isNotEmpty ? 1 : 0;
        oldMeetings += (old[i]['schedules'] as List).length;
        if (!changed.contains(c['sourceId'])) {
          expect(c, old[i]);
        } else {
          final restored = Map<String, dynamic>.from(c);
          for (final field in [
            'schedules',
            'scheduleStatus',
            'departmentRemarks',
          ]) {
            restored[field] = old[i][field];
          }
          expect(restored, old[i]);
        }
      }
    }
    expect(oldScheduled, 2196);
    expect(oldMeetings, 31920);
    for (final key in [
      'P013112/01',
      'P013112/02',
      'O133142/01',
      'U515233/01',
      'C024871/01',
    ]) {
      expect(
        all.singleWhere((c) => c.sourceId.endsWith(key)).meetings,
        isEmpty,
      );
    }
  });
  test(
    'all10 independent native periods room owncalendar and partialday proof',
    () {
      final dayPattern = RegExp(r'([월화수목금토일])\s+([0-9 ]+)\s+\(([^)]+)\)');
      final holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      var added = 0;
      for (final c in all.where((c) => proofs.containsKey(c.sourceId))) {
        final p = proofs[c.sourceId];
        final source = read(p['planPath'] as String);
        expect(source['fields']['identity'], endsWith('${c.code}${c.section}'));
        expect(
          source['fields']['schedule'].split('\n').first,
          c.sourceSchedule,
        );
        expect(
          sha256
              .convert(File(p['planPath'] as String).readAsBytesSync())
              .toString(),
          p['planSha256'],
        );
        var literal = c.sourceSchedule;
        if (c.campus == 'global') {
          literal =
              '${literal.split(c.code == 'M012061' ? ' 목' : ' 금').first} (${c.sourceClassroom})';
          expect(source['fields']['methods'], contains('대부분 녹화강의'));
        }
        final match = dayPattern.firstMatch(literal)!;
        final weekday = '월화수목금토일'.indexOf(match[1]!) + 1;
        final periods = match[2]!
            .trim()
            .split(RegExp(r'\s+'))
            .map(int.parse)
            .toList();
        final start = (8 + periods.first) * 60;
        final end = (8 + periods.last) * 60 + 50;
        final expected = <String>{};
        for (
          var d = DateTime(2026, 9, 1);
          !d.isAfter(DateTime(2026, 12, 7));
          d = d.add(const Duration(days: 1))
        ) {
          final date = d.toIso8601String().substring(0, 10);
          if (d.weekday != weekday ||
              holidays.contains(date) ||
              (p['individualKnownNoClassDates'] as List).contains(date)) {
            continue;
          }
          if (p['individualWeek8Exam'] == true &&
              !d.isBefore(DateTime(2026, 10, 20)) &&
              !d.isAfter(DateTime(2026, 10, 26))) {
            continue;
          }
          expected.add('$date|$weekday|$start|$end|${match[3]}');
        }
        final actual = c.meetings
            .map(
              (m) =>
                  '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
            )
            .toList();
        expect(actual.toSet(), expected);
        expect(actual, hasLength(expected.length));
        expect(p['attendanceConfirmed'], false);
        expect(p['examTimeConfirmed'], false);
        expect(p['freshRequeryPerformed'], false);
        expect(c.period?.toJson()['startDate'], '2026-09-01');
        expect(c.period?.toJson()['endDate'], '2026-12-07');
        added += c.meetings.length;
      }
      expect(added, 128);
      expect(
        all.singleWhere((c) => c.sourceId.endsWith('M012061/01')).meetings,
        hasLength(13),
      );
      expect(
        all.singleWhere((c) => c.sourceId.endsWith('M013081/01')).meetings,
        hasLength(12),
      );
    },
  );
  test('all174 full source native header independent days room and own dates', () {
    expect(additions, hasLength(174));
    var total = 0;
    final holidays = {
      '2026-09-24',
      '2026-09-25',
      '2026-09-26',
      '2026-10-03',
      '2026-10-05',
      '2026-10-09',
    };
    for (final c in all.where((c) => additions.containsKey(c.sourceId))) {
      final p = additions[c.sourceId];
      final plan = read(p['sourcePlanPath'] as String);
      expect(plan['key'], '${c.code}${c.section}');
      expect(plan['fields']['title'], startsWith(c.title));
      expect(plan['fields']['schedule'].split('\n').first, c.sourceSchedule);
      expect(
        sha256
            .convert(File(p['sourcePlanPath'] as String).readAsBytesSync())
            .toString(),
        p['sourcePlanSHA256'],
      );
      final rules = <Map<String, dynamic>>[];
      for (final block in RegExp(
        r'([^()]+)\(([^()]+)\)',
      ).allMatches(c.sourceSchedule)) {
        for (final match in RegExp(
          r'([월화수목금토일])\s+([0-9 ]+)',
        ).allMatches(block[1]!)) {
          final periods = match[2]!
              .trim()
              .split(RegExp(r'\s+'))
              .map(int.parse)
              .toList();
          expect(periods.every((p) => p >= 1 && p <= 12), true);
          rules.add({
            'weekday': '월화수목금토일'.indexOf(match[1]!) + 1,
            'start': (8 + periods.first) * 60,
            'end': (8 + periods.last) * 60 + 50,
            'room': block[2],
          });
        }
      }
      final operation = p['operationDecision'];
      final expected = <String>{};
      for (
        var d = DateTime(2026, 9, 1);
        !d.isAfter(DateTime(2026, 12, 7));
        d = d.add(const Duration(days: 1))
      ) {
        final date = d.toIso8601String().substring(0, 10);
        if (holidays.contains(date)) {
          continue;
        }
        for (final rule in rules) {
          if (d.weekday != rule['weekday']) {
            continue;
          }
          final exceptionDays = operation['midtermExceptionWeekdays'] as List?;
          if (operation['individualMidtermExclude'] == true &&
              !d.isBefore(DateTime(2026, 10, 20)) &&
              !d.isAfter(DateTime(2026, 10, 26)) &&
              (exceptionDays == null || exceptionDays.contains(d.weekday))) {
            continue;
          }
          expected.add(
            '$date|${d.weekday}|${rule['start']}|${rule['end']}|${rule['room']}',
          );
        }
      }
      final actual = c.meetings
          .map(
            (m) =>
                '${m.date}|${m.weekday}|${m.originalStartMinute}|${m.originalEndMinute}|${m.classroom}',
          )
          .toList();
      expect(actual.toSet(), expected);
      expect(actual, hasLength(expected.length));
      for (var i = 0; i < c.meetings.length; i++) {
        final meeting = c.meetings[i];
        for (final other in c.meetings.skip(i + 1)) {
          if (other.date == meeting.date) {
            expect(
              meeting.originalEndMinute <= other.originalStartMinute ||
                  other.originalEndMinute <= meeting.originalStartMinute,
              true,
            );
          }
        }
      }
      total += c.meetings.length;
    }
    expect(total, 2520);
    final bio = all.singleWhere((c) => c.sourceId.endsWith('F033521/01'));
    expect(bio.meetings.where((m) => m.date == '2026-10-20'), hasLength(1));
    expect(bio.meetings.where((m) => m.date == '2026-10-21'), isEmpty);
  });
  test(
    'twelve meaningful holds preserved and late pool fully source-reviewed',
    () {
      final audit = read('$folder/candidate-audit.json');
      final review = read('$folder/late186-full-operation-decisions.json');
      expect(review['counts'], {'reviewed': 186, 'eligible': 174, 'held': 12});
      expect(review['decisions'], hasLength(186));
      for (final entry in review['decisions']) {
        expect(entry['wholeRetainedOperatingTextReviewed'], true);
        expect(entry['noWeekNumberDateInference'], true);
      }
      for (final hold in audit['held']) {
        expect(
          all.singleWhere((c) => c.sourceId == hold['sourceId']).meetings,
          isEmpty,
        );
      }
    },
  );
  test('whole2380 allthree usermodes and fullDrive document equality', () {
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final records = <String, TimetableSyncValue>{};
      for (final c in all.where((c) => c.hasSchedulableMeetings)) {
        final t = c.toTimetable(id: c.sourceId, mode: mode);
        expect(t.isValid, true, reason: c.sourceId);
        expect(t.defaultMode, mode);
        final restored = TimetableClass.fromJson(t.toJson());
        expect(restored.toJson(), t.toJson());
        final key = timetableCourseSyncKey(t);
        expect(records.containsKey(key), false);
        records[key] = TimetableSyncValue(
          {...t.toJson(), 'id': key},
          DateTime.utc(2026, 10, 9),
          'research',
        );
      }
      expect(records, hasLength(2380));
      final document = TimetableSyncDocument.records(courses: records);
      final encoded = jsonEncode(document.toJson());
      final decoded = TimetableSyncDocument.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.toJson(), document.toJson());
    }
  });
}
