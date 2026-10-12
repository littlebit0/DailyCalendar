import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-c/skku-ordinary-reservation-v2-20261008';
Map<String, dynamic> read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final audit = read('$folder/candidate-audit.json');
  final raw = <Map<String, dynamic>>[];
  final prior = <String, dynamic>{};
  final courses = <UniversityCourse>[];
  for (final campus in audit['campuses']) {
    final dataset = read("$folder/${campus['candidateFile']}");
    raw.addAll((dataset['courses'] as List).cast<Map<String, dynamic>>());
    courses.addAll(UniversityDataset.fromJson(dataset).courses);
    for (final row in read('$folder/${campus['baselineFile']}')['courses']) {
      prior[row['sourceId']] = row;
    }
  }
  final proofs = {for (final p in audit['proofs']) p['sourceId']: p};
  test(
    'Historical v2 three-campus whole2782 native union; all prior1378 exact and six actual conflicts held',
    () {
      expect(courses, hasLength(2782));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2782));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1403));
      expect(courses.expand((c) => c.meetings), hasLength(40476));
      final native =
          (read('$folder/baseline-public-native-whole.json')['records'] as List)
              .where((r) => r['JUKYONGHAKWI_GB'] != '05');
      expect(
        native.map((r) => r['HAKSU_NO_BUNBAN']).toSet(),
        raw.map((r) => '${r['courseCode']}-${r['section']}').toSet(),
      );
      expect(
        prior.values.where((r) => (r['schedules'] as List).isNotEmpty),
        hasLength(1378),
      );
      for (final campus in audit['campuses']) {
        expect(
          sha256
              .convert(
                File('$folder/${campus['candidateFile']}').readAsBytesSync(),
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
            'reservationEvidenceV2',
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
      expect(audit['held'], hasLength(6));
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
    '25 current attached source native clocks rooms and own-term operation exceptions',
    () {
      expect(proofs, hasLength(25));
      final current = read('$folder/current-attached-public-recheck.json');
      expect(current['stopped'], false);
      expect(current['records'], hasLength(31));
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
        expect(row['SUUP_TYPE_CD'], '31');
        expect(row['HAKBU_JIBJUNG_GB'], 'N');
        expect(p['currentIdentityTeacherClockRoomChangedFields'], isEmpty);
        expect(p['attachmentsRecheckedRatherThanAssumedFromCache'], true);
        expect(record['attachments'], isNotEmpty);
        for (final attachment in record['attachments']) {
          expect(attachment['privacySuppressedLineCount'] ?? 0, 0);
          expect(attachment['contextLimitReached'] ?? false, false);
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
          expect(
            audit['excludedReservationDates'],
            isNot(contains(meeting.date)),
          );
          expect(p['excludedExactDates'], isNot(contains(meeting.date)));
          expect(
            p['excludedWeeks'],
            isNot(
              contains(date.difference(DateTime(2026, 8, 31)).inDays ~/ 7 + 1),
            ),
          );
        }
      }
      expect(proofs['skku-2026-2-DKL3017-02']['excludedExactDates'], [
        '2026-09-23',
        '2026-10-21',
      ]);
      expect(proofs['skku-2026-2-DKL3017-02']['excludedWeeks'], [8, 15, 16]);
      expect(proofs['skku-2026-2-SWF3049-01']['excludedWeeks'], isEmpty);
      expect(
        proofs['skku-2026-2-SOC2016-01']['sourceSemanticBasis'],
        contains('subjectcontent'),
      );
    },
  );
  test(
    'three actual selected modes and entire1403-record Drive schema2 deep equality',
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
        expect(values, hasLength(1403));
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
