import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-c/hansung-held-source-review-v2-20261009/';
  Map<String, dynamic> read(String path) {
    final actual = path;
    final data =
        jsonDecode(fixtureFile(actual).readAsStringSync())
            as Map<String, dynamic>;
    for (final row in data['courses'] ?? []) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
    }
    return data;
  }

  final prior = read('${root}hansung-frozen-prior-v1-1489.json');
  final raw = read(
    '${root}hansung-main-2026-2.held-ordinary-candidate-v2.json',
  );
  final proof = read('${root}current-source-candidate-audit-v2.json');
  final calendar = read('${root}hansung-current-term-evidence.json');
  final rule = read('${root}hansung-current-school-closure-evidence.json');
  final dataset = UniversityDataset.fromJson(raw);
  final old = {for (final c in prior['courses'] as List) c['sourceId']: c};
  final accepted = {
    for (final c in proof['reviews194'] as List)
      if (c['decision'] == 'ordinaryReservation') c['sourceId']: c,
  };
  String clean(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
  test(
    'whole1489/native and frozen978/14501 remain deeply unchanged; exact133 added and known holds preserved',
    () {
      expect(dataset.courses, hasLength(1489));
      expect(dataset.courses.map((c) => c.sourceId).toSet(), old.keys.toSet());
      expect(accepted, hasLength(133));
      expect(proof['reviews194'], hasLength(194));
      final previous = (prior['courses'] as List)
          .where((c) => (c['schedules'] as List).isNotEmpty)
          .toList();
      expect(previous, hasLength(978));
      expect(
        previous.fold<int>(0, (n, c) => n + (c['schedules'] as List).length),
        14501,
      );
      for (final c in raw['courses'] as List) {
        final p = old[c['sourceId']]!;
        if (!accepted.containsKey(c['sourceId']) ||
            (p['schedules'] as List).isNotEmpty) {
          expect(c, p);
        }
        for (final e in (p as Map).entries) {
          if (![
            'schedules',
            'scheduleStatus',
            'period',
            'departmentRemarks',
            'sourceEducation',
          ].contains(e.key)) {
            expect(c[e.key], e.value);
          }
        }
      }
      for (final key in [
        'GEN0867-7',
        'GEN0867-A',
        'CTS0011-7',
        'CTS0011-8',
        'CTS0011-A',
        'CTS0011-N',
        'GEN0845-A',
        'GEN0845-N',
        'V020038-7',
        'V020038-9',
      ]) {
        final bits = key.split('-');
        expect(
          dataset.courses
              .singleWhere(
                (c) =>
                    c.sourceId == 'hansung/main/2026/2/${bits[0]}/${bits[1]}',
              )
              .meetings,
          isEmpty,
        );
      }
      expect(
        dataset.courses.where((c) => c.meetings.isNotEmpty),
        hasLength(1111),
      );
      expect(
        (raw['courses'] as List).where(
          (c) => c['scheduleStatus'] == 'unrecognized',
        ),
        hasLength(268),
      );
      expect(
        (raw['courses'] as List).where(
          (c) => c['scheduleStatus'] == 'unscheduled',
        ),
        hasLength(110),
      );
    },
  );
  test(
    'own current school diagram/native weekday-room/full source194 and explicit operation omissions match every1710 booking',
    () {
      final scope = calendar['scope'] as List;
      for (final row in [
        {
          'title': '개시일 및 개강일',
          'start': '2026-08-31',
          'endExclusive': '2026-09-01',
        },
        {
          'title': '기말고사, 보강 주',
          'start': '2026-12-07',
          'endExclusive': '2026-12-20',
        },
        {'title': '종강', 'start': '2026-12-19', 'endExclusive': '2026-12-20'},
      ]) {
        expect(
          scope.where(
            (e) =>
                e['title'] == row['title'] &&
                e['start'] == row['start'] &&
                e['endExclusive'] == row['endExclusive'],
          ),
          hasLength(1),
        );
      }
      expect(rule['article'], 11);
      expect(rule['nationalHolidayDates2026Fall'], [
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      ]);
      // Direct manual reads of own school clock chart; M endpoints and Thursday evening difference remain exact.
      const starts75 = {
        '1': 540,
        '2M': 630,
        '4': 720,
        '5M': 810,
        '7': 900,
        '8M': 990,
        '10': 1080,
        '11M': 1165,
        '13': 1245,
      };
      const ends75 = {
        '2': 615,
        '3M': 705,
        '5': 795,
        '6M': 885,
        '8': 975,
        '9M': 1065,
        '11': 1155,
        '12M': 1240,
        '14': 1320,
      };
      const nightStarts50 = {10: 1080, 11: 1135, 12: 1190, 13: 1245, 14: 1300};
      const nightEnds50 = {10: 1130, 11: 1185, 12: 1240, 13: 1295, 14: 1350};
      var added = 0;
      for (final c in dataset.courses.where(
        (c) => accepted.containsKey(c.sourceId),
      )) {
        final p = accepted[c.sourceId]!;
        final receipt = read(
          '${root}selected-current-education-plans/${p['key']}.json',
        );
        final education = receipt['education'] as Map;
        expect(education['data_year'], '2026');
        expect(education['hakgi'], '2');
        expect(education['kwamok'], c.code);
        expect(education['bunban'], c.section);
        expect(clean(education['kwamokname'] as String), c.title);
        expect(clean(education['timeclassroom'] as String), c.sourceSchedule);
        expect(education['offlineyn'], 'Y');
        expect(education['weeks'], hasLength(15));
        expect(
          (education['weeks'] as List).every(
            (w) => (w['topicEducationLiteral'] as String).isNotEmpty,
          ),
          true,
        );
        expect(p['all15WeeksAndFullEducationalNotesIndependentlyRead'], true);
        expect(p['videoHoursUsedAsPhysicalClock'], false);
        expect(p['plannedMakeupDatesUsedAsRegularDates'], false);
        final expected = <String, String>{};
        for (final block in c.sourceSchedule.split('/')) {
          if (RegExp(r'^\s*온라인강좌\s+[\d.]+시간\s*$').hasMatch(block)) {
            continue;
          }
          final pair = RegExp(
            r'^\s*(.+?)\s+((?:[월화수목금]\d+M?~\d+M?)(?:\s*,\s*[월화수목금]\d+M?~\d+M?)*)\s*$',
          ).firstMatch(block)!;
          final room = pair[1]!.trim();
          for (final slot in pair[2]!.split(',')) {
            final m = RegExp(
              r'^\s*([월화수목금])(\d+M?)~(\d+M?)\s*$',
            ).firstMatch(slot)!;
            final day = '월화수목금'.indexOf(m[1]!) + 1;
            final int start;
            final int end;
            if ([1, 3, 4].contains(day)) {
              start = day == 4 && m[2] == '11M' ? 1180 : starts75[m[2]]!;
              end = day == 4 && m[3] == '12M' ? 1250 : ends75[m[3]]!;
            } else {
              final first = int.parse(m[2]!);
              final last = int.parse(m[3]!.replaceAll('M', ''));
              start = first <= 9
                  ? 540 + (first - 1) * 60
                  : nightStarts50[first]!;
              end = last <= 9 ? 590 + (last - 1) * 60 : nightEnds50[last]!;
            }
            for (
              var d = DateTime(2026, 8, 31);
              !d.isAfter(DateTime(2026, 12, 6));
              d = d.add(const Duration(days: 1))
            ) {
              final ds =
                  '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              if (d.weekday != day ||
                  (rule['nationalHolidayDates2026Fall'] as List).contains(ds) ||
                  (p['explicitExceptionWeeks'] as Map).containsKey(
                    ((d.difference(DateTime(2026, 8, 31)).inDays ~/ 7) + 1)
                        .toString(),
                  )) {
                continue;
              }
              expected['$ds/$day/$start/$end'] = room;
            }
          }
        }
        expect(c.meetings, hasLength(expected.length));
        expect(c.meetings, hasLength(p['newReservationCount'] as int));
        for (final m in c.meetings) {
          expect(DateTime.parse(m.date!).weekday, m.weekday);
          expect(
            expected['${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}'],
            m.classroom,
          );
        }
        expect(
          c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).note,
          contains('실제 출석이나 날짜별 운영을 모두 확인했다는 뜻이 아닙니다'),
        );
        added += c.meetings.length;
      }
      expect(added, 1710);
      for (final key in ['GEN0754-7', 'GEN0754-A']) {
        final bits = key.split('-');
        final c = dataset.courses.singleWhere(
          (c) => c.sourceId == 'hansung/main/2026/2/${bits[0]}/${bits[1]}',
        );
        expect(
          c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).note,
          contains('불허 대상: 일본 교환 유학생(다녀온 학생) 및 일본인 유학생'),
        );
      }
    },
  );
  test(
    'whole1111/16211 retain every original clock room and educational condition through all3 modes/full Drive JSON',
    () {
      final slots = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(slots.fold<int>(0, (n, c) => n + c.meetings.length), 16211);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final original = slots
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: original,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(1111));
        expect(restored.fold<int>(0, (n, c) => n + c.meetings.length), 16211);
        final map = {for (final c in original) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, true);
          expect(
            c.toJson()..remove('id'),
            map[c.sourceId]!.toJson()..remove('id'),
          );
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
