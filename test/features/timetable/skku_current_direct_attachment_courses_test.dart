import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/skku-held-own-operation-v55-20261009';
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
    'humanities':
        read('skku-humanities-2026-2.own-operation-v55.json')
            as Map<String, dynamic>,
  };
  final all = datasets.values.expand((d) => d['courses'] as List).toList();
  test(
    'Exact current education role, source association and literal seventy plans',
    () {
      final source =
          read('source-current-attachment-identity.json')['records'] as List;
      final receipt =
          read('independent-literal-date-validation.json')['byCourse'] as List;
      var count = 0;
      for (final r in source) {
        final key = r['offeringCode'] as String;
        final c = all.singleWhere(
          (c) => '${c['courseCode']}-${c['section']}' == key,
        );
        final d = r['detail'][0];
        expect(d['GAESUL_YEAR'], '2026');
        expect(d['GAESUL_TERM'], '20');
        expect(d['PER_NAME'], c['professor']);
        expect(d['HAKSU_NO'], c['courseCode']);
        expect(d['BUNBAN'], c['section']);
        expect(r['sourceRow']['GYOSI_NAME'], c['sourceSchedule']);
        expect(c['partialCoverage'], true);
        final f = read('${key.toLowerCase()}-full-education.json');
        expect(f['fullEducationalTextRead'], true);
        expect(f['rawBytesSaved'], false);
        final text = f['educationFullText'] as String;
        expect(text, contains('2026'));
        expect(c['reservationEvidenceV55']['ownCodePrinted'], false);
        final link =
            c['reservationEvidenceV55']['directSchoolCurrentPrimaryLocatorEvidence'];
        expect(link['currentLocatorBytesEqualFrozenEducation'], true);
        expect(link['downloadedCurrentLocatorRawSHAOnly'], f['sha256']);
        expect(
          c['reservationEvidenceV55']['currentSchoolCodeSectionLocatorConfirmed'],
          true,
        );
        expect(c['reservationEvidenceV55']['sourceSectionPrinted'], false);
        expect(
          c['reservationEvidenceV55']['exactFullPublicAttachmentEducation']['sha256'],
          f['sha256'],
        );
        expect(c['reservationEvidenceV55']['ordinalProjectionApplied'], false);
        expect(
          c['reservationEvidenceV55']['plannedDatesDerivedFromNativeSemester'],
          false,
        );
        expect(
          c['reservationEvidenceV55']['sourceActualLiteralDates'],
          isNotEmpty,
        );
        final expected =
            receipt.singleWhere(
                  (x) => x['offeringCode'] == key,
                )['expectedSchedulesLiteral']
                as List;
        expect(c['schedules'], expected);
        for (final m in expected) {
          expect(DateTime.parse(m['date']).weekday, m['weekday']);
        }
        count += expected.length;
      }
      expect(count, 70);
    },
  );
  test('2779 other whole and1800 prior classes49434 plans preserved', () {
    var unchanged = 0, oldscheduled = 0, oldplans = 0;
    for (final dataset in bases.values) {
      for (final b in dataset['courses']) {
        final c = all.singleWhere((c) => c['sourceId'] == b['sourceId']);
        if ((read('independent-literal-date-validation.json')['byCourse']
                as List)
            .map((r) => r['sourceId'])
            .toList()
            .contains(b['sourceId'])) {
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
            oldscheduled++;
            oldplans += (b['schedules'] as List).length;
          }
        }
      }
    }
    expect(unchanged, 2779);
    expect(oldscheduled, 1800);
    expect(oldplans, 49434);
  });
  test('All1803 actual models49504 plans three user defaults fullDrive v2', () {
    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final values = <String, TimetableSyncValue>{};
      var total = 0;
      for (final dataset in datasets.values) {
        for (final c in UniversityDataset.fromJson(dataset).courses) {
          final plans =
              all.singleWhere((v) => v['sourceId'] == c.sourceId)['schedules']
                  as List;
          if (plans.isEmpty) continue;
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.defaultMode, mode);
          expect(saved.isValid, true);

          if ((read('independent-literal-date-validation.json')['byCourse']
                  as List)
              .any((r) => r['sourceId'] == c.sourceId)) {
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
      expect(total, 49504);
      expect(values, hasLength(1803));
      final document =
          jsonDecode(
                jsonEncode(
                  TimetableSyncDocument.records(
                    courses: values,
                    schemaVersion: 2,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>;
      final restored = TimetableSyncDocument.fromJson(
        document,
      ).materializeClasses();
      expect(restored, hasLength(1803));
      for (final c in restored) {
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
      }
    }
  });
}
