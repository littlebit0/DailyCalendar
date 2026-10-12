import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const directory =
    'work/university-research/catalog-c/donga-cell-extension-20261008';
const campusDirectory =
    'work/university-research/catalog-c/donga-campus-v2-20261008';
const sourceDirectory =
    'work/university-research/catalog-c/donga-current-20261008';
Map<String, dynamic> frozenRead(String name) =>
    jsonDecode(
          File(
            File('$directory/$name').existsSync()
                ? '$directory/$name'
                : File('$campusDirectory/$name').existsSync()
                ? '$campusDirectory/$name'
                : '$sourceDirectory/$name',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
Map<String, dynamic> read(String name) {
  if (name.startsWith('donga-') &&
      name.contains('published-partial') &&
      !name.contains('institution')) {
    final campus = name.contains('seunghak') ? 'seunghak' : 'unknown';
    final product =
        jsonDecode(
              File(
                'assets/timetable/donga-$campus-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final expectedIds = {
      for (final c in frozenRead(name)['courses'] as List) c['sourceId'],
    };
    return {
      ...product,
      'courses': (product['courses'] as List)
          .where((c) => expectedIds.contains(c['sourceId']))
          .toList(),
    };
  }
  return frozenRead(name);
}

void main() {
  final audit = read('candidate-audit.json');
  final raw = <String, dynamic>{
    'courses': [
      for (final part in audit['candidates']) ...read(part['file'])['courses'],
    ],
  };
  final courses = [
    for (final part in audit['candidates'])
      ...UniversityDataset.fromJson(read(part['file'])).courses,
  ];
  final records = {for (final row in raw['courses']) row['sourceId']: row};
  final originalScheduledIds = {
    for (final part in audit['candidates'])
      for (final c in frozenRead(part['file'])['courses'])
        if ((c['schedules'] as List).isNotEmpty) c['sourceId'],
  };
  test(
    'Current CELL source codes, sections, category and exam hours remain separate from lectures',
    () {
      final extension = read('extension-audit.json');
      final name = extension['candidate']['file'] as String;
      expect(
        sha256.convert(File('$directory/$name').readAsBytesSync()).toString(),
        extension['candidate']['sha256'],
      );
      final cell = UniversityDataset.fromJson(read(name)).courses;
      expect(cell, hasLength(3));
      final native =
          read('notice-8464186-educational-receipt.json')['educationalLines']
              as List;
      final rawCell = read(name)['courses'] as List;
      expect(native.where((x) => x == '01COR146'), hasLength(3));
      expect(cell.map((c) => c.section).toSet(), {'10', '11', '12'});
      final allIds = {
        ...courses.map((c) => c.sourceId),
        ...cell.map((c) => c.sourceId),
      };
      expect(allIds, hasLength(80));
      for (final c in cell) {
        expect(native.join(' '), contains('${c.section}분반'));
        expect(c.code, '01COR146');
        expect(c.credits, 1);
        expect(c.sourceClassification, '중핵교양(1영역)');
        expect(c.meetings, isEmpty);
        final row = rawCell.singleWhere((r) => r['sourceId'] == c.sourceId);
        expect(row['publishedOperatingWeekCount'], 5);
        expect(row['publishedExamPlans'], hasLength(2));
        for (final exam in row['publishedExamPlans']) {
          expect(DateTime.parse(exam['date']).weekday, 6);
          expect(exam['startMinute'], 900);
          expect(exam['endMinute'], 930);
          expect(exam['finalDateRequiresSectionNotice'], true);
        }
        for (final mode in [
          LectureMode.inPerson,
          LectureMode.liveOnline,
          LectureMode.video,
        ]) {
          final held = c.toTimetable(id: c.sourceId, mode: mode);
          expect(held.meetings, isEmpty);
          expect(held.isValid, false);
        }
      }
      final subjects =
          read('integrated-liberal-education-native-subjects.json')['rows']
              as List;
      expect(subjects, hasLength(6));
      for (final subject in subjects) {
        expect(subject['nativeSectionPublished'], false);
        expect(subject['section'], '');
        expect(subject['candidateIncluded'], false);
        expect(subject['sourceOperatingInstitution'], '동서대학교');
      }
    },
  );
  test(
    'Split union preserves 77 source identities and every other raw field',
    () {
      final prior = read(
        'donga-institution-2026-2.published-partial-20261008.json',
      );
      final old = {for (final c in prior['courses']) c['sourceId']: c};
      expect(records, hasLength(77));
      expect(records.keys.toSet(), old.keys.toSet());
      expect(raw['courses'], hasLength(77));
      expect((audit['candidates'] as List).map((p) => p['classes']).toList(), [
        39,
        38,
      ]);
      for (final c in raw['courses']) {
        final frozen = (audit['candidates'] as List)
            .expand((part) => frozenRead(part['file'])['courses'] as List)
            .singleWhere((row) => row['sourceId'] == c['sourceId']);
        final restored = Map<String, dynamic>.from(frozen as Map);
        restored['campus'] = 'unknown';
        expect(restored, old[c['sourceId']]);
        if (c['campus'] == 'seunghak') {
          expect(c['nativeCampus'], '승학');
          for (final r in c['publicEducationRows']) {
            expect(r['education']['수업장소'], contains('(승학)'));
            expect(r['education']['교과과정 관련'], isNot('동서대 교과'));
          }
        } else {
          expect(c['campus'], 'unknown');
        }
      }
    },
  );
  test(
    'Latest published native identities, educational source and exact closure exclusion',
    () {
      for (final part in audit['candidates']) {
        expect(
          sha256
              .convert(
                File('$campusDirectory/${part['file']}').readAsBytesSync(),
              )
              .toString(),
          part['sha256'],
        );
      }
      expect(courses, hasLength(77));
      expect(read('public-education-37448.json')['rows'], hasLength(89));
      final closed =
          (jsonDecode(
                    File(
                      '$sourceDirectory/closure-educational-rows.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .map((r) => '${r['nativeSubjectCode']}/${r['nativeSection']}')
              .toSet();
      expect(closed, hasLength(162));
      expect(audit['closedJoin'], hasLength(7));
      for (final c in courses) {
        expect(closed.contains('${c.code}/${c.section}'), false);
        final record = records[c.sourceId];
        expect(record['referenceKind'], '교과목코드');
        expect(
          record['campus'],
          record['nativeCampus'] == '승학' ? 'seunghak' : 'unknown',
        );
        for (final row in record['publicEducationRows']) {
          final e = row['education'];
          expect(c.code, e['교과목 코드']);
          expect(c.section, e['분반']);
          expect(c.credits, e['학점']);
        }
        if (originalScheduledIds.contains(c.sourceId)) {
          expect(c.remarks, contains('실제 75분'));
        }
      }
      final held = (audit['holds'] as List)
          .map((r) => '${r['nativeSubjectCode']}/${r['nativeSection']}')
          .toSet();
      expect(held, hasLength(66));
      final expanded =
          (jsonDecode(
                    File(
                      'work/university-research/catalog-c/donga-ordinary-reservation-v3-20261008/candidate-audit.json',
                    ).readAsStringSync(),
                  )['expandedObjects']
                  as List)
              .map((row) => row['sourceId'])
              .toSet();
      for (final c in courses.where(
        (c) =>
            held.contains('${c.code}/${c.section}') &&
            !expanded.contains(c.sourceId),
      )) {
        expect(c.meetings, isEmpty);
      }
    },
  );
  test(
    'Source weekday, room and actual instruction ends including changed weekday makeups',
    () {
      final proof = read('native-clock-proof.json');
      final clocks = <int, List<int>>{};
      for (final row in [
        ...proof['actual75MinuteGroups'],
        ...proof['actual70MinuteNightGroups'],
      ]) {
        clocks[(row['periods'] as List).first as int] = [
          row['startMinutes'] as int,
          row['endMinutes'] as int,
        ];
      }
      final excluded = {
        ...(audit['excludedHolidays'] as List),
        ...(audit['excludedMidtermDates'] as List),
      };
      final makeups = audit['makeups'] as Map<String, dynamic>;
      var count = 0;
      for (final c in courses.where(
        (c) => originalScheduledIds.contains(c.sourceId),
      )) {
        final e = records[c.sourceId]['publicEducationRows'][0]['education'];
        expect(e['학점'], 3);
        expect(e['이론'].toString(), '3');
        expect(e['실습'].toString(), '0');
        expect(e['수업운영방식'], '오프라인');
        final matches = RegExp(
          r'([월화수목금토일])\s*(\d+)\s*[~\-]\s*(\d+)교시',
        ).allMatches(e['수업요일/시간']).toList();
        final rooms = RegExp(r'S[0-9]{2}-[A-Z0-9\-]+\(승학\)')
            .allMatches(e['수업장소'])
            .map((m) => m[0]!.replaceAll('(승학)', ''))
            .toList();
        expect(matches, hasLength(2));
        expect(matches.map((m) => m[1]).toSet(), hasLength(2));
        expect(rooms, hasLength(2));
        final expected = <String>{};
        void add(DateTime original, DateTime actual) {
          for (var i = 0; i < matches.length; i++) {
            final m = matches[i];
            if (original.weekday != '월화수목금토일'.indexOf(m[1]!) + 1) {
              continue;
            }
            final start = int.parse(m[2]!);
            expect(int.parse(m[3]!), start + 2);
            final clock = clocks[start]!;
            expected.add(
              '${timetableDateKey(actual)}/${actual.weekday}/${clock[0]}/${clock[1]}/${rooms[i]}',
            );
          }
        }

        for (
          var day = DateTime(2026, 9, 1);
          !day.isAfter(DateTime(2026, 12, 7));
          day = day.add(const Duration(days: 1))
        ) {
          if (!excluded.contains(timetableDateKey(day))) {
            add(day, day);
          }
        }
        for (final entry in makeups.entries) {
          add(DateTime.parse(entry.key), DateTime.parse(entry.value as String));
        }
        final actual = <String>{};
        for (final m in c.meetings) {
          count++;
          expect(m.weekday, m.teachingDate!.weekday);
          expect(
            actual.add(
              '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            ),
            true,
          );
        }
        expect(actual, expected, reason: '${c.code}/${c.section}');
      }
      expect(originalScheduledIds, hasLength(11));
      expect(count, 286);
      final monday = courses.firstWhere((c) => c.code == '01DME303');
      expect(
        monday.meetings.where((m) => m.date == '2026-12-08' && m.weekday == 2),
        isNotEmpty,
      );
    },
  );
  for (final mode in [
    LectureMode.inPerson,
    LectureMode.liveOnline,
    LectureMode.video,
  ]) {
    test('Actual model, 3 modes and full Drive JSON ${mode.name}', () {
      final values = <String, TimetableSyncValue>{};
      var count = 0;
      for (final c in courses.where((c) => c.meetings.isNotEmpty)) {
        final saved = c.toTimetable(id: c.sourceId, mode: mode);
        expect(saved.isValid, true);
        expect(saved.note, c.remarks);
        expect(saved.period!.start, DateTime(2026, 9, 1));
        expect(saved.period!.end, DateTime(2026, 12, 18));
        for (final m in saved.meetings) {
          count++;
          expect(m.isValid, true);
          expect(saved.modeOn(m, m.teachingDate!), mode);
          expect(saved.period!.contains(m.teachingDate!), true);
        }
        final key = timetableCourseSyncKey(saved);
        values[key] = TimetableSyncValue(
          {...saved.toJson(), 'id': key},
          DateTime.utc(2026, 10, 8),
          'research',
        );
      }
      expect(values, hasLength(25));
      expect(count, 481);
      final doc = TimetableSyncDocument.records(
        courses: values,
        schemaVersion: 2,
      );
      final json = jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>;
      final restored = TimetableSyncDocument.fromJson(json);
      expect(restored.materializeClasses(), hasLength(25));
      for (final c in restored.materializeClasses()) {
        expect(c.toJson(), values[timetableCourseSyncKey(c)]!.value);
      }
    });
  }
}
