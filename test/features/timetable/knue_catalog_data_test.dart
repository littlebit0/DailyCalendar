import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KNUE integrated profile uses its own published catalog', () {
    for (final id in [
      'academyinfo:0000031',
      'institution:academyinfo:0000031',
    ]) {
      final profile = AcademicProfile(
        universityId: id,
        universityName: '한국교원대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'knue');
      expect(profile.timetableCampus, 'main');
      expect(profile.academicSourceId, 'knue');
      expect(
        AcademicProfile(
          universityId: id,
          universityName: '한국교원대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
    }
  });
  test(
    'KNUE full742 search preserves date-specific nominal blocks and restrictions in Drive',
    () {
      const root = 'work/university-research/catalog-f/knue/';
      final raw =
          jsonDecode(
                File(
                  'assets/timetable/knue-main-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final dataset = UniversityDataset.fromJson(raw);
      final audit =
          jsonDecode(
                File(
                  '${root}knue-partial-nominal-blocks-v1-candidate-audit.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final cases = List<Map<String, dynamic>>.from(audit['cases'] as List);
      final expected = <String, List<Map<String, dynamic>>>{};
      for (final sourceCase in cases) {
        expected
            .putIfAbsent(sourceCase['courseId'] as String, () => [])
            .add(sourceCase);
      }
      final closures = List<String>.from(
        audit['schoolRegularClosures'] as List,
      );
      expect(dataset.courses, hasLength(742));
      final domains =
          jsonDecode(
                File(
                  '${root}current26-native-classification-domain-proposal-20261008.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final expectedDomains = {
        for (final row in domains['rows'] as List)
          row['exactSourceLabel']: CourseCategory.values.byName(
            row['proposedBroadDomain'] as String,
          ),
      };
      for (final c in dataset.courses) {
        expect(c.categoriesFor(), [expectedDomains[c.sourceClassification]]);
        expect(c.sourceClassification, matches(RegExp(r'^\d{2} ')));
      }
      final published = dataset.courses
          .where((c) => c.hasSchedulableMeetings)
          .toList();
      expect(published, hasLength(587));
      expect(published.expand((c) => c.meetings), hasLength(8307));
      expect(
        dataset.courses.where((c) => !c.hasSchedulableMeetings),
        hasLength(155),
      );
      for (final c in published) {
        final cid = c.sourceId.split('/').last;
        expect(c.meetings, hasLength(expected[cid]!.length));
        for (var i = 0; i < c.meetings.length; i++) {
          final m = c.meetings[i];
          final e = expected[cid]![i];
          final periods = List<int>.from(e['nativePeriods'] as List);
          expect(periods.every([1, 2, 3, 4, 6, 7, 8].contains), isTrue);
          expect(m.date, e['date']);
          expect(m.classroom, e['classroom']);
          expect(m.originalStartMinute, 480 + periods.first * 60);
          expect(m.originalEndMinute, 540 + periods.last * 60);
          expect(closures, isNot(contains(m.date)));
          expect(m.date!.compareTo('2026-08-31'), greaterThanOrEqualTo(0));
          expect(m.date!.compareTo('2026-12-11'), lessThanOrEqualTo(0));
        }
      }
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final originals = published
            .map((c) => c.toTimetable(id: c.sourceId, mode: mode))
            .toList();
        final document = TimetableSyncDocument.legacy(
          courses: originals,
          termNames: {},
          activeYear: 2026,
          activeSemester: '2',
        );
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(jsonEncode(document.toJson())) as Map<String, dynamic>,
        ).materializeClasses();
        expect(restored, hasLength(587));
        final byId = {for (final c in originals) c.sourceId: c};
        for (final c in restored) {
          final original = byId[c.sourceId]!;
          expect(c.isValid, isTrue);
          expect(
            c.meetings.map((m) => m.toJson()).toList(),
            original.meetings.map((m) => m.toJson()).toList(),
          );
          expect(
            c.meetings.every(
              (m) =>
                  c.modeOn(m, DateTime.parse(m.date!)) == LectureMode.inPerson,
            ),
            isTrue,
          );
          expect(c.note, original.note);
          expect(c.note, contains('예약 블록'));
          expect(c.note, contains('50분'));
          expect(c.note, contains('75분'));
          expect(c.note, contains('확인 중'));
        }
      }
    },
  );
}
