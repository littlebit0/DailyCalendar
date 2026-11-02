// Historical checkpoint149 regression. Latest packaged152 checks are separate.
import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-f/pknu-same-term-unit-v3-20261009/';
  dynamic read(String name) =>
      jsonDecode(fixtureFile('$root$name').readAsStringSync());
  final audit = read('candidate-audit.json') as Map;
  final datasets = [
    for (final name in (audit['datasets'] as Map).keys)
      jsonDecode(
        fixtureFile(
          "work/university-research/resume-batch-20261010/before-projection/${(name as String).split('.').first}.json",
        ).readAsStringSync(),
      ),
  ];
  final records = {
    for (final d in datasets)
      for (final c in d['courses'] as List)
        '${c['courseCode']}-${c['section']}': c,
  };
  final baseline = {
    for (final campus in ['daeyeon', 'unknown'])
      for (final c
          in read(
                'baseline-pknu-$campus-2026-2.semantic-reviewed-v2-20261008.json',
              )['courses']
              as List)
        '${c['courseCode']}-${c['section']}': c,
  };
  final newIds = (audit['newCourseProofs'] as List)
      .map((x) => x['identity'])
      .toSet();
  final source = read('official-semester-xlsx-education.json') as Map;
  final official = {
    for (final r in source['rows'] as List) r['fields']['identity']: r,
  };
  final current = {
    for (final r
        in jsonDecode(
              fixtureFile(
                'work/university-research/catalog-f/pknu-latest-rows.json',
              ).readAsStringSync(),
            )
            as List)
      '${r['COURSE_NO']}-${r['DCLSS_NO']}': r,
  };
  final semantic = {
    for (final r
        in read('current-semantic-ordinary-exclusions-education.json')['rows']
            as List)
      r['identity']: r,
  };
  List<String> parse(String text) {
    var normalized = text;
    for (final e in {
      'Monday': '월',
      'Tuesday': '화',
      'Wednesday': '수',
      'Thursday': '목',
      'Friday': '금',
      'Saturday': '토',
      'Sunday': '일',
    }.entries) {
      normalized = normalized.replaceAll(e.key, e.value);
    }
    final parts = <String>[];
    for (final m in RegExp(
      r'([월화수목금토일])\s*(\d+(?:\s*[-~,]\s*\d+)*)',
    ).allMatches(normalized)) {
      final day = '월화수목금토일'.indexOf(m[1]!) + 1;
      for (final p in m[2]!.split(',')) {
        final range = p.trim().split(RegExp('[-~]')).map(int.parse).toList();
        for (var n = range.first; n <= range.last; n++) {
          parts.add('$day/$n');
        }
      }
    }
    parts.sort();
    return parts;
  }

  test(
    '2720whole known currentnative identities and1058/43341 frozen baseline deep unchanged',
    () {
      expect(records, hasLength(2720));
      expect(current, hasLength(2720));
      expect(newIds, hasLength(1039));
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
      expect(closed, hasLength(114));
      expect(records.keys.toSet().intersection(closed), isEmpty);
      var scheduled = 0;
      var dates = 0;
      for (final identity in records.keys) {
        final c = records[identity];
        final old = baseline[identity];
        expect(c['sourceCurrentEducation'], old['sourceCurrentEducation']);
        for (final field in (c['sourceCurrentEducation'] as Map).keys) {
          expect(c['sourceCurrentEducation'][field], current[identity][field]);
        }
        expect(c['campus'], old['campus']);
        expect(c['publicPlanEducation'], old['publicPlanEducation']);
        if (!newIds.contains(identity)) {
          expect(c, old);
        } else {
          expect(old['schedules'], isEmpty);
          for (final key in (old as Map).keys) {
            if ([
              'schedules',
              'scheduleStatus',
              'remarks',
              'departmentRemarks',
              'dateProofKind',
            ].contains(key)) {
              continue;
            }
            expect(c[key], old[key]);
          }
          expect(
            c['sameTermUnitProvenance']['priorReservationRemarks'],
            old['remarks'],
          );
        }
        if ((old['schedules'] as List).isNotEmpty) {
          scheduled++;
          dates += (old['schedules'] as List).length;
        }
      }
      expect(scheduled, 1058);
      expect(dates, 43341);
    },
  );

  test(
    'PublishedJuly same2026-2unit actualeducational XLS cells match current native identity hours periods,changed17excluded',
    () {
      expect(source['rows'], hasLength(2835));
      final sourceIdentities = (source['rows'] as List)
          .map((r) => r['fields']['identity'])
          .toList();
      expect(sourceIdentities.toSet(), hasLength(2835));
      expect(official, hasLength(2835));
      final uniqueness =
          read('independent-xlsx-identity-unit-education-audit.json') as Map;
      expect(uniqueness['rows'], 2835);
      expect(uniqueness['uniqueIdentities'], 2835);
      expect(uniqueness['duplicateIdentities'], isEmpty);
      expect(uniqueness['sourceSHA256'], source['sourceSHA256']);
      expect(uniqueness['freshDownloadEducationReceipt']['sameBytes'], true);
      expect(
        uniqueness['freshDownloadEducationReceipt']['refreshedSHA256'],
        source['sourceSHA256'],
      );
      for (final header in uniqueness['actualHeaderCells'] as List) {
        expect(header['AT1'], '수업\n단위');
        expect(header['AU2'], '강의교시1');
        expect(header['AZ2'], '강의실1');
      }
      expect(source['publicationDate'], '2026-07-30');
      expect(source['freshIdenticalDownloadDate'], '2026-10-08');
      expect(source['sourceCurrentUnitConfirmedOct9'], false);
      expect(
        sha256
            .convert(
              fixtureFile(
                'work/university-research/catalog-f/pknu-full.xlsx',
              ).readAsBytesSync(),
            )
            .toString(),
        source['sourceSHA256'],
      );
      expect(source['columnLabels']['AT1'], '수업\n단위');
      final cachedOld = {
        for (final r
            in jsonDecode(
                  fixtureFile(
                    'work/university-research/catalog-f/pknu-course-rows.json',
                  ).readAsStringSync(),
                )
                as List)
          r['identity']: r,
      };
      final changedTimes = (audit['changedTime17'] as List).toSet();
      expect(changedTimes, hasLength(17));
      expect(newIds.intersection(changedTimes), isEmpty);
      var unit50 = 0;
      var unit75 = 0;
      for (final identity in newIds) {
        final c = records[identity];
        final published = official[identity];
        final fields = published['fields'] as Map;
        final independent = cachedOld[identity];
        for (final key in [
          'year',
          'semester',
          'title',
          'code',
          'section',
          'identity',
          'creditScheme',
          'unit',
          'periods',
          'rooms',
        ]) {
          expect(fields[key], independent[key]);
        }
        expect(fields['year'], '2026');
        expect(fields['semester'], '2');
        expect(fields['title'], c['courseName']);
        expect(c['publicPlanEducation']['fields']['교과목명'], c['courseName']);
        expect(
          parse((fields['periods'] as List).whereType<String>().join(' ')),
          parse(c['sourceSchedule'] as String),
        );
        expect(fields['creditScheme'], current[identity]['PNT_THEO_PRAC']);
        final hours = (current[identity]['PNT_THEO_PRAC'] as String)
            .split('-')
            .map(int.parse)
            .toList();
        final unit = int.parse(fields['unit'] as String);
        expect([50, 75], contains(unit));
        expect(
          parse(c['sourceSchedule'] as String).length * unit,
          (hours[1] + hours[2]) * 50,
        );
        expect(c['sourceClassroom'], c['publicPlanEducation']['fields']['강의실']);
        expect(c['publicPlanEducation']['fields']['강의형태'], '대면 수업');
        expect(
          (c['publicPlanEducation']['fields'] as Map).containsKey('수업단위'),
          false,
        );
        expect(
          c['sameTermUnitProvenance']['currentUnitDirectlyConfirmedOct9'],
          false,
        );
        expect(c['sameTermUnitProvenance']['latestRoomFromCurrentPlan'], true);
        expect(
          c['sameTermUnitProvenance']['unitCell'],
          'AT${published['row']}',
        );
        if (unit == 50) {
          unit50++;
        } else {
          unit75++;
          for (final allocation in parse(c['sourceSchedule'] as String)) {
            final n = allocation.split('/').map(int.parse).toList();
            expect([2, 4].contains(n[0]), true);
            expect(n[1] >= 1 && n[1] <= 9, true);
          }
        }
      }
      expect(unit50, 888);
      expect(unit75, 151);
    },
  );

  test(
    'New1039 ordinary exactpublished unit/currentroom/date sets and knownindividual exam exclusions independently reconstructed',
    () {
      final excluded =
          (read(
                    '../pknu-current-20261008/candidate-audit.json',
                  )['excludedHolidays']
                  as List)
              .toSet();
      final policy = read('../pknu-current-clock-policy-audit.json') as Map;
      expect(policy['revision'], '2026-01-21');
      expect(policy['clockEvidence'], contains('09:00-10:15'));
      expect(policy['clockEvidence'], contains('22:00-22:50'));
      var count = 0;
      for (final identity in newIds) {
        final c = records[identity];
        final unit = int.parse(official[identity]['fields']['unit'] as String);
        final native = parse(c['sourceSchedule'] as String);
        final extraExcluded =
            (semantic[identity]?['ordinaryExclusions'] as List? ?? []).toSet();
        final expected = <String>{};
        for (
          var date = DateTime(2026, 9, 1);
          !date.isAfter(DateTime(2026, 12, 7));
          date = date.add(const Duration(days: 1))
        ) {
          final day = date.toIso8601String().substring(0, 10);
          if (excluded.contains(day) || extraExcluded.contains(day)) {
            continue;
          }
          for (final allocation in native) {
            final parts = allocation.split('/').map(int.parse).toList();
            if (parts[0] != date.weekday) {
              continue;
            }
            final start = unit == 50
                ? 480 + parts[1] * 60
                : 540 + (parts[1] - 1) * 90;
            expected.add(
              '$day/${parts[0]}/$start/${start + unit}/${c['sourceClassroom']}',
            );
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
        for (final meeting in c['schedules'] as List) {
          expect(meeting.containsKey('deliveryMode'), false);
          expect(meeting['sourceMinuteUnit'], unit);
        }
        count += actual.length;
      }
      expect(count, 43404);
      for (final identity in [
        '100663-101',
        '101066-101',
        '101066-102',
        '105832-101',
        '105832-102',
        '105832-103',
      ]) {
        final dates = (records[identity]['schedules'] as List)
            .map((m) => m['date'])
            .toSet();
        expect(dates.contains('2026-10-20'), false);
      }
    },
  );

  test(
    'Current realasync mixed/intensive rooms/unit conflicts held and currentfield source precedence transparently retained',
    () {
      for (final identity in [
        '105115-101',
        '111220-101',
        '107474-102',
        '111872-101',
        '112708-104',
        '112706-101',
        '109713-102',
        '107919-101',
        '114343-101',
      ]) {
        expect(records[identity]['schedules'], isEmpty);
      }
      expect(
        records.values.where((c) => (c['schedules'] as List).isEmpty),
        hasLength(623),
      );
      for (final item in semantic.values) {
        expect(item['actualExamAppointmentsGenerated'], false);
        final receipt =
            jsonDecode(
                  fixtureFile(
                    item['sourceReceipt'] as String,
                  ).readAsStringSync(),
                )
                as Map;
        expect(receipt['year'], '2026');
        expect(receipt['semester'], '2');
        expect(
          (receipt['fields']['학수번호'] as List).join(),
          records[item['identity']]['courseCode'],
        );
      }
      final publication =
          read('current-official-publication-education-receipt.json') as Map;
      expect(publication['normalHTTPStatus'], 200);
      expect(publication['linksRemainOnOfficialCurrentNotice'], [true, true]);
      expect(publication['sourcePublicationDate'], '2026-07-30');
      for (final d in datasets) {
        expect(d['completionClaim'], false);
        expect(d['wholeOperatingVerified'], false);
        expect(d['wholeSchoolCourseCoverageComplete'], false);
      }
    },
  );

  test(
    '2097actual classes86745 meetings fullthreeuser modes andwhole Drive JSON',
    () {
      final models = datasets
          .expand(
            (d) =>
                UniversityDataset.fromJson(d as Map<String, dynamic>).courses,
          )
          .toList();
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final before = models
            .where((c) => c.hasSchedulableMeetings)
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        expect(before, hasLength(2097));
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
        final original = {for (final c in before) c.sourceId: c};
        expect(after, hasLength(2097));
        var count = 0;
        for (final c in after) {
          final old = original[c.sourceId]!;
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
        expect(count, 86745);
      }
    },
  );
}
