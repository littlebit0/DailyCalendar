import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:flutter_test/flutter_test.dart';

const dir =
    'work/university-research/catalog-c/khu-ordinary-reservation-v2-20261008';
const prior =
    'work/university-research/catalog-c/ordinary-weekly-held-audit-20261008';
Map<String, dynamic> read(String path) =>
    jsonDecode(fixtureFile(path).readAsStringSync()) as Map<String, dynamic>;
void main() {
  test(
    'KHU exact ordinary practical and theory native clocks, prior490 deep preservation and66 source corrections, three modes and full Drive',
    () {
      final audit = read('$dir/candidate-audit.json');
      final proofs = {for (final p in audit['proofs']) p['sourceId']: p};
      final correction = read(
        '$dir/current-online-method-source-corrections.json',
      );
      final withdrawn = (correction['withdrawnCourseIds'] as List).toSet();
      expect(withdrawn, hasLength(66));
      var withdrawnDates = 0;
      final raw = <String, dynamic>{};
      final original = <String, dynamic>{};
      final courses = <UniversityCourse>[];
      for (final campus in ['global', 'seoul']) {
        final before = read(
          '$prior/khu-$campus-2026-2.ordinary-reservation-research-v1-20261008.json',
        );
        final after = read(
          '$dir/khu-$campus-2026-2.ordinary-reservation-research-v2-20261008.json',
        );
        for (final c in before['courses']) {
          if (c['metadata']?.containsKey('researchOnly') == true) {
            c['metadata']['researchOnly'] = false;
          }
          original[c['sourceId']] = c;
        }
        for (final c in after['courses']) {
          if (c['metadata']?.containsKey('researchOnly') == true) {
            c['metadata']['researchOnly'] = false;
          }
          raw[c['sourceId']] = c;
        }
        courses.addAll(UniversityDataset.fromJson(after).courses);
      }
      // Independently derive correction identities from all actual source plans and baseline native keys.
      final planIndex = <String, List<Map<String, dynamic>>>{};
      for (final entity in fixtureDirectory(
        'work/university-research/catalog-u/public-plans-v2',
      ).listSync().whereType<File>()) {
        if (!entity.path.endsWith('.json')) {
          continue;
        }
        final plan = read(entity.path);
        planIndex
            .putIfAbsent('${plan['campus']}/${plan['lectureCode']}', () => [])
            .add(plan);
      }
      final independentlyWithdrawn = <String>{};
      for (final before in original.values) {
        if ((before['schedules'] as List).isEmpty ||
            before['sourceId'] == 'khu/2026/2/seoul/ECON100100') {
          continue;
        }
        final variants = before['sourceEducationalVariants'] as List;
        final campus = before['campus'] == 'seoul' ? '서울' : '국제';
        final teachers = variants.map((v) => v['teach_na']).toSet();
        for (final plan
            in planIndex['$campus/${variants[0]['lecture_cd']}'] ??
                <Map<String, dynamic>>[]) {
          if (!teachers.contains(plan['queriedProfessorName'])) {
            continue;
          }
          for (final section in plan['educationalSections']) {
            if (section['section'] != '수업유형 및 방법') {
              continue;
            }
            List<dynamic>? header;
            for (final row in section['rows']) {
              if ((row as List).contains('온라인강의')) {
                header = row;
              }
              if (row.isNotEmpty && row[0] == '수업방법' && header != null) {
                final index = header.indexOf('온라인강의');
                if (row.length > index &&
                    !{
                      '',
                      '0',
                      '0%',
                      '0.0%',
                    }.contains(row[index].toString().trim())) {
                  independentlyWithdrawn.add(before['sourceId'] as String);
                }
              }
            }
          }
        }
      }
      expect(withdrawn, independentlyWithdrawn);
      expect(courses, hasLength(4666));
      expect(proofs, hasLength(1358));
      var preservedClasses = 0;
      var preservedMeetings = 0;
      final slot = RegExp(
        r'([월화수목금토일])\s*(\d{2}):(\d{2})-(\d{2}):(\d{2})\s*\(((?:[^()]|\([^()]*\))*)\)',
      );
      final exception = RegExp(
        r'시험|고사|추석|공휴일|연휴|휴강|휴일|midterm|final\s*(exam|test)|no\s*class|holiday|vacation',
        caseSensitive: false,
      );
      for (final c in courses) {
        final before = original[c.sourceId] as Map;
        final after = raw[c.sourceId] as Map;
        if (withdrawn.contains(c.sourceId)) {
          expect(c.meetings, isEmpty);
          withdrawnDates += (before['schedules'] as List).length;
          for (final key in before.keys.where(
            (key) => !{
              'schedules',
              'scheduleStatus',
              'departmentRemarks',
            }.contains(key),
          )) {
            expect(after[key], before[key], reason: '${c.sourceId}/$key');
          }
          final nativeRows =
              (read('$dir/prior556-selected-online-method-audit.json')['rows']
                      as List)
                  .where((r) => r['sourceId'] == c.sourceId)
                  .toList();
          expect(nativeRows, isNotEmpty);
          for (final row in nativeRows) {
            final plan = read(row['sourcePlan']);
            final currentSections = (plan['educationalSections'] as List).where(
              (sec) => sec['section'] == '수업유형 및 방법',
            );
            var currentSelectedOnline = false;
            for (final section in currentSections) {
              List<dynamic>? header;
              for (final fields in section['rows']) {
                if ((fields as List).contains('온라인강의')) {
                  header = fields;
                }
                if (fields.isNotEmpty &&
                    fields[0] == '수업방법' &&
                    header != null) {
                  expect(header.indexOf('온라인강의'), 6);
                  expect(header.indexOf('e-campus활용'), 7);
                  if (fields[6].toString().trim().isNotEmpty) {
                    currentSelectedOnline = true;
                  }
                }
              }
            }
            expect(currentSelectedOnline, true, reason: c.sourceId);
          }
          continue;
        }
        if (!proofs.containsKey(c.sourceId)) {
          expect(after, before, reason: c.sourceId);
          if ((before['schedules'] as List).isNotEmpty) {
            preservedClasses++;
            preservedMeetings += (before['schedules'] as List).length;
          }
          continue;
        }
        for (final k in before.keys.where(
          (k) =>
              !{'schedules', 'scheduleStatus', 'departmentRemarks'}.contains(k),
        )) {
          expect(after[k], before[k], reason: '${c.sourceId}/$k');
        }
        expect(c.campus, anyOf('seoul', 'global'));
        expect(
          after['reservationEvidence']['individualDatedAttendanceConfirmed'],
          false,
        );
        final blocks = <List<dynamic>>[];
        final text = before['sourceSchedule'] as String;
        for (final m in slot.allMatches(text)) {
          blocks.add([
            '월화수목금토일'.indexOf(m[1]!) + 1,
            int.parse(m[2]!) * 60 + int.parse(m[3]!),
            int.parse(m[4]!) * 60 + int.parse(m[5]!),
            m[6]!.trim(),
          ]);
        }
        expect(blocks, isNotEmpty);
        expect(
          text.replaceAll(slot, '').replaceAll(RegExp(r'[\s,;/]'), ''),
          '',
        );
        final exclusions = <List<DateTime>>[
          [DateTime(2026, 10, 20), DateTime(2026, 10, 26)],
          [DateTime(2026, 12, 15), DateTime(2026, 12, 21)],
        ];
        for (final planProof in proofs[c.sourceId]['planProofs']) {
          final path = planProof['file'] as String;
          expect(
            sha256.convert(fixtureFile(path).readAsBytesSync()).toString(),
            planProof['sha256'],
          );
          final plan = read(path);
          expect(plan['header'], ['2026학년도 2학기 강의계획서']);
          for (final section in plan['educationalSections']) {
            if (section['section'] != '주별강의내용') {
              continue;
            }
            for (final row in section['rows']) {
              if (row.length < 3 ||
                  !RegExp(r'^\d+주$').hasMatch(row[0]) ||
                  !exception.hasMatch(row.sublist(2).join(' '))) {
                continue;
              }
              final m = RegExp(
                r'^(\d+)/(\d+)\s*~\s*(\d+)/(\d+)$',
              ).firstMatch(row[1]);
              expect(m, isNotNull);
              exclusions.add([
                DateTime(2026, int.parse(m![1]!), int.parse(m[2]!)),
                DateTime(2026, int.parse(m[3]!), int.parse(m[4]!)),
              ]);
            }
          }
        }
        final expected = <String>{};
        for (final b in blocks) {
          for (
            var date = DateTime(2026, 9, 1);
            !date.isAfter(DateTime(2026, 12, 21));
            date = date.add(const Duration(days: 1))
          ) {
            final day = date.toIso8601String().substring(0, 10);
            if (date.weekday != b[0] ||
                {
                  '2026-09-24',
                  '2026-09-25',
                  '2026-09-26',
                  '2026-10-03',
                  '2026-10-05',
                  '2026-10-09',
                }.contains(day) ||
                exclusions.any(
                  (r) => !date.isBefore(r[0]) && !date.isAfter(r[1]),
                )) {
              continue;
            }
            expected.add('$day/${b[0]}/${b[1]}/${b[2]}/${b[3]}');
          }
        }
        final actual = c.meetings
            .map(
              (m) =>
                  '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            )
            .toSet();
        expect(actual, expected, reason: c.sourceId);
      }
      expect(withdrawnDates, 1448);
      expect(preservedClasses, 490);
      expect(preservedMeetings, 10717);
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(1848));
      expect(courses.fold<int>(0, (n, c) => n + c.meetings.length), 34882);
      final economic = courses.singleWhere(
        (c) => c.code == 'ECON1001' && c.section == '00',
      );
      expect(
        economic.meetings
            .map((m) => [m.date, m.originalStartMinute, m.originalEndMinute])
            .toList(),
        [
          ['2026-10-20', 1080, 1140],
          ['2026-12-15', 1080, 1140],
        ],
      );
      expect(
        courses.singleWhere((c) => c.code == 'MEDIC2026').meetings,
        isEmpty,
      );
      expect(courses.where((c) => c.code.startsWith('IE318')), isEmpty);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.professor, c.professor);
          expect(saved.note, c.remarks);
          for (var index = 0; index < saved.meetings.length; index++) {
            final m = saved.meetings[index];
            final published =
                raw[c.sourceId]['schedules'][index]['deliveryMode'];
            final expectedMode = published == 'inPerson'
                ? LectureMode.inPerson
                : published == 'liveOnline'
                ? LectureMode.liveOnline
                : mode;
            expect(saved.modeOn(m, m.teachingDate!), expectedMode);
            expect(saved.period!.contains(m.teachingDate!), true);
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
        expect(restored, hasLength(1848));
        for (final c in restored) {
          expect(c.defaultMode, mode);
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
        }
      }
    },
  );
}
