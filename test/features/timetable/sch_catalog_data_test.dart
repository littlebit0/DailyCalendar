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
  test(
    'SCH retains current search and published reservation ranges after restore',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'sch',
      );
      final courses = datasets.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(2598));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(2127));
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(235),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(236),
      );
      expect(courses.expand((c) => c.meetings), hasLength(35380));
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
          expect(m.teachingDate!.weekday, m.weekday);
          expect(m.classroom, isNotEmpty);
          expect(m.startMinute % 30, 0);
          expect(m.endMinute % 30, 0);
        }
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 9, 24),
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 19),
              DateTime(2026, 10, 20),
              DateTime(2026, 12, 7),
              DateTime(2026, 12, 14),
              DateTime(2027, 1, 4),
            ],
          ),
          isEmpty,
        );
      }
      // 2023 요람 65쪽 수업시간: 교시 슬롯(50분 교시 60분, 75분 블록 90분)에
      // 쉬는 시간을 포함하고, 같은 날 같은 강의실의 이어지는 교시는 한 구간이다.
      for (final c in courses) {
        final rooms = <String, int>{};
        for (final m in c.meetings) {
          final length = m.originalEndMinute - m.originalStartMinute;
          expect(length, isNot(50), reason: c.sourceId);
          expect(length, isNot(75), reason: c.sourceId);
          final key = '${m.date}/${m.classroom}';
          final previousEnd = rooms[key];
          if (previousEnd != null) {
            expect(
              m.originalStartMinute - previousEnd,
              greaterThanOrEqualTo(60),
              reason: '${c.sourceId} $key',
            );
          }
          rooms[key] = m.originalEndMinute;
        }
      }
      final merged = courses.singleWhere((c) => c.code == '10008');
      expect(
        merged.meetings
            .where((m) => m.date == '2026-09-02')
            .map((m) => [m.originalStartMinute, m.originalEndMinute]),
        [
          [600, 720],
        ],
      );
      final ai = courses.singleWhere((c) => c.code == '12797');
      expect(ai.meetings.map((m) => m.originalStartMinute).toSet(), {1020});
      expect(ai.meetings.map((m) => m.originalEndMinute).toSet(), {1080});
      final changed = courses.singleWhere((c) => c.code == '10640');
      expect(changed.meetings.map((m) => m.originalEndMinute).toSet(), {720});
      for (final code in ['10654', '10655']) {
        final course = courses.singleWhere((c) => c.code == code);
        expect(course.hasSchedulableMeetings, isTrue);
        expect(course.meetings.map((m) => m.originalStartMinute).toSet(), {
          1020,
        });
        expect(course.meetings.map((m) => m.originalEndMinute).toSet(), {1080});
        expect(course.remarks, contains('개별 배정 미확인'));
        final video = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.video,
        );
        expect(
          video.meetings.every(
            (m) => video.modeOn(m, m.teachingDate!) == LectureMode.video,
          ),
          isTrue,
        );
      }
    },
  );

  test(
    'SCH major labels all reach an official college in the course page',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'sch',
      );
      final raw = <String>{};
      final orphans = <String>{};
      for (final d in datasets) {
        // A raw label naming a college shown on the same campus joins that
        // college's own choice in the course page.
        final titles = {
          for (final c in d.courses)
            for (final o in c.offeringOrganizations)
              if ((o.college ?? o.group) case final String title) title,
        };
        for (final c in d.courses) {
          for (final l in c.departments) {
            if (c.isMajorForSourceDepartment(l) &&
                !c.offeringOrganizations.any((o) => o.sourceLabel == l) &&
                !titles.contains(l)) {
              raw.add('${d.campus} $l');
            }
          }
          for (final o in c.offeringOrganizations) {
            if (o.department != null &&
                o.college == null &&
                o.group == null &&
                c.isMajorForOrganization(o)) {
              orphans.add('${d.campus} ${o.department}');
            }
          }
        }
      }
      expect(raw, isEmpty);
      expect(orphans, isEmpty);
    },
  );

  test(
    'SCH profile rejects foreign campuses and retains outer semester bounds',
    () async {
      for (final id in [
        'academyinfo:0000142',
        'institution:academyinfo:0000142',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '순천향대학교',
          schoolKind: 'fourYear',
          campus: '',
        );
        expect(profile.timetableUniversity, 'sch');
        expect(profile.timetableCampus, 'unknown');
        expect(
          AcademicProfile(
            universityId: id,
            universityName: '순천향대학교',
            schoolKind: 'fourYear',
            campus: '',
            campusId: 'academyinfo:0000029',
          ).timetableSupported,
          isFalse,
        );
      }
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final period = defaults.periodFor(2026, '2', university: 'sch');
      expect(period?.start, DateTime(2026, 8, 31));
      expect(period?.end, DateTime(2026, 12, 18));
    },
  );
}
