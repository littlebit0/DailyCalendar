import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const donga =
    'work/university-research/catalog-c/donga-ordinary-reservation-v3-20261008';
const mju =
    'work/university-research/catalog-f/mju/current-business-reference-v2';
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  test(
    'Dong-A exact native ordinary published windows, prior preservation, three modes and full Drive',
    () {
      final audit = read('$donga/candidate-audit.json');
      final raw = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final campus in ['seunghak', 'unknown']) {
        final part = read(
          '$donga/donga-$campus-2026-2.ordinary-reservation-v3.json',
        );
        markHistoricalPublication(part);
        for (final c in part['courses']) {
          raw[c['sourceId']] = c;
        }
        courses.addAll(UniversityDataset.fromJson(part).courses);
      }
      final original = <String, dynamic>{};
      for (final path in (audit['inputSources'] as Map).keys) {
        expect(
          sha256
              .convert(fixtureFile(path as String).readAsBytesSync())
              .toString(),
          audit['inputSources'][path],
        );
        for (final c in read(path)['courses']) {
          if (c['metadata']?.containsKey('researchOnly') == true) {
            c['metadata']['researchOnly'] = false;
          }
          original[c['sourceId']] = c;
        }
      }
      expect(raw.keys.toSet(), original.keys.toSet());
      expect(courses, hasLength(80));
      final expanded = (audit['expandedObjects'] as List)
          .map((c) => c['sourceId'])
          .toSet();
      expect(expanded, hasLength(14));
      final blocks = <String, List<List<dynamic>>>{
        '01DID328/01': [
          [3, 600, 780, 'S17-0705'],
        ],
        '01EPS305/01': [
          [3, 1080, 1230, 'S04-0208'],
        ],
        '01EPS307/01': [
          [5, 900, 1080, 'S06-0704'],
        ],
        '01EPS403/01': [
          [1, 1080, 1230, 'S06-0908'],
        ],
        '01EPS404/01': [
          [2, 1080, 1230, 'S04-0208'],
        ],
        '01FAS307/01': [
          [1, 600, 780, 'S12-0710'],
        ],
        '01FAS307/02': [
          [1, 840, 1020, 'S12-0710'],
        ],
        '01FAS325/01': [
          [2, 540, 720, 'S11-0119'],
        ],
        '01HCC417/01': [
          [1, 840, 1020, 'S17-0303'],
        ],
        '01HCC418/01': [
          [4, 540, 720, 'S12-0615'],
        ],
        '01HEM404/01': [
          [5, 1080, 1230, 'S06-0308'],
        ],
        '01HMC406/01': [
          [1, 1080, 1155, 'S09-0427'],
          [2, 1080, 1155, 'S09-0402'],
        ],
        '01LAN329/03': [
          [1, 540, 720, 'S12-0607'],
        ],
        '01PED232/03': [
          [4, 810, 990, 'S07-0413'],
        ],
      };
      final exclusions = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
        for (var day = 20; day <= 26; day++) '2026-10-$day',
      };
      final makeups = {
        '2026-09-24': '2026-12-10',
        '2026-09-25': '2026-12-11',
        '2026-10-05': '2026-12-08',
        '2026-10-09': '2026-12-09',
      };
      var newCount = 0;
      for (final c in courses) {
        final record = raw[c.sourceId] as Map;
        final old = original[c.sourceId] as Map;
        if (!expanded.contains(c.sourceId)) {
          expect(record, old);
          continue;
        }
        for (final key in old.keys.where(
          (k) => !{
            'schedules',
            'scheduleStatus',
            'nativePeriodBlocks',
            'remarks',
            'departmentRemarks',
          }.contains(k),
        )) {
          expect(record[key], old[key], reason: '${c.sourceId}/$key');
        }
        expect(c.campus, 'seunghak');
        expect(c.remarks, contains('휴식 포함 가능'));
        expect(record['reservationProof']['actualAttendanceConfirmed'], false);
        expect(record['reservationProof']['modeOverrideApplied'], false);
        final native = blocks['${c.code}/${c.section}']!;
        final expected = <String>{};
        for (
          var date = DateTime(2026, 9, 1);
          !date.isAfter(DateTime(2026, 12, 7));
          date = date.add(const Duration(days: 1))
        ) {
          final day = date.toIso8601String().substring(0, 10);
          if (exclusions.contains(day)) {
            continue;
          }
          for (final b in native) {
            if (date.weekday == b[0]) {
              expected.add('$day/${date.weekday}/${b[1]}/${b[2]}/${b[3]}');
            }
          }
        }
        for (final entry in makeups.entries) {
          for (final b in native) {
            if (DateTime.parse(entry.key).weekday == b[0]) {
              expected.add(
                '${entry.value}/${DateTime.parse(entry.value).weekday}/${b[1]}/${b[2]}/${b[3]}',
              );
            }
          }
        }
        final actual = <String>{};
        for (final meeting in c.meetings) {
          newCount++;
          expect(meeting.weekday, meeting.teachingDate!.weekday);
          expect(
            actual.add(
              '${meeting.date}/${meeting.weekday}/${meeting.originalStartMinute}/${meeting.originalEndMinute}/${meeting.classroom}',
            ),
            true,
          );
        }
        expect(actual, expected, reason: '${c.code}/${c.section}');
      }
      expect(newCount, 195);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(25));
      expect(courses.fold<int>(0, (n, c) => n + c.meetings.length), 481);
      for (final code in [
        '01B40007',
        '01B40010',
        '01B40011',
        '01B40029',
        '01HCC309',
        '01EPS304',
      ]) {
        expect(courses.singleWhere((c) => c.code == code).meetings, isEmpty);
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.note, c.remarks);
          expect(saved.professor, c.professor);
          for (final meeting in saved.meetings) {
            expect(saved.modeOn(meeting, meeting.teachingDate!), mode);
            expect(saved.period!.contains(meeting.teachingDate!), true);
          }
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        final document = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(
          json,
        ).materializeClasses();
        expect(restored, hasLength(25));
        for (final c in restored) {
          expect(c.defaultMode, mode);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
  test(
    'MJU current printed native references, exact aliases, unchanged prior100 and no invented appointments',
    () {
      Map<String, dynamic> read(String path) {
        const frozenRoot =
            'work/university-research/catalog-f/mju/natural-reference-v3-fixture-derivative-20261009';
        final actual = path == 'assets/timetable/mju-unknown-2026-2.json'
            ? '$frozenRoot/baseline-unknown.json'
            : path == 'assets/timetable/mju-natural-2026-2.json'
            ? '$frozenRoot/baseline-natural.json'
            : path == 'assets/timetable/mju-humanities-2026-2.json'
            ? '$frozenRoot/baseline-humanities.json'
            : path;
        return jsonDecode(fixtureFile(actual).readAsStringSync())
            as Map<String, dynamic>;
      }

      final audit = read('$mju/candidate-audit.json');
      final raw = read('assets/timetable/mju-unknown-2026-2.json');
      final education = read('$mju/business-current-printed-education.json');
      final native = {
        for (final row in education['educationRows'])
          row['nativeLectureNumber']: row,
      };
      final model = UniversityDataset.fromJson(raw);
      expect(native, hasLength(44));
      expect(model.courses, hasLength(41));
      final aliases =
          jsonDecode(
                fixtureFile(
                  '$mju/cross-source-native-aliases.json',
                ).readAsStringSync(),
              )
              as List;
      expect(
        aliases
            .map((a) => a['currentPrintedRow']['nativeLectureNumber'])
            .toSet(),
        {'5908', '5885', '5914'},
      );
      expect(model.courses.where((c) => c.meetings.isNotEmpty), isEmpty);
      for (var i = 0; i < model.courses.length; i++) {
        final c = model.courses[i];
        final row = raw['courses'][i];
        final source = native[row['nativeLectureNumber']];
        expect(c.code, isEmpty);
        expect(c.section, isEmpty);
        expect(c.credits, isNull);
        expect(c.campus, 'unknown');
        expect(c.title, source['courseName']);
        expect(c.professor, source['professor']);
        expect(c.sourceClassification, '전공');
        expect(c.remarks, contains(source['nativeKoreanCourseCode']));
        expect(
          row['sourceEducation']['nativeKoreanCourseCode'],
          source['nativeKoreanCourseCode'],
        );
        expect(c.remarks, contains(row['nativeLectureNumber']));
      }
      var originalCount = 0;
      for (final entry in (audit['original100CandidatesSHA'] as Map).entries) {
        final path = 'work/university-research/catalog-f/mju/${entry.key}';
        expect(
          sha256.convert(fixtureFile(path).readAsBytesSync()).toString(),
          entry.value,
        );
        final frozen = read(path);
        final campus = entry.key.contains('humanities')
            ? 'humanities'
            : 'natural';
        final packaged = read('assets/timetable/mju-$campus-2026-2.json');
        for (final course in frozen['courses']) {
          if (course['metadata']?.containsKey('researchOnly') == true) {
            course['metadata']['researchOnly'] = false;
          }
        }
        expect(packaged['courses'], frozen['courses']);
        originalCount += UniversityDataset.fromJson(packaged).courses.length;
      }
      expect(originalCount, 100);
      expect(audit['unionNativeReferenceObjects'], 141);
    },
  );
}
