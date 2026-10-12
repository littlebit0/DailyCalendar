import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-t/hufs-isolated-operation-v6-20261009';
const baselineFolder =
    'work/university-research/catalog-t/hufs-late-operation-v5-20261009';
Map<String, dynamic> read(String p) =>
    jsonDecode(fixtureFile(p).readAsStringSync()) as Map<String, dynamic>;
void main() {
  final proofs = {
    for (final p
        in jsonDecode(
              fixtureFile(
                '$folder/reviewed24-source-proofs.json',
              ).readAsStringSync(),
            )
            as List)
      p['sourceId']: p,
  };
  final raw = {
    for (final campus in ['seoul', 'global'])
      campus: read(
        '$folder/hufs-$campus-2026-2.isolated-operation-v6-research.json',
      ),
  };
  final all = [
    for (final d in raw.values) ...UniversityDataset.fromJson(d).courses,
  ];
  test('whole3372 prior2380deep and outside24 unchanged', () {
    expect(all, hasLength(3372));
    expect(all.map((c) => c.sourceId).toSet(), hasLength(3372));
    expect(all.where((c) => c.hasSchedulableMeetings), hasLength(2404));
    expect(all.expand((c) => c.meetings), hasLength(34814));
    var previous = 0;
    var previousMeetings = 0;
    for (final campus in ['seoul', 'global']) {
      final old =
          read(
                '$baselineFolder/hufs-$campus-2026-2.late-operation-v5-research.json',
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
    expect(previous, 2380);
    expect(previousMeetings, 34568);
  });
  test(
    'independent source SHA current identity whole header and 246 partial reservations',
    () {
      final validation = read(
        '$folder/source-only-independent-validation.json',
      );
      expect(validation['result'], 'PASS');
      for (final entry in (validation['sourceSha256'] as Map).entries) {
        expect(
          sha256
              .convert(fixtureFile(entry.key as String).readAsBytesSync())
              .toString(),
          entry.value,
        );
      }
      expect(proofs, hasLength(24));
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
      expect(total, 246);
    },
  );
  test(
    'direct VOD and assessment dates omitted without seventh-week arithmetic',
    () {
      final russian = all.singleWhere((c) => c.sourceId.endsWith('A043103/01'));
      expect(
        russian.meetings.where(
          (m) => m.date == '2026-09-16' || m.date == '2026-10-21',
        ),
        isEmpty,
      );
      final film = all.singleWhere((c) => c.sourceId.endsWith('A044643/01'));
      expect(
        film.meetings.where(
          (m) => [
            '2026-09-10',
            '2026-09-17',
            '2026-09-24',
            '2026-10-22',
          ].contains(m.date),
        ),
        isEmpty,
      );
      final stats = all.singleWhere((c) => c.sourceId.endsWith('D024661/01'));
      expect(stats.meetings.where((m) => m.date == '2026-10-15'), hasLength(1));
      expect(stats.meetings.where((m) => m.date == '2026-10-22'), isEmpty);
      final culture = all.singleWhere((c) => c.sourceId.endsWith('C044922/01'));
      expect(
        culture.meetings.where((m) => m.date == '2026-10-22'),
        hasLength(1),
      );
    },
  );
  test(
    'weekday VOD and own-calendar first-half scope, prior12 meaningful holds unchanged',
    () {
      final math = all.singleWhere((c) => c.sourceId.endsWith('Q020181/01'));
      expect(math.meetings, hasLength(11));
      expect(math.meetings.every((m) => m.weekday == 5), true);
      final career = all.where(
        (c) => c.code == 'Y121034' && proofs.containsKey(c.sourceId),
      );
      expect(career, hasLength(6));
      expect(career.expand((c) => c.meetings), hasLength(33));
      for (final c in career) {
        expect(
          c.meetings.every(
            (m) => m.date != null && m.date!.compareTo('2026-10-19') <= 0,
          ),
          true,
        );
      }
      for (final hold in read('$baselineFolder/candidate-audit.json')['held']) {
        expect(
          all.singleWhere((c) => c.sourceId == hold['sourceId']).meetings,
          isEmpty,
        );
      }
    },
  );
  test('whole2404 allthree usermodes and fullDrive document equality', () {
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
      expect(records, hasLength(2404));
      final document = TimetableSyncDocument.records(courses: records);
      final encoded = jsonEncode(document.toJson());
      final decoded = TimetableSyncDocument.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      expect(decoded.toJson(), document.toJson());
    }
  });
}
