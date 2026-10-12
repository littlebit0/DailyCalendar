import 'dart:convert';
import '../../support/source_fixture.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily/core/academic/academic_profile.dart';

void main() {
  test('SSU integrated academic profile rejects a foreign campus', () {
    for (final id in [
      'institution:academyinfo:0000143',
      'academyinfo:0000143',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '숭실대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'ssu');
      expect(profile.timetableCampus, 'main');
      expect(profile.academicSourceId, 'ssu');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '숭실대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  test('All SSU native educational records survive product projection', () {
    final frozen =
        jsonDecode(
              fixtureFile(
                'work/university-research/catalog-f/ssu/weekly-reservations-v4-20261008/ssu-main-2026-2.whole2219-weekly-reservations-v4.json',
              ).readAsStringSync(),
            )
            as Map;
    final product =
        jsonDecode(
              fixtureFile(
                'assets/timetable/ssu-main-2026-2.json',
              ).readAsStringSync(),
            )
            as Map;
    expect(product['courses'], frozen['courses']);
    final period =
        (jsonDecode(
                  fixtureFile(
                    'assets/timetable/term-periods.json',
                  ).readAsStringSync(),
                )
                as Map)['additionalUniversities']
            as List;
    expect(
      (period.singleWhere((r) => r['university'] == 'ssu')['terms'] as List)
          .single,
      {
        'year': 2026,
        'semester': '2',
        'start': '2026-09-01',
        'end': '2026-12-21',
      },
    );
  });
  test('SSU printed dates preserve video/exam holds and final Wednesday', () {
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
    final prior = UniversityDataset.fromJson(
      jsonDecode(
            fixtureFile(
              '${root}ssu-main-2026-2.whole2219-partial-first12-v1.json',
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
  });
}
