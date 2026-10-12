import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';

void main() {
  test(
    'Changwon native identity, source-specific dates and all modes survive Drive restoration',
    () {
      const root = 'work/university-research/catalog-v/';
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/changwon-unknown-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final dataset = UniversityDataset.fromJson(raw);
      final source =
          jsonDecode(
                File(
                  '${root}changwon-current-educational-rows-20261008.json',
                ).readAsStringSync(),
              )
              as List;
      final original = <String, List<dynamic>>{};
      for (final r in source) {
        original.putIfAbsent('${r['code']}-${r['section']}', () => []).add(r);
      }
      expect(dataset.courses, hasLength(1754));
      for (final r in raw['courses'] as List) {
        expect(
          r['sourceEducation']['originalPublicRows'],
          original['${r['courseCode']}-${r['section']}'],
        );
        expect(r['courseCode'], matches(RegExp(r'^[A-Z]{3}\d{4}$')));
        expect(r['section'], matches(RegExp(r'^\d{2}$')));
      }
      final published = dataset.courses
          .where((c) => c.hasSchedulableMeetings)
          .toList();
      expect(published, hasLength(1412));
      expect(published.expand((c) => c.meetings), hasLength(28702));
      final baseline =
          jsonDecode(
                File(
                  '${root}changwon-unknown-2026-2.eleven-dated-v2.json',
                ).readAsStringSync(),
              )
              as Map;
      final priorIds = (baseline['courses'] as List)
          .where((c) => (c['schedules'] as List).isNotEmpty)
          .map((c) => c['sourceId'])
          .toSet();
      published.removeWhere((c) => !priorIds.contains(c.sourceId));
      expect(published, hasLength(11));
      expect(published.expand((c) => c.meetings), hasLength(185));
      final byCode = {for (final c in published) c.code: c};
      final workshop = byCode['EDA0077']!;
      expect(workshop.meetings.map((m) => m.date), contains('2026-12-09'));
      expect(
        workshop.meetings.map((m) => m.date),
        isNot(contains('2026-10-28')),
      );
      expect(
        workshop.meetings.map((m) => m.date),
        isNot(contains('2026-11-03')),
      );
      final exam = workshop.meetings.singleWhere((m) => m.date == '2026-10-21');
      expect(exam.originalStartMinute, 600);
      expect(exam.originalEndMinute, 660);
      final early = byCode['EDA0108']!.meetings.singleWhere(
        (m) => m.date == '2026-09-16',
      );
      expect(early.originalEndMinute, 870);
      expect(
        byCode['EDA0108']!.meetings.map((m) => m.date),
        isNot(contains('2026-12-09')),
      );
      final shifted = byCode['EDA0112']!;
      expect(
        shifted.meetings.where((m) => m.date == '2026-10-08'),
        hasLength(1),
      );
      expect(
        shifted.meetings.map((m) => m.date),
        isNot(contains('2026-09-24')),
      );
      expect(shifted.meetings.map((m) => m.date), contains('2026-11-19'));
      expect(
        byCode['EDA0093']!.meetings.map((m) => m.date),
        isNot(contains('2026-11-24')),
      );
      final festival = byCode['GEA7537']!;
      final field = festival.meetings
          .where(
            (m) => ['2026-10-23', '2026-10-24', '2026-10-25'].contains(m.date),
          )
          .toList();
      expect(field, hasLength(9));
      expect(field.every((m) => m.classroom.isEmpty), isTrue);
      expect(field.map((m) => m.weekday).toSet(), {5, 6, 7});
      expect(
        festival.meetings.map((m) => m.date),
        isNot(contains('2026-09-15')),
      );
      final previous = UniversityDataset.fromJson(
        jsonDecode(
              File(
                '${root}changwon-unknown-2026-2.five-dated-v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
      );
      for (final old in previous.courses.where(
        (c) => c.hasSchedulableMeetings,
      )) {
        expect(
          byCode[old.code]!.meetings.map((m) => m.toJson()).toList(),
          old.meetings.map((m) => m.toJson()).toList(),
        );
      }
      for (final code in ['MUA0530', 'MUA0532', 'MUA0737', 'MUA0741']) {
        final course = byCode[code]!;
        expect(course.meetings, hasLength(code == 'MUA0532' ? 21 : 23));
        for (final m in course.meetings) {
          expect(m.originalStartMinute, 960);
          expect(m.originalEndMinute, 1080);
          expect(
            m.classroom,
            m.date == '2026-10-20'
                ? '61106'
                : m.weekday == 2
                ? '63402'
                : '63404',
          );
          expect(m.weekday, isIn([2, 4]));
          expect([
            '2026-09-24',
            '2026-10-31',
            '2026-11-02',
            '2026-11-14',
            '2026-11-16',
            '2026-11-19',
            '2026-11-24',
          ], isNot(contains(m.date)));
        }
      }
      final psychology = byCode['NSA0126']!;
      expect(psychology.meetings, hasLength(14));
      final mid = psychology.meetings.singleWhere(
        (m) => m.date == '2026-10-21',
      );
      expect(mid.originalStartMinute, 660);
      expect(mid.originalEndMinute, 720);
      expect(
        psychology.meetings.map((m) => m.date),
        isNot(contains('2026-09-23')),
      );
      expect(
        psychology.meetings.map((m) => m.date),
        isNot(contains('2026-12-16')),
      );
      expect(psychology.meetings.any((m) => m.date == '2026-12-09'), true);
      final challenge = byCode['GEA8002']!;
      expect(challenge.meetings, hasLength(14));
      expect(challenge.meetings.any((m) => m.date == '2026-12-15'), true);
      expect(
        challenge.meetings.map((m) => m.date),
        isNot(contains('2026-11-24')),
      );
      expect(
        challenge.meetings.map((m) => m.date),
        isNot(contains('2026-12-12')),
      );
      for (final m in challenge.meetings) {
        expect(m.originalStartMinute, 840);
        expect(m.originalEndMinute, 960);
        expect(m.classroom, 'CWNU가온홀');
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = published
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
        expect(restored, hasLength(11));
        final before = {for (final c in classes) c.sourceId: c};
        for (final c in restored) {
          expect(c.isValid, isTrue);
          expect(c.defaultMode, mode);
          expect(c.note, before[c.sourceId]!.note);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            before[c.sourceId]!.meetings.map((m) => m.toJson()).toList(),
          );
          expect(c.period!.end, DateTime(2026, 12, 20));
          expect(c.note, contains('예약 블록'));
          for (final m in c.meetings) {
            expect(m.teachingDate!.weekday, m.weekday);
            expect(c.period!.contains(m.teachingDate!), isTrue);
            expect(c.modeOn(m, m.teachingDate!), LectureMode.inPerson);
          }
        }
      }
    },
  );
}
