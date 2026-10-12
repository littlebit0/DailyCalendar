import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/skku-held-own-operation-v152-20261009';
dynamic read(String n) {
  final actual = '$dir/$n';
  final data = jsonDecode(fixtureFile(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

void main() {
  final bases = {
    for (final campus in ['humanities', 'naturalScience', 'icampus'])
      campus: read('baseline-skku-$campus-2026-2.json') as Map<String, dynamic>,
  };
  final datasets = {
    ...bases,
    'naturalScience':
        read('skku-naturalScience-2026-2.own-operation-v152.json')
            as Map<String, dynamic>,
  };
  final all = datasets.values.expand((d) => d['courses'] as List).toList();
  final receipt = read('independent-literal-date-validation.json');
  final target = all.singleWhere(
    (c) => '${c['courseCode']}-${c['section']}' == 'ENA2028-41',
  );
  test('Current own source identity and native weekly conservative scope', () {
    final e = target['reservationEvidenceV152'];
    final f = read('ena2028-41-attachment1-full-education.json');
    expect(f['fullEducationalTextRead'], true);
    final scope = read('independent-native-weekly-date-scope-proof.json');
    expect(scope['plannedDatesAreOwnPrintedLiterals'], false);
    expect(scope['specificOwnOrdinalWeeksGregorianConfirmed'], false);
    expect(
      target['schedules'],
      scope['expectedNativeRegularPlannedSchedulesIndependentlyListed'],
    );
    expect(RegExp(r'강\s*승\s*구').hasMatch(f['educationFullText']), true);
    expect(e['ownHHPrinted'], false);
    expect(e['ownTermPrinted'], false);
    expect(e['sourceActualLiteralDates'], isEmpty);
    expect(f['rawBytesSaved'], false);
    final link = e['directSchoolCurrentPrimaryLocatorEvidence'];
    final observed = link['files'].singleWhere(
      (x) =>
          x['educationalFile'] == 'ena2028-41-attachment1-full-education.json',
    );
    expect(observed['rawSHA256'], f['sha256']);
    expect(f['currentFileRow']['GAESUL_YEAR'], '2026');
    expect(f['currentFileRow']['GAESUL_TERM'], '20');
    expect(
      '${f['currentFileRow']['HAKSU_NO']}-${f['currentFileRow']['BUNBAN']}',
      'ENA2028-41',
    );
    expect(e['sourceSectionPrinted'], false);
    expect(e['ordinalProjectionApplied'], false);
    expect(e['plannedDatesDerivedFromNativeSemester'], true);
    expect(target['partialCoverage'], true);
    expect(
      target['schedules'],
      receipt['byCourse'][0]['expectedSchedulesLiteral'],
    );
    for (final m in target['schedules']) {
      expect(DateTime.parse(m['date']).weekday, m['weekday']);
      expect(
        (target['rawMeetingFrameForReviewOnly'] as List).any(
          (f) =>
              f['weekday'] == m['weekday'] &&
              f['startMinute'] == m['startMinute'] &&
              f['endMinute'] == m['endMinute'] &&
              f['classroom'] == m['classroom'],
        ),
        true,
      );
      expect(m['deliveryMode'], isNull);
    }
    expect((target['schedules'] as List).length, 27);
  });
  test('All prior whole objects and native fields unchanged', () {
    var unchanged = 0, oldcount = 0, oldplans = 0;
    for (final d in bases.values) {
      for (final b in d['courses']) {
        final c = all.singleWhere((c) => c['sourceId'] == b['sourceId']);
        if (c['sourceId'] == target['sourceId']) {
          expect(b['schedules'], isEmpty);
          for (final k in (b as Map).keys) {
            if (![
              'schedules',
              'scheduleStatus',
              'unresolvedReasons',
              'researchOnly',
              'scheduleEvidenceKind',
              'actualAttendanceConfirmed',
              'commonClosureDatesApplied',
              'period',
              'departmentRemarks',
              'partialCoverage',
            ].contains(k)) {
              expect(c[k], b[k]);
            }
          }
          expect(c['priorHeldDepartmentRemarks'], b['departmentRemarks']);
        } else {
          expect(c, b);
          unchanged++;
          if ((b['schedules'] as List).isNotEmpty) {
            oldcount++;
            oldplans += (b['schedules'] as List).length;
          }
        }
      }
    }
    expect(unchanged, 2781);
    expect(oldcount, 1829);
    expect(oldplans, 49999);
  });
  test('Whole actual models all three user defaults and full Drive v2', () {
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final values = <String, TimetableSyncValue>{};
      var total = 0;
      for (final d in datasets.values) {
        for (final c in UniversityDataset.fromJson(d).courses) {
          final raw = all.singleWhere((v) => v['sourceId'] == c.sourceId);
          final plans = raw['schedules'] as List;
          if (plans.isEmpty) continue;
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.defaultMode, mode);
          expect(saved.isValid, true);
          if (c.sourceId == target['sourceId']) {
            expect(saved.note, contains('원문'));
          }
          expect(saved.meetings, hasLength(plans.length));
          for (var i = 0; i < plans.length; i++) {
            final m = saved.meetings[i], p = plans[i];
            expect(m.date, p['date']);
            expect(m.originalStartMinute, p['startMinute']);
            expect(m.originalEndMinute, p['endMinute']);
            expect(m.classroom, p['classroom']);
            final forced = switch (p['deliveryMode']) {
              'inPerson' => LectureMode.inPerson,
              'liveOnline' => LectureMode.liveOnline,
              _ => mode,
            };
            expect(saved.modeOn(m, m.teachingDate!), forced);
            expect(saved.period!.contains(m.teachingDate!), true);
            total++;
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 9),
            'research',
          );
        }
      }
      expect(total, 50026);
      expect(values, hasLength(1830));
      final doc =
          jsonDecode(
                jsonEncode(
                  TimetableSyncDocument.records(
                    courses: values,
                    schemaVersion: 2,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      final restored = TimetableSyncDocument.fromJson(doc).materializeClasses();
      expect(restored, hasLength(1830));
      for (final c in restored) {
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
      }
    }
  });
}
