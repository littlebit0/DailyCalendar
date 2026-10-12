import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-c/skku-ordinary-reservation-v6-20261009';
Map<String, dynamic> read(String path) {
  final data =
      jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
  for (final c in data['courses'] as List? ?? []) {
    if (c['metadata']?.containsKey('researchOnly') == true) {
      c['metadata']['researchOnly'] = false;
    }
  }
  return data;
}

void main() {
  final audit = read('$folder/candidate-audit.json');
  final raw = <Map<String, dynamic>>[];
  final prior = <String, dynamic>{};
  final courses = <UniversityCourse>[];
  for (final campus in audit['campuses']) {
    final dataset = read('$folder/${campus['candidateFile']}');
    raw.addAll((dataset['courses'] as List).cast<Map<String, dynamic>>());
    courses.addAll(UniversityDataset.fromJson(dataset).courses);
    for (final row in read('$folder/${campus['baselineFile']}')['courses']) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
      prior[row['sourceId']] = row;
    }
  }
  final proofs = {for (final p in audit['proofs']) p['sourceId']: p};
  test(
    'three-campus whole2782 native union; all prior1689 exact and 0 newly unresolved source contradictions',
    () {
      expect(courses, hasLength(2782));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2782));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1691));
      expect(courses.expand((c) => c.meetings), hasLength(47158));
      final native =
          (read('$folder/baseline-public-native-whole.json')['records'] as List)
              .where((r) => r['JUKYONGHAKWI_GB'] != '05');
      expect(
        native.map((r) => r['HAKSU_NO_BUNBAN']).toSet(),
        raw.map((r) => '${r['courseCode']}-${r['section']}').toSet(),
      );
      expect(
        prior.values.where((r) => (r['schedules'] as List).isNotEmpty),
        hasLength(1689),
      );
      for (final campus in audit['campuses']) {
        expect(
          sha256
              .convert(
                fixtureFile(
                  '$folder/${campus['candidateFile']}',
                ).readAsBytesSync(),
              )
              .toString(),
          campus['candidateSHA256'],
        );
      }
      for (final row in raw) {
        final old = prior[row['sourceId']] as Map;
        if (!proofs.containsKey(row['sourceId'])) {
          expect(row, old);
        } else {
          final restored = Map<String, dynamic>.from(row);
          for (final key in [
            'scheduleStatus',
            'schedules',
            'unresolvedReasons',
            'researchOnly',
            'period',
            'reservationEvidenceV6',
            'scheduleEvidenceKind',
            'actualAttendanceConfirmed',
            'commonClosureDatesApplied',
            'departmentRemarks',
          ]) {
            if (old.containsKey(key)) {
              restored[key] = old[key];
            } else {
              restored.remove(key);
            }
          }
          expect(restored, old);
        }
      }
      expect(audit['held'], hasLength(0));
      for (final held in audit['held']) {
        final row = raw.singleWhere(
          (r) => '${r['courseCode']}-${r['section']}' == held['offeringCode'],
        );
        expect(row['schedules'], isEmpty);
        expect(row, prior[row['sourceId']]);
      }
    },
  );
  test(
    '2 frozen pre119 visual attached source native clocks rooms and own-term operation exceptions',
    () {
      expect(proofs, hasLength(2));
      final current = read(
        '$folder/current-incomplete-educational-operation-recheck.json',
      );
      expect(current['stopped'], false);
      expect(current['records'], hasLength(2));
      final nativePattern = RegExp(
        r'([월화수목금토일])(\d{2}):(\d{2})-(\d{2}):(\d{2})【([^】]+)】',
      );
      final detailPattern = RegExp(
        r'([월화수목금토일])(?:\[[^\]]+\])?(\d{2}):(\d{2})-(\d{2}):(\d{2})',
      );
      for (final course in courses.where(
        (c) => proofs.containsKey(c.sourceId),
      )) {
        final p = proofs[course.sourceId];
        final row = p['nativeSourceRow'];
        final record = p['currentPublicEducationalEvidence'];
        final detail = record['detail'].single;
        expect(record['currentDetailIdentityConfirmed'], true);
        expect(detail['HAKSU_NO'], course.code);
        expect(detail['BUNBAN'], course.section);
        expect(detail['PER_NAME'], course.professor);
        expect(detail['GAESUL_YEAR'], '2026');
        expect(detail['GAESUL_TERM'], '20');
        expect(row['SUUP_TYPE_CD'], anyOf('31', '33'));
        expect(row['HAKBU_JIBJUNG_GB'], 'N');
        expect(p['currentIdentityTeacherClockRoomChangedFields'], isEmpty);
        expect(p['attachmentsRecheckedRatherThanAssumedFromCache'], true);
        expect(record['attachments'], isNotEmpty);
        for (final attachment in record['attachments']) {
          // Source contact filtering losses are resolved by the independently read educational tables.
          expect(
            p['fullOperatingTableIndependentReview']['actualFullOperatingTableReviewed'],
            true,
          );
          expect(attachment['contextTruncated'] ?? false, false);
          expect(attachment['protectionPresent'] ?? false, false);
          expect(attachment['educationalOperatingContexts'], isNotEmpty);
        }
        final source = nativePattern
            .allMatches(row['GYOSI_NAME'] as String)
            .toList();
        final direct = detailPattern
            .allMatches(detail['SUUP_YOIL_GYOSI'] as String)
            .toList();
        expect(source, isNotEmpty);
        for (final meeting in course.meetings) {
          expect(
            source.any(
              (s) =>
                  '월화수목금토일'.indexOf(s[1]!) + 1 == meeting.weekday &&
                  int.parse(s[2]!) * 60 + int.parse(s[3]!) ==
                      meeting.originalStartMinute &&
                  int.parse(s[4]!) * 60 + int.parse(s[5]!) ==
                      meeting.originalEndMinute &&
                  s[6] == meeting.classroom,
            ),
            true,
          );
          expect(
            direct.any(
              (s) =>
                  '월화수목금토일'.indexOf(s[1]!) + 1 == meeting.weekday &&
                  int.parse(s[2]!) * 60 + int.parse(s[3]!) ==
                      meeting.originalStartMinute &&
                  int.parse(s[4]!) * 60 + int.parse(s[5]!) ==
                      meeting.originalEndMinute,
            ),
            true,
          );
          expect(detail['SUUP_GANGUISIL'], contains(meeting.classroom));
          final date = DateTime.parse(meeting.date!);
          expect(date.weekday, meeting.weekday);
          expect(date.isBefore(DateTime(2026, 8, 31)), false);
          expect(date.isAfter(DateTime(2026, 12, 18)), false);
          if (!(p['explicitOwnClosureOperatingDates'] as List).contains(
            meeting.date,
          )) {
            expect(
              audit['excludedReservationDates'],
              isNot(contains(meeting.date)),
            );
          }
          expect(p['excludedExactDates'], isNot(contains(meeting.date)));
          final week = date.difference(DateTime(2026, 8, 31)).inDays ~/ 7 + 1;
          if (p['includedExactDatesOnly'] != null) {
            expect(p['includedExactDatesOnly'], contains(meeting.date));
          }
          if (p['includedWeeksOnly'] != null) {
            expect(p['includedWeeksOnly'], contains(week));
          }
          if (p['includedWeekdayWeeks'] != null) {
            expect(
              p['includedWeekdayWeeks']['월화수목금토일'[date.weekday - 1]],
              contains(week),
            );
          }
          expect(p['fullOperatingTableIndependentReview'], isNotEmpty);
          expect(
            p['excludedWeeks'],
            isNot(
              contains(date.difference(DateTime(2026, 8, 31)).inDays ~/ 7 + 1),
            ),
          );
        }
      }
      final reviewed = read('$folder/attached-semantic-review-checkpoint.json');
      expect(reviewed['remainingCount'], 0);
      expect(reviewed['records'], hasLength(2));
      expect(
        (reviewed['records'] as List).every(
          (r) =>
              r['basis'] is String &&
              r['actualFullOperatingTableReviewed'] is bool,
        ),
        true,
      );
      final nativeAudit = read(
        '$folder/current-native-row-equivalence-audit.json',
      );
      expect(nativeAudit['currentCount'], 2);
      expect(nativeAudit['changedCount'], 0);
      for (final row in nativeAudit['records']) {
        expect(row['changedFields'], isEmpty);
        expect(row['sourceRowExact'], true);
      }
      for (final code in ['GEDT017-66', 'GEDT017-75']) {
        final course = courses.singleWhere(
          (c) => c.sourceId == 'skku-2026-2-$code',
        );
        final p = proofs[course.sourceId];
        expect(p['excludedWeeks'], [1, 4, 6]);
        expect(course.meetings, hasLength(26));
        expect(
          course.meetings.map((m) => m.date),
          isNot(contains('2026-09-04')),
        );
        expect(
          course.meetings.map((m) => m.date),
          containsAll(['2026-10-23', '2026-10-30', '2026-12-04', '2026-12-18']),
        );
        expect(course.meetings.map((m) => m.classroom).toSet(), {'36107'});
        final visual = p['independentOperatingTableVisualReview'];
        expect(visual['visuallyCheckedOperatingTablePage'], 5);
        expect(visual['publishedFridayDates'], hasLength(16));
        expect(visual['teamEvaluationDoesNotProveNoClassOrOutside'], true);
        expect(
          visual['cropReceipt']['uncertainPrivateObservationsInsideSelectedColumns'],
          0,
        );
        expect(
          visual['cropReceipt']['nonEducationalRightColumnExcluded'],
          true,
        );
        expect(
          visual['samePublicPublishedEducationAttachmentSHA256'],
          hasLength(2),
        );
      }
      final crop = fixtureFile(
        '$folder/GEDT017-66-education-operating-table-page5.png',
      );
      expect(
        sha256.convert(crop.readAsBytesSync()).toString(),
        proofs['skku-2026-2-GEDT017-66']['independentOperatingTableVisualReview']['cropReceipt']['sha256'],
      );
    },
  );
  test(
    'three actual selected modes and entire1691-record Drive schema2 deep equality',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final course in courses.where((c) => c.hasSchedulableMeetings)) {
          final timetable = course.toTimetable(id: course.sourceId, mode: mode);
          expect(timetable.isValid, true);
          expect(timetable.defaultMode, mode);
          final key = timetableCourseSyncKey(timetable);
          values[key] = TimetableSyncValue(
            {...timetable.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(values, hasLength(1691));
        final original = TimetableSyncDocument.records(courses: values);
        final decoded = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
        );
        expect(decoded.toJson(), original.toJson());
        for (final entry in values.entries) {
          expect(decoded.courses[entry.key]!.value, entry.value.value);
        }
      }
    },
  );
}
