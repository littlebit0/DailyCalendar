import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const root =
      'work/university-research/catalog-c/yonsei-h1-course-specific-operation-v4-20261009/';
  Map<String, dynamic> read(String n) {
    final path = '$root$n';
    final data =
        jsonDecode(fixtureFile(path).readAsStringSync())
            as Map<String, dynamic>;
    for (final row in data['courses'] ?? []) {
      if (row['metadata']?.containsKey('researchOnly') == true) {
        row['metadata']['researchOnly'] = false;
      }
    }
    return data;
  }

  final prior = read('baseline-international-frozen-v3.json');
  final raw = read(
    'yonsei-international-2026-2.ENG1108-06-01-candidate-v4.json',
  );
  final dataset = UniversityDataset.fromJson(raw);
  const id = 'yonsei/H1/2026-2/ENG1108-06-01';
  test(
    'whole879 native metadata/all477 previous offerings deep unchanged; unique one offering50 reservations added',
    () {
      expect(raw['courses'], hasLength(879));
      final old = {for (final c in prior['courses'] as List) c['sourceId']: c};
      expect(dataset.courses.map((c) => c.sourceId).toSet(), old.keys.toSet());
      for (final c in raw['courses'] as List) {
        final p = old[c['sourceId']];
        if (c['sourceId'] != id) {
          expect(c, p);
          continue;
        }
        for (final e in (p as Map).entries) {
          if ([
            'schedules',
            'scheduleStatus',
            'remarks',
            'departmentRemarks',
          ].contains(e.key)) {
            continue;
          }
          expect(c[e.key], e.value);
        }
      }
      expect(
        dataset.courses.where((c) => c.meetings.isNotEmpty),
        hasLength(478),
      );
      final selected = dataset.courses.singleWhere((c) => c.sourceId == id);
      expect(selected.meetings, hasLength(50));
      expect(
        selected.toTimetable(id: id, mode: LectureMode.inPerson).note,
        contains('도시공학과 대상'),
      );
      final eighth = dataset.courses.singleWhere(
        (c) => c.sourceId == 'yonsei/H1/2026-2/MAT1002-08-00',
      );
      expect(eighth.meetings, isEmpty);
    },
  );
  test(
    'native06-practical01-only exact sourceMondaylecture/Wednesdaypractical/room/date bounds independently match own2026 term',
    () {
      final sources =
          jsonDecode(
                fixtureFile(
                  '${root}official-course-operation-educational-receipts.json',
                ).readAsStringSync(),
              )
              as List;
      final proof = sources.singleWhere((e) => e['reference'] == 'ENG1108');
      expect(proof['allExpectedLiteralsMatched'], true);
      expect(
        proof['educationalLiterals'],
        contains('강의시간/실험,실습,실기시간: 월3,4(수3,4)'),
      );
      final current =
          jsonDecode(
                fixtureFile(
                  '${root}fresh-narrow-native-educational-receipts.json',
                ).readAsStringSync(),
              )
              as List;
      final native = (current.single['matches'] as List).single;
      expect(native['cgprfNm'], '김진환');
      expect(native['lctreTimeNm'], '월3,4/(수3,4)');
      expect(native['lecrmNm'], 'I자A311/(I자A303)');
      expect(native['campsDivNm'], '국제');
      expect(native['rmvlcYn'], '0');
      final clock = read('current-h1-clock-independent-receipt.json');
      expect(clock['layoutVisuallyVerified'], true);
      final clockRows = clock['clockRows'] as List;
      expect(
        clockRows.singleWhere((r) => r['period'] == 3)['startMinute'],
        660,
      );
      expect(clockRows.singleWhere((r) => r['period'] == 3)['endMinute'], 710);
      expect(
        clockRows.singleWhere((r) => r['period'] == 4)['startMinute'],
        720,
      );
      expect(clockRows.singleWhere((r) => r['period'] == 4)['endMinute'], 770);
      final c = dataset.courses.singleWhere((c) => c.sourceId == id);
      final expected = <String>{};
      const holidays = {
        '2026-09-24',
        '2026-09-25',
        '2026-09-26',
        '2026-10-03',
        '2026-10-05',
        '2026-10-09',
      };
      for (
        var d = DateTime(2026, 9, 1);
        !d.isAfter(DateTime(2026, 12, 7));
        d = d.add(const Duration(days: 1))
      ) {
        final ds =
            '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        if (holidays.contains(ds) ||
            (!d.isBefore(DateTime(2026, 10, 20)) &&
                !d.isAfter(DateTime(2026, 10, 26)))) {
          continue;
        }
        if (d.weekday == 1 || d.weekday == 3) {
          for (final n in [3, 4]) {
            final room = d.weekday == 1 ? 'I자A311' : 'I자A303';
            expected.add(
              '$ds/${d.weekday}/${(8 + n) * 60}/${(8 + n) * 60 + 50}/$room',
            );
          }
        }
      }
      expect(expected, hasLength(50));
      expect(c.meetings.where((m) => m.weekday == 1), hasLength(24));
      expect(c.meetings.where((m) => m.weekday == 3), hasLength(26));
      expect(
        c.meetings
            .map(
              (m) =>
                  '${m.date}/${m.weekday}/${m.originalStartMinute}/${m.originalEndMinute}/${m.classroom}',
            )
            .toSet(),
        expected,
      );
    },
  );
  test(
    'all4 frozen campus native union/prior schedules deep preserved and whole3mode Drive',
    () {
      final campusNames = [
        'baseline-sinchon-frozen-v1.json',
        'baseline-international-frozen-v3.json',
        'baseline-mirae-frozen-v2.json',
        'baseline-unknown-frozen-v1.json',
      ];
      final previous = campusNames
          .expand((n) => read(n)['courses'] as List)
          .toList();
      final current = campusNames
          .expand(
            (n) => n == 'baseline-international-frozen-v3.json'
                ? raw['courses'] as List
                : read(n)['courses'] as List,
          )
          .toList();
      expect(current, hasLength(4710));
      expect(
        current.map((c) => c['sourceId']).toSet(),
        previous.map((c) => c['sourceId']).toSet(),
      );
      final oldMap = {for (final c in previous) c['sourceId']: c};
      for (final c in current) {
        if (c['sourceId'] != id) {
          expect(c, oldMap[c['sourceId']]);
        }
      }
      final union = campusNames
          .map(
            (n) => UniversityDataset.fromJson(
              n == 'baseline-international-frozen-v3.json' ? raw : read(n),
            ),
          )
          .expand((d) => d.courses)
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      final audit = read(
        'whole-campus-independent-union-audit.json',
      )['candidate'];
      expect(union.length, audit['scheduled']);
      expect(
        union.fold<int>(0, (n, c) => n + c.meetings.length),
        audit['reservations'],
      );
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = union
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: classes,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        final byId = {for (final c in classes) c.sourceId: c};
        expect(restored.length, classes.length);
        for (final c in restored) {
          expect(
            c.toJson()..remove('id'),
            byId[c.sourceId]!.toJson()..remove('id'),
          );
        }
      }
    },
  );
  test(
    'whole478/17093 retain every original clock room and educational condition through all3 modes/full Drive JSON',
    () {
      final slots = dataset.courses
          .where((c) => c.meetings.isNotEmpty)
          .toList();
      expect(slots.fold<int>(0, (n, c) => n + c.meetings.length), 17093);
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
        expect(restored, hasLength(478));
        expect(restored.fold<int>(0, (n, c) => n + c.meetings.length), 17093);
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
