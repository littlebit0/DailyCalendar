import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory =
    'work/university-research/catalog-r/dgist-lab-weekly-reservations-v2-20261008';
const sourceDirectory = 'work/university-research/catalog-r';
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
String hash(String path) =>
    sha256.convert(fixtureFile(path).readAsBytesSync()).toString();
void main() {
  final audit = read('$directory/lab-weekly-audit-v2.json');
  final raw = read('$directory/${audit['candidateFile']}');
  final base = read(audit['baseFile']);
  final courses = (raw['courses'] as List).cast<Map<String, dynamic>>();
  final model = UniversityDataset.fromJson(raw);
  final classification =
      jsonDecode(
            fixtureFile(
              '$directory/all569-classification-v2.json',
            ).readAsStringSync(),
          )
          as List;
  final added = classification
      .where((r) => r['status'] == 'ordinaryNativeWeeklyReservation')
      .map((r) => r['offering'])
      .toSet();
  final nativeByCurriculum = <String, Map<String, dynamic>>{};
  for (final year in ['2020', '2024', '2014']) {
    final rows =
        jsonDecode(
              fixtureFile(
                '$sourceDirectory/dgist2026-2-$year-current-recheck-20261008.json',
              ).readAsStringSync(),
            )
            as List;
    nativeByCurriculum[year] = {
      for (final r in rows) '${r['SBJT_NO']}-${r['CLSS_NO']}': r,
    };
  }
  test(
    'whole569 source-native variants exact, prior150 and374held deep unchanged',
    () {
      expect(
        hash('$directory/${audit['candidateFile']}'),
        audit['candidateSHA256'],
      );
      expect(
        hash(audit['baseFile']),
        '1300a869120e6c1fd68c4ac13a3f6a421938b2809da05955867199fd9bbebf35',
      );
      expect(courses, hasLength(569));
      expect(
        model.courses.where((c) => c.hasSchedulableMeetings),
        hasLength(195),
      );
      expect(model.courses.expand((c) => c.meetings), hasLength(4058));
      expect(added, hasLength(45));
      var existing = 0;
      var held = 0;
      for (var i = 0; i < courses.length; i++) {
        final course = courses[i];
        final before = base['courses'][i];
        final offering = '${course['courseCode']}-${course['section']}';
        for (final variant
            in course['sourceEducationalMetadata']['curriculumVariants']) {
          final row =
              nativeByCurriculum[variant['curriculum']]![offering] as Map;
          expect(variant['fields'], row);
          expect(row['SHYY'], '2026');
          expect(row['SHTM_DCD'], 'CMN17.20');
          expect(row['ORGN_CLSF_NM'], '대학');
          expect(course['sourceSchedule'], row['TLSN_TIME']);
          expect(course['professor'], row['PROF_NM']);
          expect(course['credits'], double.parse(row['PNT']));
          if (added.contains(offering)) {
            expect(row['TLSN_TIME'], isNotEmpty);
          }
        }
        for (final field in [
          'sourceId',
          'campus',
          'courseCode',
          'section',
          'courseName',
          'professor',
          'credits',
          'classification',
          'sourceSchedule',
          'sourceClassroom',
          'sourceEducationalMetadata',
          'departmentCredits',
        ]) {
          expect(course[field], before[field]);
        }
        if (!added.contains(offering)) {
          expect(jsonEncode(course), jsonEncode(before));
          if ((before['schedules'] as List).isEmpty) {
            held++;
          } else {
            existing++;
          }
        } else {
          expect(before['schedules'], isEmpty);
          expect(course['reservationEvidence']['sourceWeekIndexUsed'], false);
          expect(
            course['reservationEvidence']['dateMeaning'],
            'derivedRegularWeeklyReservationNotSourcePublishedAttendance',
          );
          expect(
            course['reservationEvidence']['sourcePublishedIndividualDatesClaim'],
            false,
          );
        }
      }
      expect(existing, 150);
      expect(held, 374);
      for (final c in courses.where(
        (c) =>
            (c['courseCode'] as String).startsWith('RP') ||
            (c['courseCode'] as String).startsWith('INT'),
      )) {
        expect(c['schedules'], isEmpty);
      }
      for (final key in ['HSS123-01', 'HSS221-01', 'MSE302-01', 'LS313a-01']) {
        expect(
          courses.singleWhere(
            (c) => '${c['courseCode']}-${c['section']}' == key,
          )['schedules'],
          isEmpty,
        );
      }
    },
  );
  test(
    'native minute room and independent term/date/individual exclusions',
    () {
      final excluded = (audit['globalExcludedDates'] as List)
          .cast<String>()
          .toSet();
      const days = {'월': 1, '화': 2, '수': 3, '목': 4, '금': 5, '토': 6, '일': 7};
      var count = 0;
      for (final c in courses.where(
        (c) => added.contains('${c['courseCode']}-${c['section']}'),
      )) {
        final direct = RegExp(
          r'([월화수목금토일])(\d{2}):(\d{2})-(\d{2}):(\d{2})\(([^()]*)\)',
        ).allMatches(c['sourceSchedule']);
        final individual =
            (c['reservationEvidence']['excludedIndividualDates'] as List)
                .cast<String>()
                .toSet();
        final expected = <Map<String, dynamic>>[];
        for (
          var d = DateTime(2026, 8, 24);
          !d.isAfter(DateTime(2026, 12, 11));
          d = d.add(const Duration(days: 1))
        ) {
          final date = timetableDateKey(d);
          if (excluded.contains(date) || individual.contains(date)) {
            continue;
          }
          for (final m in direct) {
            if (days[m[1]] != d.weekday) {
              continue;
            }
            expected.add({
              'weekday': d.weekday,
              'startMinute': int.parse(m[2]!) * 60 + int.parse(m[3]!),
              'endMinute': int.parse(m[4]!) * 60 + int.parse(m[5]!),
              'classroom': m[6]!.trim(),
              'date': date,
            });
          }
        }
        expect(c['schedules'], expected);
        expect(c['period'], {
          'startDate': '2026-08-24',
          'endDate': '2026-12-11',
        });
        count += expected.length;
        for (final m in c['schedules']) {
          expect(m.containsKey('deliveryMode'), false);
        }
      }
      expect(count, 814);
      for (final section in ['04', '05']) {
        final c = courses.singleWhere(
          (c) => c['courseCode'] == 'HSS109a' && c['section'] == section,
        );
        expect(
          (c['schedules'] as List).where((m) => m['date'] == '2026-12-04'),
          isEmpty,
        );
      }
      final hss = courses.singleWhere((c) => c['courseCode'] == 'HSS116');
      expect(
        (hss['schedules'] as List).where((m) => m['date'] == '2026-11-23'),
        isEmpty,
      );
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      'actual195 classes4058 original meetings and full Drive ${mode.name}',
      () {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in model.courses.where((c) => c.hasSchedulableMeetings)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(
            TimetableClass.fromJson(saved.toJson()).toJson(),
            saved.toJson(),
          );
          final source = courses.singleWhere(
            (r) => r['sourceId'] == c.sourceId,
          );
          final schedules = source['schedules'] as List;
          expect(saved.meetings, hasLength(schedules.length));
          for (var i = 0; i < schedules.length; i++) {
            final m = saved.meetings[i];
            final r = schedules[i];
            expect(m.date, r['date']);
            expect(m.weekday, r['weekday']);
            expect(m.originalStartMinute, r['startMinute']);
            expect(m.originalEndMinute, r['endMinute']);
            expect(m.classroom, r['classroom']);
            expect(saved.period!.contains(m.teachingDate!), true);
            expect(saved.modeOn(m, m.teachingDate!), mode);
            expect(
              classOccurrences([saved], [m.teachingDate!]),
              hasLength(mode == LectureMode.video ? 0 : 1),
            );
            count++;
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(count, 4058);
        expect(values, hasLength(195));
        final json =
            jsonDecode(
                  jsonEncode(
                    TimetableSyncDocument.records(
                      courses: values,
                      schemaVersion: 2,
                    ).toJson(),
                  ),
                )
                as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(195));
        for (final c in restored.materializeClasses()) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      },
    );
  }
}
