import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'SSU expanded dated plans preserve source-specific remote and exam holds',
    () {
      const root = 'work/university-research/catalog-f/ssu/';
      final dataset = UniversityDataset.fromJson(
        jsonDecode(
              fixtureFile(
                'assets/timetable/ssu-main-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      expect(dataset.courses, hasLength(2219));
      final selected = dataset.courses
          .where((c) => c.hasSchedulableMeetings)
          .toList();
      expect(selected, hasLength(2044));
      expect(selected.fold<int>(0, (n, c) => n + c.meetings.length), 56624);
      final baseline =
          jsonDecode(
                fixtureFile(
                  '${root}ssu-main-2026-2.whole2219-partial-dated-v3.json',
                ).readAsStringSync(),
              )
              as Map;
      final priorIds = (baseline['courses'] as List)
          .where((c) => (c['schedules'] as List).isNotEmpty)
          .map((c) => c['sourceId'])
          .toSet();
      selected.removeWhere((c) => !priorIds.contains(c.sourceId));
      expect(selected, hasLength(17));
      expect(selected.fold<int>(0, (n, c) => n + c.meetings.length), 121);
      final writing = selected.singleWhere(
        (c) => c.sourceId.endsWith('/2150523201'),
      );
      expect(writing.code, '21505232');
      expect(writing.section, '01');
      expect(writing.meetings, hasLength(28));
      expect(writing.meetings.last.date, '2026-12-16');
      expect(writing.meetings.last.weekday, 3);
      expect(writing.meetings.last.classroom, '미래관 20201');
      for (final m in writing.meetings) {
        expect(m.originalStartMinute, 810);
        expect(m.originalEndMinute, 885);
        expect(m.classroom, m.weekday == 1 ? '미래관 20206' : '미래관 20201');
        expect({
          '2026-10-05',
          '2026-12-07',
          '2026-12-14',
          '2026-12-21',
        }, isNot(contains(m.date)));
      }
      final expectedNewCounts = {
        '2150542401': 26,
        '2150222901': 25,
        '2150569301': 26,
        '2150551501': 4,
      };
      final heldDates = {
        '2150542401': {'2026-10-05', '2026-11-02', '2026-12-09', '2026-12-14'},
        '2150222901': {
          '2026-09-24',
          '2026-10-20',
          '2026-10-22',
          '2026-12-08',
          '2026-12-10',
        },
        '2150569301': {'2026-09-24', '2026-10-01', '2026-11-05', '2026-12-08'},
      };
      for (final entry in expectedNewCounts.entries) {
        final c = selected.singleWhere(
          (c) => c.sourceId.endsWith('/${entry.key}'),
        );
        expect(c.meetings, hasLength(entry.value));
        for (final m in c.meetings) {
          expect(m.originalEndMinute - m.originalStartMinute, 75);
          expect(heldDates[entry.key] ?? <String>{}, isNot(contains(m.date)));
        }
      }
      final semantics = selected.singleWhere(
        (c) => c.sourceId.endsWith('/2150542401'),
      );
      expect(semantics.meetings.any((m) => m.date == '2026-12-07'), isTrue);
      for (final m in semantics.meetings) {
        expect(m.originalStartMinute, 540);
        expect(m.classroom, '미래관 20201');
      }
      final culture = selected.singleWhere(
        (c) => c.sourceId.endsWith('/2150569301'),
      );
      for (final d in ['2026-11-03', '2026-11-10', '2026-12-10']) {
        expect(culture.meetings.any((m) => m.date == d), isTrue);
      }
      for (final m in culture.meetings) {
        expect(m.originalStartMinute, 720);
        expect(m.classroom, m.weekday == 2 ? '미래관 20303' : '미래관 20304');
      }
      final criticism = selected.singleWhere(
        (c) => c.sourceId.endsWith('/2150551501'),
      );
      expect(criticism.meetings.map((m) => m.date).toList(), [
        '2026-09-01',
        '2026-09-03',
        '2026-09-08',
        '2026-09-10',
      ]);
      final prior = UniversityDataset.fromJson(
        jsonDecode(
              fixtureFile(
                '${root}ssu-main-2026-2.whole2219-partial-dated-v2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      for (final c in prior.courses.where((c) => c.hasSchedulableMeetings)) {
        final next = selected.singleWhere((n) => n.sourceId == c.sourceId);
        expect(
          next.meetings.map((m) => m.toJson()).toList(),
          c.meetings.map((m) => m.toJson()).toList(),
        );
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = selected
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final doc = TimetableSyncDocument.legacy(
          courses: originals,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(17));
        final lookup = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          final original = lookup[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
          expect(c.note, original.note);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), LectureMode.inPerson);
          }
        }
        final restoredWriting = restored.singleWhere(
          (c) => c.sourceId!.endsWith('/2150523201'),
        );
        expect(restoredWriting.note, contains('10월 5일'));
        expect(restoredWriting.note, contains('12월 7일'));
        expect(restoredWriting.note, contains('12월 16일'));
        expect(restoredWriting.note, contains('수강대상'));
      }
    },
  );
}
