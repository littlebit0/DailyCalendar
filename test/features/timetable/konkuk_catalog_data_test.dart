import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:daily/features/timetable/domain/university_course.dart';
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

// 정규학기 교시별 시간 안내, https://www.konkuk.ac.kr/konkuk/2367/subview.do
const _seoulClock = {
  1: (540, 570), 2: (570, 600), 3: (600, 630), 4: (630, 660), //
  5: (660, 690), 6: (690, 720), 7: (720, 750), 8: (750, 780),
  9: (780, 810), 10: (810, 840), 11: (840, 870), 12: (870, 900),
  13: (900, 930), 14: (930, 960), 15: (960, 990), 16: (990, 1020),
  17: (1020, 1050), 18: (1050, 1080), 19: (1095, 1140), 20: (1140, 1185),
  21: (1185, 1230), 22: (1230, 1275), 23: (1275, 1320),
};
const _days = '월화수목금토일';

List<(int, int, int)> _expected(UniversityCourse course) {
  final seoul = course.campus == 'seoul';
  final pattern = seoul
      ? RegExp(r'([월화수목금토일])(\d{2})(?:-(\d{2}))?')
      : RegExp(r'([월화수목금토일])(\d{2})(\d{2})-(\d{2})(\d{2})');
  return [
    for (final block in course.sourceSchedule.split(','))
      if (pattern.firstMatch(block.trim()) case final m?)
        seoul
            ? (
                _days.indexOf(m[1]!) + 1,
                _seoulClock[int.parse(m[2]!)]!.$1,
                _seoulClock[int.parse(m[3] ?? m[2]!)]!.$2,
              )
            : (
                _days.indexOf(m[1]!) + 1,
                int.parse(m[2]!) * 60 + int.parse(m[3]!),
                int.parse(m[4]!) * 60 + int.parse(m[5]!),
              ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Konkuk profile exposes Seoul and GLOCAL published timetables',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'konkuk',
      );
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'seoul': 2432, 'glocal': 1449},
      );
      for (final (campus, expected) in [
        ('academyinfo:0000052', 'seoul'),
        ('academyinfo:0000053', 'glocal'),
      ]) {
        final profile = AcademicProfile.fromJson(
          AcademicProfile(
            universityId: 'institution:academyinfo:0000052',
            universityName: '건국대학교',
            schoolKind: 'fourYear',
            campusId: campus,
          ).toJson(),
        );
        expect(profile.timetableUniversity, 'konkuk');
        expect(profile.timetableCampus, expected);
      }
      final period = (await TimetablePeriodDefaults.load(
        bundle: _Files(),
      )).periodFor(2026, '2', university: 'konkuk');
      expect(period?.start, DateTime(2026, 8, 31));
      expect(period?.end, DateTime(2026, 12, 18));
    },
  );

  test(
    'Konkuk meetings follow the published clocks and survive Drive JSON',
    () {
      final courses = <UniversityCourse>[];
      for (final campus in ['seoul', 'glocal']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/konkuk-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        courses.addAll(UniversityDataset.fromJson(raw).courses);
      }
      final byStatus = <String, int>{};
      for (final c in courses) {
        byStatus.update(c.scheduleStatus!, (v) => v + 1, ifAbsent: () => 1);
      }
      expect(byStatus, {
        'scheduled': 3647,
        'unscheduled': 137,
        'unrecognized': 97,
      });
      // Held: weeks-only intensive GLOCAL rows and Seoul's literal period 00.
      for (final c in courses.where(
        (c) => c.scheduleStatus == 'unrecognized',
      )) {
        expect(c.meetings, isEmpty);
        expect(
          c.campus == 'glocal'
              ? c.remarks.contains('집중이수제: ')
              : c.sourceSchedule.contains('00('),
          isTrue,
          reason: c.sourceId,
        );
      }
      final approved = courses.where((c) => c.hasSchedulableMeetings).toList();
      for (final c in approved) {
        expect(c.remarks.contains('집중이수제: '), isFalse);
        expect(
          [
            for (final m in c.meetings)
              (m.weekday, m.originalStartMinute, m.originalEndMinute),
          ],
          _expected(c),
          reason: c.sourceId,
        );
      }
      expect(approved.expand((c) => c.meetings), hasLength(4844));
      for (final mode in [
        LectureMode.inPerson,
        LectureMode.liveOnline,
        LectureMode.video,
      ]) {
        final values = <String, TimetableSyncValue>{};
        for (final course in approved) {
          final saved = course.toTimetable(id: course.sourceId, mode: mode);
          expect(saved.isValid, isTrue);
          final key = timetableCourseSyncKey(saved);
          values[key] = TimetableSyncValue(
            {...saved.toJson(), 'id': key},
            DateTime.utc(2026, 10, 23),
            'test',
          );
        }
        final restored = TimetableSyncDocument.fromJson(
          jsonDecode(
                jsonEncode(
                  TimetableSyncDocument.records(
                    courses: values,
                    schemaVersion: 2,
                  ).toJson(),
                ),
              )
              as Map<String, dynamic>,
        );
        expect(restored.courses.keys.toSet(), values.keys.toSet());
        for (final entry in restored.courses.entries) {
          expect(entry.value.value, values[entry.key]!.value);
        }
      }
    },
  );
}
