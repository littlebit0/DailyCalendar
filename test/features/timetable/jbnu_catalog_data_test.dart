import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory = 'work/university-research/catalog-c/jbnu-current-20261008';
Map<String, dynamic> read(String file) {
  final original =
      jsonDecode(fixtureFile('$directory/$file').readAsStringSync())
          as Map<String, dynamic>;
  if (file !=
      'jbnu-unknown-medical-document-2026-2.published-partial-20261008.json') {
    return original;
  }
  final active =
      jsonDecode(
            fixtureFile(
              'assets/timetable/jbnu-unknown-2026-2.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  final documentIds = {
    for (final row in original['courses'] as List) row['sourceId'],
  };
  // This test checks the original clinical document. The newly added native
  // undergraduate catalogue has separate whole-source integrity checks.
  return {
    ...active,
    'courses': [
      for (final row in active['courses'] as List)
        if (documentIds.contains(row['sourceId'])) row,
    ],
  };
}

void main() {
  final audit = read('medical-candidate-audit.json');
  final raw = read(audit['candidate']['file']);
  final courses = UniversityDataset.fromJson(raw).courses;
  final records = {for (final c in raw['courses']) c['sourceId']: c};
  test('public expansion preserves every original medical document row', () {
    final original =
        jsonDecode(
              fixtureFile(
                '$directory/${audit['candidate']['file']}',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(raw['courses'], original['courses']);
  });
  test(
    'Current public native 3571 metadata, exact campus prefixes and zero fabricated clocks',
    () {
      final a = read('whole-metadata-audit.json');
      final ids = <String>{};
      var count = 0;
      final names = {
        '전주': 'jeonju',
        '익산': 'iksan',
        '남원': 'namwon',
        '고창': 'gochang',
        '새만금': 'saemangeum',
      };
      for (final file in a['candidates']) {
        expect(
          sha256
              .convert(
                fixtureFile('$directory/${file['file']}').readAsBytesSync(),
              )
              .toString(),
          file['sha256'],
        );
        final r = read(file['file']);
        final model = UniversityDataset.fromJson(r);
        expect(model.courses, hasLength(file['classes']));
        for (final c in r['courses']) {
          count++;
          expect(ids.add(c['sourceId']), true);
          final e = c['publicEducationRow'];
          expect(c['courseCode'], e['STDTR_NO']);
          expect(c['section'], e['DVCLS_NO'].toString());
          expect(c['classification'], e['CMCRS_DIVCDNM']);
          expect(c['credits'], e['ESTBL_PNT']);
          expect(c['sourceClassroom'], e['DONG_RMNM_CN'] ?? '');
          expect(c['sourceSchedule'], e['DOW_HR_CN']);
          expect(c['schedules'], isEmpty);
          final prefixes = RegExp(
            r'(전주|익산|고창|남원|새만금):',
          ).allMatches(e['DONG_RMNM_CN'] ?? '').map((m) => m[1]).toSet();
          expect(
            c['campus'],
            prefixes.length == 1 ? names[prefixes.single] : 'unknown',
          );
          expect(c['referenceKind'], '공개 과목번호');
        }
      }
      expect(count, 3571);
      expect(ids, hasLength(3571));
      expect(a['priorAbsentNow'], hasLength(5));
      final closure = read('closure-educational-reconciliation.json');
      expect(closure['sourceRows'], hasLength(248));
      expect(closure['currentTitleSectionValidationMatches'], isEmpty);
      expect(closure['medicalSameTitleNoticeRows'], isEmpty);
      expect(closure['officialCodeJoinPerformed'], false);
    },
  );
  test(
    'Medical direct document headers, date/weekday, room, assessment and holds independently checked',
    () {
      expect(
        sha256
            .convert(
              fixtureFile(
                '$directory/${audit['candidate']['file']}',
              ).readAsBytesSync(),
            )
            .toString(),
        audit['candidate']['sha256'],
      );
      expect(courses, hasLength(33));
      expect(courses.where((c) => c.meetings.isNotEmpty), hasLength(18));
      final proof = read('medical-document-educational-receipt.json');
      var count = 0;
      var cells = 0;
      for (final c in courses) {
        final r = records[c.sourceId];
        final grade = r['sourceGrade'];
        expect(c.code, '');
        expect(c.section, '');
        expect(r['canonicalSubjectCodePublished'], false);
        expect(c.remarks, contains('공식 과목번호가 아닙니다'));
        final sh = (proof['sourceSheets'] as List).singleWhere(
          (s) => s['grade'] == grade,
        );
        final subject = (sh['subjects'] as List).singleWhere(
          (e) => e['row'] == r['publishedDocumentMetadata']['row'],
        );
        expect(c.title, subject['courseName']);
        expect(c.credits, subject['credits']);
        expect(c.professor, subject['professor']);
        expect(subject['nativeClassificationAggregate'], '전필합계');
        expect(c.sourceClassification, '전필');
        final clocks = <int, List<int>>{};
        for (final h in sh['sourceClockHeader']) {
          final m = RegExp(
            r'(\d+)교시\s*(\d{1,2}):(\d{2})~(\d{1,2}):(\d{2})',
          ).firstMatch(h['sourceText'])!;
          clocks[int.parse(m[1]!)] = [
            int.parse(m[2]!) * 60 + int.parse(m[3]!),
            int.parse(m[4]!) * 60 + int.parse(m[5]!),
          ];
        }
        final expected = <String>{};
        for (final cell in r['publicDatedCells']) {
          cells++;
          final day = DateTime.parse(cell['date']);
          expect(day.weekday, cell['weekday']);
          expect('월화수목금토일'[day.weekday - 1], cell['printedWeekday']);
          final cl = clocks[cell['nativePeriod']]!;
          expect(cell['originalStartMinute'], cl[0]);
          expect(cell['originalEndMinute'], cl[1]);
          final held = (r['holds'] as List).isNotEmpty;
          final color = cell['fillRgb'];
          final assessment =
              jsonEncode(color) == jsonEncode([255, 0, 0]) ||
              jsonEncode(color) == jsonEncode([255, 128, 128]) ||
              RegExp('시험|평가|퀴즈').hasMatch(cell['sourceText']);
          if (!held && !assessment) {
            expected.add(
              '${cell['date']}/${day.weekday}/${cl[0]}/${cl[1]}/${proof['classroomAssignment'][grade.toString()]}',
            );
          }
        }
        final actual = <String>{};
        for (final m in c.meetings) {
          count++;
          expect(m.weekday, m.teachingDate!.weekday);
          expect(m.isValid, true);
          expect(
            actual.add(
              '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            ),
            true,
          );
          expect(c.period!.contains(m.teachingDate!), true);
        }
        expect(actual, expected, reason: c.title);
        if (c.title.contains('문제바탕학습')) {
          expect(c.meetings, isEmpty);
          expect(r['holds'].join(' '), contains('17:00'));
        }
        if (grade == 3 && c.title.contains('실습')) {
          expect(c.meetings, isEmpty);
          expect(c.sourceClassroom, '');
        }
      }
      expect(count, 1098);
      expect(cells, 1929);
      expect(audit['assessmentOrAmbiguousCellsExcluded'], 147);
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test(
      'Actual model 18 document plans, 1098 original clocks full Drive ${mode.name}',
      () {
        final values = <String, TimetableSyncValue>{};
        var count = 0;
        for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
          final saved = c.toTimetable(id: c.sourceId, mode: mode);
          expect(saved.isValid, true);
          expect(saved.note, c.remarks);
          for (final m in saved.meetings) {
            count++;
            expect(saved.modeOn(m, m.teachingDate!), mode);
            expect(saved.period!.contains(m.teachingDate!), true);
          }
          final key = timetableCourseSyncKey(saved);
          expect(values.containsKey(key), false);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 8),
            'research',
          );
        }
        expect(values, hasLength(18));
        expect(count, 1098);
        final doc = TimetableSyncDocument.records(
          courses: values,
          schemaVersion: 2,
        );
        final json =
            jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
        final restored = TimetableSyncDocument.fromJson(json);
        expect(restored.materializeClasses(), hasLength(18));
        for (final c in restored.materializeClasses()) {
          expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
          expect(c.isValid, true);
        }
      },
    );
  }
}
