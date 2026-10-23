import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Files extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('prerecorded administrative frames never become live class dates', () {
    final courses = <Map<String, dynamic>>[];
    for (final campus in ['humanities', 'naturalScience', 'icampus']) {
      final data =
          jsonDecode(
                File(
                  'assets/timetable/skku-$campus-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      courses.addAll((data['courses'] as List).cast<Map<String, dynamic>>());
    }
    final prerecorded = courses
        .where((c) => c['sourceTeachingTypeCode'] == '32')
        .toList();
    expect(prerecorded, hasLength(83));
    final ordinary = prerecorded
        .where((c) => c['sourceConcentratedType'] == 'N')
        .toList();
    expect(ordinary, hasLength(82));
    const examOnly = {
      'BUS3020-01',
      'ESM3061-41',
      'GEDB001-43',
      'GEDB002-43',
      'GEDB002-50',
      'GEDB002-57',
    };
    for (final c in ordinary) {
      final id = '${c['courseCode']}-${c['section']}';
      if (examOnly.contains(id)) {
        expect(c['scheduleEvidenceKind'], 'professorExplicitPlannedExamOnly');
        expect(c['schedules'], hasLength(2));
        expect(
          (c['schedules'] as List).every(
            (m) =>
                (m['date'] as String).startsWith('2026-10-') ||
                (m['date'] as String).startsWith('2026-12-'),
          ),
          isTrue,
        );
        continue;
      }
      expect(c['scheduleStatus'], 'unscheduled');
      expect(c['schedules'], isEmpty);
      expect(c['timetableImportSupported'], isFalse);
      expect(
        c['scheduleEvidenceKind'],
        'publishedPrerecordedWithoutLiveAttendanceClock',
      );
    }
    expect(
      prerecorded
          .where((c) => c['sourceConcentratedType'] != 'N')
          .single['scheduleStatus'],
      'unrecognized',
    );
  });
  test(
    'SKKU preserves whole search and verified dates across restore',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'skku',
      );
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'humanities': 1470, 'naturalScience': 1266, 'icampus': 47},
      );
      final courses = datasets.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2783));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1843));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(228),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(712),
      );
      for (final id in ['ICE3057-41', 'ICE3057-42', 'ICE2016-41']) {
        final c = courses.singleWhere((c) => c.codeAndSection == id);
        expect(c.hasSchedulableMeetings, isTrue);
        for (final m in c.meetings) {
          expect(m.teachingDate!.isBefore(DateTime(2026, 12, 14)), isTrue);
          if (id.startsWith('ICE3057')) {
            expect(
              m.teachingDate!.isBefore(DateTime(2026, 10, 19)) ||
                  m.teachingDate!.isAfter(DateTime(2026, 10, 25)),
              isTrue,
            );
          }
        }
      }
      final publishedSchedules = <String, List>{};
      for (final campus in ['humanities', 'naturalScience', 'icampus']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/skku-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        for (final course in raw['courses'] as List) {
          publishedSchedules[course['sourceId'] as String] =
              course['schedules'] as List;
        }
      }
      for (final c in courses) {
        if (!c.hasSchedulableMeetings) {
          expect(c.meetings, isEmpty);
          continue;
        }
        final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue);
        expect(restored.period?.toJson(), saved.period?.toJson());
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
        );
        for (final m in restored.meetings) {
          expect(m.date, isNotNull);
          expect(m.teachingDate!.weekday, m.weekday);
          final index = restored.meetings.indexOf(m);
          final published =
              (publishedSchedules[c.sourceId]![index] as Map)['deliveryMode'];
          final expectedMode = switch (published) {
            'liveOnline' => LectureMode.liveOnline,
            'inPerson' => LectureMode.inPerson,
            _ => LectureMode.inPerson,
          };
          expect(restored.modeOn(m, m.teachingDate!), expectedMode);
        }
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 8, 30),
              DateTime(2026, 9, 24),
              DateTime(2026, 9, 25),
              // ECO4006-01 explicitly publishes classes on this holiday.
              if (c.codeAndSection != 'ECO4006-01') DateTime(2026, 9, 28),
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 9),
              DateTime(2026, 12, 19),
              DateTime(2027, 1, 1),
            ],
          ),
          isEmpty,
        );
        if (c.codeAndSection == 'ECO4006-01') {
          expect(
            classOccurrences([restored], [DateTime(2026, 9, 28)]),
            hasLength(2),
          );
        }
      }
      expect(
        courses.singleWhere((c) => c.codeAndSection == 'GLD2014-01').remarks,
        contains('글로벌리더학부생 외 다른학과생 수강신청 불가'),
      );
      expect(
        courses.singleWhere((c) => c.codeAndSection == 'GEC3401-01').remarks,
        contains('한국어 능력을 요구합니다'),
      );
      final flipped = courses.singleWhere(
        (c) => c.codeAndSection == 'ECO2006-01',
      );
      expect(flipped.meetings.map((m) => m.weekday).toSet(), {
        DateTime.wednesday,
      });
      expect(flipped.meetings.map((m) => m.originalStartMinute).toSet(), {810});
      for (final id in [
        'ECO3003-01',
        'BUS3042-01',
        'BUS2003-01',
        'BUS2003-03',
        'USS2001-01',
      ]) {
        expect(
          courses
              .singleWhere((c) => c.codeAndSection == id)
              .hasSchedulableMeetings,
          isFalse,
        );
      }
    },
  );
  test(
    'SKKU profile shares campuses and keeps the published term boundary',
    () async {
      for (final id in [
        'academyinfo:0000133',
        'institution:academyinfo:0000133',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '성균관대학교',
          schoolKind: 'fourYear',
          campus: '',
        );
        expect(profile.timetableUniversity, 'skku');
        expect(profile.timetableCampus, 'humanities');
      }
      final foreign = AcademicProfile(
        universityId: 'academyinfo:0000133',
        universityName: '성균관대학교',
        schoolKind: 'fourYear',
        campus: '',
        campusId: 'academyinfo:0000029',
      );
      expect(foreign.timetableSupported, isFalse);
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final period = defaults.periodFor(2026, '2', university: 'skku');
      expect(period?.start, DateTime(2026, 8, 31));
      expect(period?.end, DateTime(2026, 12, 18));
    },
  );
}
