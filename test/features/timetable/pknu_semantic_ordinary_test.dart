import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-f/pknu-operating-semantic-v2-20261008/';
  dynamic read(String file) =>
      jsonDecode(fixtureFile('$root$file').readAsStringSync());
  final audit = read('candidate-audit.json') as Map;
  final raw = [
    for (final d in audit['datasets'] as List) read(d['file'] as String),
  ];
  final records = {
    for (final d in raw)
      for (final c in d['courses'] as List)
        '${c['courseCode']}-${c['section']}': c,
  };
  final baseline = {
    for (final campus in ['daeyeon', 'unknown'])
      for (final c
          in read(
                'baseline-pknu-$campus-2026-2.published-partial-20261008.json',
              )['courses']
              as List)
        '${c['courseCode']}-${c['section']}': c,
  };
  final changed = (audit['courseProofs'] as List)
      .map((c) => c['identity'])
      .toSet();
  final models = raw
      .expand(
        (d) => UniversityDataset.fromJson(d as Map<String, dynamic>).courses,
      )
      .toList();

  test(
    'All2720 current native education identities and prior1049/43018 deep retained',
    () {
      final native =
          jsonDecode(
                fixtureFile(
                  'work/university-research/catalog-f/pknu-latest-rows.json',
                ).readAsStringSync(),
              )
              as List;
      final source = {
        for (final c in native) '${c['COURSE_NO']}-${c['DCLSS_NO']}': c,
      };
      final closed =
          (jsonDecode(
                    fixtureFile(
                      'work/university-research/catalog-f/pknu-course-rows.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .where((r) => (r['closedPhases'] as List? ?? []).isNotEmpty)
              .map((r) => r['identity'])
              .toSet();
      expect(source, hasLength(2720));
      expect(records, hasLength(2720));
      expect(closed, hasLength(114));
      expect(records.keys.toSet().intersection(closed), isEmpty);
      var oldScheduled = 0;
      var oldMeetings = 0;
      for (final identity in records.keys) {
        final c = records[identity];
        final old = baseline[identity];
        final e = source[identity];
        for (final field in (c['sourceCurrentEducation'] as Map).keys) {
          expect(c['sourceCurrentEducation'][field], e[field]);
        }
        expect(e['YY'], '2026');
        expect(e['SHTM_CD'], 'U0003002');
        expect(e['CLS_CLSS_YN'], 'N');
        expect(
          (c['sourceCurrentEducation'] as Map).containsKey('STAFF_NO'),
          false,
        );
        if (!changed.contains(identity)) {
          expect(c, old);
        } else {
          expect(old['schedules'], isEmpty);
          for (final field in (old as Map).keys) {
            if ([
              'schedules',
              'scheduleStatus',
              'dateProofKind',
              'remarks',
              'departmentRemarks',
            ].contains(field)) {
              continue;
            }
            expect(c[field], old[field]);
          }
        }
        if ((old['schedules'] as List).isNotEmpty) {
          oldScheduled++;
          oldMeetings += (old['schedules'] as List).length;
        }
        expect(c['campus'], old['campus']);
      }
      expect(oldScheduled, 1049);
      expect(oldMeetings, 43018);
      expect(changed, hasLength(9));
    },
  );

  test(
    'Fresh30 public teaching receipts header identities and excluded contact fields;61 lexical decisions retained',
    () {
      final files = fixtureDirectory(root)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.current-operating-education.json'))
          .toList();
      expect(files, hasLength(30));
      for (final file in files) {
        final r = jsonDecode(file.readAsStringSync()) as Map;
        expect(r['year'], '2026');
        expect(r['semester'], '2');
        expect(r['rawBodyStored'], false);
        final c = records[r['identity']];
        final f = r['fields'] as Map;
        expect((f['학수번호'] as List).join(), c['courseCode']);
        expect((f['분반'] as List).join(), c['section']);
        expect((f['강의시간'] as List).join(' '), c['sourceSchedule']);
        expect((f['강의실'] as List).join(', '), c['sourceClassroom']);
        for (final x in r['selectedAcademicContexts'] as List) {
          expect(x['sourceTextIndex'] >= r['educationalBodyStartIndex'], true);
          expect(
            RegExp(
              r'(?<!\d)0\d{8,10}(?!\d)|@|연락처|이메일|상담시간|연구실|담당교수',
            ).hasMatch(x['text'] as String),
            false,
          );
        }
      }
      final semantic = read('lexical61-semantic-source-audit.json') as Map;
      expect(semantic['rows'], hasLength(61));
      for (final row in semantic['rows'] as List) {
        expect(
          sha256
              .convert(
                fixtureFile(row['sourceReceipt'] as String).readAsBytesSync(),
              )
              .toString(),
          row['receiptSHA256'],
        );
        expect(row['newLectureDatesFromWeekNumbersInvented'], false);
      }
    },
  );

  test(
    'Nine eligible plans use source clocks rooms date exceptions and no ambiguous Tuesday/Thursday1–9 mapping',
    () {
      final policy = read('current-clock-policy-education.json') as Map;
      expect(policy['revision'], '2026-01-21');
      expect(policy['clockEvidence'], contains('11교시\n19:00-19:50'));
      expect(
        policy['clockEvidence'],
        contains('9교시\n17:00-17:50\n21:00-22:15'),
      );
      final excluded =
          (read(
                    '../pknu-current-20261008/candidate-audit.json',
                  )['excludedHolidays']
                  as List)
              .toSet();
      var count = 0;
      for (final identity in changed) {
        final c = records[identity];
        final receipt =
            read('$identity.current-operating-education.json') as Map;
        final context = (receipt['selectedAcademicContexts'] as List)
            .map((x) => x['text'])
            .join('\n');
        final native = <Map<String, int>>[];
        for (final part in RegExp(
          r'([월화수목금토일])(\d+(?:,\d+)*)',
        ).allMatches((receipt['fields']['강의시간'] as List).join(' '))) {
          for (final p in part[2]!.split(',').map(int.parse)) {
            native.add({
              'weekday': '월화수목금토일'.indexOf(part[1]!) + 1,
              'period': p,
            });
          }
        }
        expect(native, c['sourceNativePeriods']);
        final expected = <String>{};
        if (identity == '114580-101') {
          expect(context, contains('비대면 실시간 시험'));
          expect(context, contains('12월 9일(수) 12:00~13:00'));
          expected.add('2026-12-09/3/720/780/');
        } else {
          final dates = <String>{};
          if (identity == '112888-101') {
            for (final day in [
              '09-05',
              '09-19',
              '10-03',
              '10-17',
              '10-24',
              '11-07',
              '11-21',
              '12-19',
            ]) {
              dates.add('2026-$day');
            }
            for (final text in [
              '9월5일',
              '9월19일',
              '10월3일',
              '10월17일',
              '10월24일',
              '11월7일',
              '11월21일',
              '12월19일',
            ]) {
              expect(context, contains(text));
            }
          } else if (identity == '103392-103') {
            for (final day in [
              '09-01',
              '10-13',
              '10-20',
              '10-27',
              '12-01',
              '12-15',
            ]) {
              dates.add('2026-$day');
            }
            expect(
              native.every((p) => p['period']! > 9 && p['period']! <= 14),
              true,
            );
            expect(context, contains('대면수업(9월01일)'));
            expect(context, contains('대면평가(12월15일)'));
            expect(
              c['sourceSemanticOperatingEvidence']['basis'],
              contains('inferential clock mapping'),
            );
          } else {
            for (
              var d = DateTime(2026, 9, 1);
              !d.isAfter(DateTime(2026, 12, 7));
              d = d.add(const Duration(days: 1))
            ) {
              final date = d.toIso8601String().substring(0, 10);
              if (!excluded.contains(date)) {
                dates.add(date);
              }
            }
            if (identity == '100987-101') {
              expect(context, contains('10월 26일 월요일 수업시간'));
              expect(context, contains('12월 14일 월요일 수업시간'));
              dates.add('2026-12-14');
            }
            if (['112758-101', '112807-101'].contains(identity)) {
              expect(context.replaceAll(' ', ''), contains('12월18일'));
              dates.add('2026-12-18');
            }
            expect(
              native.every((p) => p['weekday'] != 2 && p['weekday'] != 4),
              true,
            );
          }
          for (final date in dates) {
            final weekday = DateTime.parse(date).weekday;
            for (final p in native.where((p) => p['weekday'] == weekday)) {
              final start = 480 + p['period']! * 60;
              expected.add(
                '$date/$weekday/$start/${start + 50}/${c['sourceClassroom']}',
              );
            }
          }
        }
        final actual = (c['schedules'] as List)
            .map(
              (m) =>
                  '${m['date']}/${m['weekday']}/${m['startMinute']}/${m['endMinute']}/${m['classroom']}',
            )
            .toSet();
        expect(actual, expected, reason: identity as String);
        expect(actual, hasLength((c['schedules'] as List).length));
        count += actual.length;
      }
      expect(count, 323);
    },
  );

  test(
    'Known unresolved mode clock room and intensive courses remain held; current campuses unchanged',
    () {
      for (final identity in [
        '112668-101',
        '100663-101',
        '101066-101',
        '101066-102',
        '107324-102',
        '107919-101',
        '101280-101',
        '102185-101',
        '109713-102',
      ]) {
        expect(records[identity]['schedules'], isEmpty);
      }
      expect(
        records.values.where((c) => (c['schedules'] as List).isEmpty),
        hasLength(1662),
      );
      expect(records['102811-101']['campus'], 'unknown');
      expect(records['106337-101']['campus'], 'unknown');
      expect(records['114409-102']['campus'], 'unknown');
      for (final d in raw) {
        expect(d['completionClaim'], false);
        expect(d['wholeOperatingVerified'], false);
        expect(d['wholeSchoolCourseCoverageComplete'], false);
      }
    },
  );

  test(
    '1058actual classes43341meetings full Drive allthree user mode preservation',
    () {
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = models
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        expect(before, hasLength(1058));
        final document = TimetableSyncDocument.legacy(
          courses: before,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final data = document.toJson();

        final after = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
        ).materializeClasses();
        final originals = {for (final c in before) c.sourceId: c};
        expect(after, hasLength(1058));
        var count = 0;
        for (final c in after) {
          final old = originals[c.sourceId]!;
          expect(c.isValid, true);
          expect(c.defaultMode, mode);
          expect(c.title, old.title);
          expect(c.professor, old.professor);
          expect(c.note, old.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            old.meetings.map((m) => m.toJson()).toList(),
          );
          count += c.meetings.length;
        }
        expect(count, 43341);
      }
    },
  );
}
