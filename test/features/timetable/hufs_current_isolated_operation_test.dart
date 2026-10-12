import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'hufs_frozen_isolated_v6_fixture.dart' as frozen_v6;

const folder =
    'work/university-research/catalog-t/hufs-isolated-operation-v7-20261009';
const baselineFolder =
    'work/university-research/catalog-t/hufs-isolated-operation-v6-20261009';
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
  frozen_v6.main();
  final proofs = {
    for (final p
        in jsonDecode(
              File('$folder/reviewed21-source-proofs.json').readAsStringSync(),
            )
            as List)
      p['sourceId']: p,
  };
  final raw = {
    for (final campus in ['seoul', 'global'])
      campus: read(
        '$folder/hufs-$campus-2026-2.isolated-operation-v7-research.json',
      ),
  };
  final all = [
    for (final d in raw.values) ...UniversityDataset.fromJson(d).courses,
  ];
  test('whole3372 prior2404deep and outside21 unchanged', () {
    expect(all, hasLength(3372));
    expect(all.map((c) => c.sourceId).toSet(), hasLength(3372));
    expect(all.where((c) => c.hasSchedulableMeetings), hasLength(2425));
    expect(all.expand((c) => c.meetings), hasLength(35057));
    var previous = 0;
    var previousMeetings = 0;
    for (final campus in ['seoul', 'global']) {
      final old =
          read(
                '$baselineFolder/hufs-$campus-2026-2.isolated-operation-v6-research.json',
              )['courses']
              as List;
      final current = raw[campus]!['courses'] as List;
      expect(current, hasLength(old.length));
      for (var i = 0; i < old.length; i++) {
        final c = current[i] as Map<String, dynamic>;
        expect(c['sourceId'], old[i]['sourceId']);
        previous += (old[i]['schedules'] as List).isEmpty ? 0 : 1;
        previousMeetings += (old[i]['schedules'] as List).length;
        if (!proofs.containsKey(c['sourceId'])) {
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
    expect(previous, 2404);
    expect(previousMeetings, 34814);
  });
  test(
    'independent source SHA current identity whole header and 243 partial reservations',
    () {
      final validation = read(
        '$folder/source-only-independent-validation.json',
      );
      expect(validation['result'], 'PASS');
      for (final entry in (validation['sourceSha256'] as Map).entries) {
        expect(
          sha256
              .convert(File(entry.key as String).readAsBytesSync())
              .toString(),
          entry.value,
        );
      }
      expect(proofs, hasLength(21));
      var total = 0;
      for (final c in all.where((c) => proofs.containsKey(c.sourceId))) {
        final p = proofs[c.sourceId];
        final source = read(p['sourcePlanPath'] as String);
        expect(source, p['educationPlan']);
        expect(source['fields']['identity'], endsWith('${c.code}${c.section}'));
        expect(
          source['fields']['schedule'].split('\n').first,
          c.sourceSchedule,
        );
        final actual = [
          for (final m in c.meetings)
            {
              'weekday': m.weekday,
              'startMinute': m.originalStartMinute,
              'endMinute': m.originalEndMinute,
              'classroom': m.classroom,
              'date': m.date,
            },
        ];
        expect(actual, p['reservations']);
        total += actual.length;
        for (var i = 0; i < c.meetings.length; i++) {
          for (final other in c.meetings.skip(i + 1)) {
            final m = c.meetings[i];
            if (m.date == other.date) {
              expect(
                m.originalEndMinute <= other.originalStartMinute ||
                    other.originalEndMinute <= m.originalStartMinute,
                true,
              );
            }
          }
        }
      }
      expect(total, 243);
    },
  );
  test(
    'individual printed assessment dates override school middle period or shifted week labels',
    () {
      for (final id in ['E114561/01', 'E114561/02']) {
        final c = all.singleWhere((c) => c.sourceId.endsWith(id));
        expect(c.meetings.where((m) => m.date == '2026-10-22'), hasLength(1));
        expect(c.meetings.where((m) => m.date == '2026-10-29'), isEmpty);
      }
      final africa = all.singleWhere((c) => c.sourceId.endsWith('U541203/01'));
      expect(
        africa.meetings.where((m) => m.date == '2026-10-26'),
        hasLength(1),
      );
      expect(africa.meetings.where((m) => m.date == '2026-11-02'), isEmpty);
      final stats = all.singleWhere((c) => c.sourceId.endsWith('Q020011/09'));
      expect(stats.meetings.where((m) => m.date == '2026-10-23'), isEmpty);
      expect(stats.meetings.where((m) => m.date == '2026-11-06'), hasLength(1));
    },
  );
  test('isolated VOD dates only and all v5 meaningful holds unchanged', () {
    final international = all.singleWhere(
      (c) => c.sourceId.endsWith('C013095/01'),
    );
    expect(
      international.meetings.where((m) => m.date == '2026-09-11'),
      isEmpty,
    );
    expect(
      international.meetings.where((m) => m.date == '2026-09-18'),
      hasLength(1),
    );
    final ethics = all.singleWhere((c) => c.sourceId.endsWith('Y211541/01'));
    expect(
      ethics.meetings.where(
        (m) => ['2026-10-19', '2026-10-26'].contains(m.date),
      ),
      isEmpty,
    );
    expect(ethics.meetings.where((m) => m.date == '2026-11-02'), hasLength(1));
    for (final hold in read(
      'work/university-research/catalog-t/hufs-late-operation-v5-20261009/candidate-audit.json',
    )['held']) {
      expect(
        all.singleWhere((c) => c.sourceId == hold['sourceId']).meetings,
        isEmpty,
      );
    }
  });
  test('whole2425 allthree usermodes and fullDrive document equality', () {
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
      expect(records, hasLength(2425));
      final document = TimetableSyncDocument.records(courses: records);
      final encoded = jsonEncode(document.toJson());
      final decoded = TimetableSyncDocument.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.toJson(), document.toJson());
    }
  });
}
