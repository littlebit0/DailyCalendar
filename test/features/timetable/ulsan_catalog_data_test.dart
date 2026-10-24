import 'dart:convert';
import 'dart:io';

import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
import 'package:daily/features/timetable/data/timetable_sync_document.dart';
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

  test('Ulsan profile exposes the full public 2026-2 listing', () async {
    final datasets = await UniversityCatalog.load(
      bundle: _Files(),
      university: 'ulsan',
    );
    expect(
      {for (final d in datasets) d.campus: d.courses.length},
      {'main': 2046},
    );
    final profile = AcademicProfile.fromJson(
      const AcademicProfile(
        universityId: 'academyinfo:0000158',
        universityName: '울산대학교',
        schoolKind: 'fourYear',
      ).toJson(),
    );
    expect(profile.timetableUniversity, 'ulsan');
    expect(profile.timetableCampus, 'main');
    final period = (await TimetablePeriodDefaults.load(
      bundle: _Files(),
    )).periodFor(2026, '2', university: 'ulsan');
    expect(period?.start, DateTime(2026, 9, 1));
    expect(period?.end, DateTime(2026, 12, 21));
  });

  test('only clock-published honors courses get meetings', () {
    final raw =
        jsonDecode(
              File(
                'assets/timetable/ulsan-main-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final courses = UniversityDataset.fromJson(raw).courses;
    expect(courses.map((c) => c.sourceId).toSet(), hasLength(2046));
    final statuses = <String, int>{};
    for (final row in raw['courses'] as List) {
      final status = (row as Map)['scheduleStatus'] as String;
      statuses[status] = (statuses[status] ?? 0) + 1;
      if (status == 'unrecognized') {
        expect(row['schedules'], isEmpty);
        final remarks = (row['departmentRemarks'] as Map).values;
        expect(remarks, everyElement(contains('수업 시각 미확정')));
      }
      if (status == 'unscheduled') expect(row['sourceSchedule'], isEmpty);
    }
    expect(statuses, {
      'scheduled': 23,
      'unrecognized': 1706,
      'unscheduled': 317,
    });

    final approved = courses.where((c) => c.hasSchedulableMeetings).toList();
    expect(approved, hasLength(23));
    // The honors 학년별 시간표 prints 1~9교시 as 09:00~17:50 (50분 수업 + 10분
    // 쉬는 시간 = 60분 슬롯). Each period owns its break, so every meeting
    // starts and ends on the 60-minute grid from 09:00, and a same-room run of
    // consecutive periods on one day is a single block.
    for (final course in approved) {
      for (final m in course.meetings) {
        expect((m.originalStartMinute - 540) % 60, 0, reason: course.sourceId);
        expect((m.originalEndMinute - 540) % 60, 0, reason: course.sourceId);
        expect(
          m.originalEndMinute - m.originalStartMinute,
          greaterThanOrEqualTo(60),
        );
      }
      final byDay = <int, List<dynamic>>{};
      for (final m in course.meetings) {
        byDay.putIfAbsent(m.weekday, () => []).add(m);
      }
      for (final day in byDay.values) {
        day.sort(
          (a, b) => a.originalStartMinute.compareTo(b.originalStartMinute),
        );
        for (var i = 1; i < day.length; i++) {
          final gap = day[i].originalStartMinute - day[i - 1].originalEndMinute;
          final sameRoom = day[i].classroom == day[i - 1].classroom;
          expect(sameRoom && gap < 60, isFalse, reason: course.sourceId);
        }
      }
    }
    expect(approved.map((c) => c.code).toSet(), {
      'A01460', 'A01472', 'A01473', 'A01477', 'A01478', 'A01529', 'A01532', //
      'A01533', 'A01534', 'A01535', 'A01536', 'A01537', 'A01538', 'A01539',
    });
    final chemistry = approved.singleWhere(
      (c) => c.codeAndSection == 'A01535-01',
    );
    expect(chemistry.sourceSchedule, '월3,화7,8');
    expect(
      chemistry.meetings
          .map(
            (m) => [
              m.weekday,
              m.originalStartMinute,
              m.originalEndMinute,
              m.classroom,
            ],
          )
          .toList(),
      [
        [1, 660, 720, '5-201'],
        [2, 900, 1020, '5-201'],
      ],
    );
    final track = approved.singleWhere((c) => c.codeAndSection == 'A01536-01');
    expect(track.meetings.single.classroom, '5-205');

    for (final mode in [
      LectureMode.inPerson,
      LectureMode.liveOnline,
      LectureMode.video,
    ]) {
      final values = <String, TimetableSyncValue>{};
      for (final course in approved) {
        final saved = course.toTimetable(id: course.sourceId, mode: mode);
        expect(saved.isValid, isTrue);
        expect(saved.note, course.remarks);
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
  });

  test('every Ulsan offering label is placed in the official tree', () {
    final organizations =
        jsonDecode(
              File(
                'assets/timetable/organizations/ulsan.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final mapped = {
      for (final m in organizations['mappings'] as List)
        (m as Map)['sourceLabel'] as String: m,
    };
    final raw =
        jsonDecode(
              File(
                'assets/timetable/ulsan-main-2026-2.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final labels = {
      for (final c in raw['courses'] as List)
        ...((c as Map)['departments'] as List).cast<String>(),
    };
    expect(labels, hasLength(182));
    expect(mapped.keys.toSet(), labels);
    for (final m in mapped.values) {
      expect(m['college'], isNotNull);
      expect(m['sourceUrl'], startsWith('https://'));
      expect(m['evidence'], isNotEmpty);
    }
  });
}
