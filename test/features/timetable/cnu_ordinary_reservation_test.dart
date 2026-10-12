// Historical frozen CNU packet; latest packaged source checks remain separate.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-c/cnu-ordinary-reservation-v2-20261008';
Map<String, dynamic> read(String path) {
  final data =
      jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
  for (final row in data['courses'] ?? []) {
    if (row['metadata']?.containsKey('researchOnly') == true) {
      row['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  final audit = read('$folder/candidate-audit.json');
  final raw = read(
    '$folder/cnu-unknown-2026-2.ordinary-reservation-research-v2-20261008.json',
  );
  final baseline = read('$folder/baseline-cnu-unknown-v1.json');
  final unknown = UniversityDataset.fromJson(raw);
  final daedeokRaw = read('$folder/baseline-cnu-daedeok-v1.json');
  final daedeok = UniversityDataset.fromJson(daedeokRaw);
  final allCourses = [...unknown.courses, ...daedeok.courses];
  final proofs = {for (final p in audit['proofs']) p['sourceId']: p};
  final native =
      jsonDecode(
            fixtureFile(
              '$folder/current-public-native-educational-catalog.json',
            ).readAsStringSync(),
          )
          as List;
  test(
    'whole 3888 two-campus native union; existing 1125 records and daedeok15 exact',
    () {
      expect(
        sha256
            .convert(
              fixtureFile(
                '$folder/${audit['candidateFile']}',
              ).readAsBytesSync(),
            )
            .toString(),
        audit['candidateSHA256'],
      );
      expect(allCourses, hasLength(3888));
      expect(
        allCourses.where((c) => c.hasSchedulableMeetings),
        hasLength(1428),
      );
      expect(allCourses.expand((c) => c.meetings), hasLength(35680));
      final originals = baseline['courses'] as List;
      final current = raw['courses'] as List;
      expect(
        current.map((c) => c['sourceId']).toSet(),
        originals.map((c) => c['sourceId']).toSet(),
      );
      expect(current.map((c) => c['sourceId']).toSet(), hasLength(3887));
      expect(allCourses.map((c) => c.sourceId).toSet(), hasLength(3888));
      expect(proofs, hasLength(303));
      final nativeIds = native.map((c) => c['COURSE_NO']).toSet();
      final productIds = [
        ...current,
        ...(daedeokRaw['courses'] as List),
      ].map((c) => c['sourceEducation']['courseId']).toSet();
      expect(productIds.difference(nativeIds), isEmpty);
      expect(nativeIds.difference(productIds), isEmpty);
      expect(daedeokRaw, read('$folder/baseline-cnu-daedeok-v1.json'));
      expect(
        sha256
            .convert(
              fixtureFile(
                '$folder/baseline-cnu-daedeok-v1.json',
              ).readAsBytesSync(),
            )
            .toString(),
        audit['daedeokSHA256'],
      );
      expect(daedeok.courses.single.meetings, hasLength(15));
      for (var i = 0; i < current.length; i++) {
        expect(current[i]['sourceId'], originals[i]['sourceId']);
        if (!proofs.containsKey(current[i]['sourceId'])) {
          expect(current[i], originals[i]);
        } else {
          final restored = Map<String, dynamic>.from(current[i] as Map);
          restored.remove('reservationEvidence');
          restored.remove('currentPublicPlanEducation');
          for (final key in [
            'schedules',
            'scheduleStatus',
            'period',
            'departmentRemarks',
          ]) {
            if ((originals[i] as Map).containsKey(key)) {
              restored[key] = originals[i][key];
            } else {
              restored.remove(key);
            }
          }
          expect(restored, originals[i]);
        }
      }
    },
  );
  test(
    'every new meeting matches direct native clock and room; source term and calendar exclusions',
    () {
      final pattern = RegExp(
        r'([월화수목금토일])(\d{2}):(\d{2})~(\d{2}):(\d{2})\(((?:[^()]|\([^()]*\))*)\)',
      );
      for (final course in allCourses.where(
        (c) => proofs.containsKey(c.sourceId),
      )) {
        final proof = proofs[course.sourceId];
        expect(course.campus, 'unknown');
        expect(proof['publicEducationChangedFields'], isEmpty);
        final semantic = proof['semanticDecision'];
        expect(semantic['screenReasons'], isEmpty);
        expect(semantic['foregroundEducationalStatements'], isNotEmpty);
        expect(semantic['actualWeeklySignals'], isEmpty);
        expect(
          sha256
              .convert(fixtureFile(proof['sourcePlanFile']).readAsBytesSync())
              .toString(),
          proof['sourcePlanFileSHA256'],
        );
        final source = read(proof['sourcePlanFile']);
        expect(source['courseId'], proof['courseId']);
        expect(source['header'], isNotEmpty);
        for (final h in source['header']) {
          expect(h['OPEN_SHTM_CD_NM'], '2학기');
        }
        final nativeCourse = native.singleWhere(
          (r) => r['COURSE_NO'] == proof['courseId'],
        );
        expect(nativeCourse['CLOSE_YN'], '0');
        expect(['이론', '실습', '이론/실습'], contains(nativeCourse['LSN_TYPE_CD_NM']));
        final matches = pattern
            .allMatches(nativeCourse['TMTBL_INFO'] as String)
            .toList();
        expect(matches, isNotEmpty);
        for (final m in course.meetings) {
          expect(
            matches.any(
              (s) =>
                  '월화수목금토일'.indexOf(s[1]!) + 1 == m.weekday &&
                  int.parse(s[2]!) * 60 + int.parse(s[3]!) ==
                      m.originalStartMinute &&
                  int.parse(s[4]!) * 60 + int.parse(s[5]!) ==
                      m.originalEndMinute &&
                  s[6]! == m.classroom,
            ),
            true,
          );
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(m.date!.compareTo('2026-09-01'), greaterThanOrEqualTo(0));
          expect(m.date!.compareTo('2026-12-18'), lessThanOrEqualTo(0));
          expect(audit['excludedReservationDates'], isNot(contains(m.date)));
        }
        for (final h in source['header']) {
          if (h['PRE_LRN_CN'] != null &&
              h['PRE_LRN_CN'].toString().isNotEmpty) {
            expect(course.remarks, contains(h['PRE_LRN_CN']));
          }
        }
      }
    },
  );
  test(
    'three actual modes and entire Drive schema2 document preserve all selected values',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final course in allCourses.where(
          (c) => c.hasSchedulableMeetings,
        )) {
          final t = course.toTimetable(id: course.sourceId, mode: mode);
          expect(t.isValid, true);
          expect(t.defaultMode, mode);
          final key = timetableCourseSyncKey(t);
          values[key] = TimetableSyncValue(
            {...t.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(values, hasLength(1428));
        final original = TimetableSyncDocument.records(courses: values);
        final decoded = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
        );
        expect(decoded.toJson(), original.toJson());
        for (final e in values.entries) {
          expect(decoded.courses[e.key]!.value, e.value.value);
        }
      }
    },
  );
}
