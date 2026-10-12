import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

const folder =
    'work/university-research/catalog-f/mju/current-ict-algorithm-direct-weekly-offering-v30-20261009';
dynamic read(String path) {
  final actual = path;
  final data = jsonDecode(File(actual).readAsStringSync());
  if (data is Map) {
    for (final c in data['courses'] as List? ?? []) {
      if (c['metadata']?.containsKey('researchOnly') == true) {
        c['metadata']['researchOnly'] = false;
      }
    }
  }
  return data;
}

const literalDates = [
  '2026-09-02',
  '2026-09-09',
  '2026-09-14',
  '2026-09-16',
  '2026-09-21',
  '2026-09-23',
  '2026-09-28',
  '2026-09-30',
  '2026-10-07',
  '2026-10-12',
  '2026-10-14',
  '2026-10-19',
  '2026-10-28',
  '2026-11-02',
  '2026-11-04',
  '2026-11-09',
  '2026-11-11',
  '2026-11-16',
  '2026-11-18',
  '2026-11-23',
  '2026-11-25',
  '2026-11-30',
  '2026-12-02',
  '2026-12-07',
];
void main() {
  test(
    'MJU exact current5983 one24,prior241/28/496 whole,full242/29/520 threeModeDrive',
    () {
      final proof = read(
        '$folder/independent-native-clock-calendar-whole-proof.json',
      );
      for (final x in proof['sourceInputs'] as List) {
        expect(
          sha256.convert(File(x['path']).readAsBytesSync()).toString(),
          x['sha256'],
        );
      }
      final parts = [
        read(
          'work/university-research/catalog-f/mju/natural-reference-v3-fixture-derivative-20261009/baseline-humanities.json',
        ),
        read(
          'work/university-research/catalog-f/mju/current-natural-reference-v3-20261009/mju-natural-2026-2.natural-reference-v3.json',
        ),
        read('$folder/mju-unknown-2026-2.algorithm-weekly-v30.json'),
      ];
      final oldUnknown = read('$folder/prior-v27-unknown-whole-archive.json');
      expect(
        (parts[2]['courses'] as List).sublist(0, 73),
        oldUnknown['courses'],
      );
      final raw = parts.expand((p) => p['courses'] as List).toList();
      expect(raw, hasLength(242));
      expect(raw.map((c) => c['sourceId']).toSet(), hasLength(242));
      final added = raw.singleWhere(
        (c) => c['sourceId'] == 'mju/unknown/2026-2/5983',
      );
      expect(added['courseName'], '알고리즘');
      expect(added['professor'], '이강선');
      expect(added['courseCode'], '');
      expect(added['section'], '');
      expect(added['campus'], 'unknown');
      final source = read('$folder/current-notice-whitelist-education.json');
      expect(
        source['nativeEducationalBody'],
        contains('강의시간 : 월, 수 13:30-14:45'),
      );
      expect(source['nativeEducationalBody'], contains('강의실 : MCC관 S10311'));
      expect(source['nativeOffering']['academicTerm'], '2026학년도 2학기');
      final meetings = added['schedules'] as List;
      expect(meetings.map((m) => m['date']).toList(), literalDates);
      for (final m in meetings) {
        expect(m['weekday'], DateTime.parse(m['date']).weekday);
        expect([1, 3], contains(m['weekday']));
        expect(m['startMinute'], 810);
        expect(m['endMinute'], 885);
        expect(m['originalStartMinute'], 810);
        expect(m['originalEndMinute'], 885);
        expect(m['classroom'], 'MCC관 S10311');
        expect(m.containsKey('deliveryMode'), false);
      }
      final courses = parts
          .expand((p) => UniversityDataset.fromJson(p).courses)
          .toList();
      expect(courses, hasLength(242));
      final plans = courses.where((c) => c.meetings.isNotEmpty).toList();
      expect(plans, hasLength(29));
      expect(plans.fold<int>(0, (n, c) => n + c.meetings.length), 520);
      final priorPlans = plans
          .where((c) => c.sourceId != 'mju/unknown/2026-2/5983')
          .toList();
      expect(priorPlans, hasLength(28));
      expect(priorPlans.fold<int>(0, (n, c) => n + c.meetings.length), 496);
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final classes = plans
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
        final expected = {for (final c in classes) c.sourceId: c};
        expect(restored, hasLength(29));
        expect(restored.map((c) => c.sourceId).toSet(), expected.keys.toSet());
        for (final c in restored) {
          expect(
            c.toJson()..remove('id'),
            expected[c.sourceId]!.toJson()..remove('id'),
          );
          expect(c.isValid, true);
          for (final m in c.meetings) {
            expect(c.modeOn(m, DateTime.parse(m.date!)), mode);
          }
        }
      }
    },
  );
}
