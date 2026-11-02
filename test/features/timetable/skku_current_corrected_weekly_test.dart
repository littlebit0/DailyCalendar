import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/skku-held-own-operation-v25b-20261009';
dynamic read(String name) {
  final actual = '$dir/$name';
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
        read('skku-humanities-2026-2.own-operation-v25b.json')
            as Map<String, dynamic>,
    'naturalScience':
        read('skku-naturalScience-2026-2.own-operation-v25b.json')
            as Map<String, dynamic>,
  };
  final all = datasets.values.expand((d) => d['courses'] as List).toList();
  test(
    'Six exact current sources with preserved scopes and independent plans76;41wholeheld',
    () {
      final receipt =
          read('independent-literal-date-validation.json')['byCourse'] as List;
      var count = 0;
      for (final r in receipt) {
        final key = r['offeringCode'] as String;
        final c = all.singleWhere((c) => c['sourceId'] == r['sourceId']);
        final e =
            c[key.startsWith('GELT012')
                ? 'reservationEvidenceV24'
                : 'reservationEvidenceV25'];
        final src = e['exactCurrentPublicSource'];
        final d = src['detail'][0];
        expect(d['GAESUL_YEAR'], '2026');
        expect(d['GAESUL_TERM'], '20');
        expect(d['HAKSU_NO'], c['courseCode']);
        expect(d['BUNBAN'], c['section']);
        expect(d['PER_NAME'], c['professor']);
        expect(src['sourceRow']['GYOSI_NAME'], c['sourceSchedule']);
        expect(c['partialCoverage'], true);
        expect(
          e['exactFullPublicAttachmentEducation']['fullEducationalTextRead'],
          true,
        );
        expect(e['exactFullPublicAttachmentEducation']['rawBytesSaved'], false);
        expect(e['ordinalProjectionApplied'], false);
        final expected = r['expectedSchedulesLiteral'] as List;
        expect(c['schedules'], expected);
        for (final m in expected) {
          expect(DateTime.parse(m['date']).weekday, m['weekday']);
        }
        count += expected.length;
      }
      expect(count, 76);
      final conflict = read(
        'withdrawn-41-external-current-condition-conflict.json',
      );
      final c = all.singleWhere(
        (c) => c['sourceId'] == 'skku-2026-2-GELT012-41',
      );
      expect(c, conflict['restoredSourceObject']);
      expect(c['schedules'], isEmpty);
      expect(conflict['withdrawnUnprojectedProposedSchedules'], hasLength(6));
    },
  );
  test('2776 otherwhole and1777 priorwhole48975 plans preserved', () {
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
    expect(unchanged, 2776);
    expect(oldscheduled, 1773);
    expect(oldplans, 48951);
  });
  test('All1779 actualmodels49027 plans oneuserdefaults fullDrive v2', () {
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
      expect(total, 49027);
      expect(values, hasLength(1779));
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
      expect(restored, hasLength(1779));
      for (final c in restored) {
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
      }
    }
  });
}
