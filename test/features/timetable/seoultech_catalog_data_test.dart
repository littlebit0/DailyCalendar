import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
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
    'Seoultech full current scope preserves dated operations, unknown clocks and actual classroom',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'seoultech',
      )).single;
      final courses = data.courses;
      expect(courses, hasLength(1990));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(1990));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1728));
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(250),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(12),
      );
      final ordinary = courses.singleWhere(
        (c) => c.codeAndSection == '111006-11001',
      );
      expect(ordinary.meetings.single.startMinute, 660);
      expect(ordinary.meetings.single.endMinute, 840);
      expect(ordinary.meetings.single.classroom, '다산관-310');
      expect(
        courses.singleWhere((c) => c.codeAndSection == '101068-11016').meetings,
        isEmpty,
      );
      expect(
        courses.where((c) => c.meetings.any((m) => m.date != null)),
        hasLength(197),
      );
      // 학사관리 규정 별표 1: 교시는 정시에 시작하는 60분 슬롯(50분 수업+10분
      // 쉬는 시간). 요일 반복 구간은 모두 슬롯 경계에 맞고, 같은 요일·강의실에서
      // 60분 미만 간격의 구간은 하나로 합쳐져 있다. 시계 시각 원문(날짜 있음)은 제외.
      for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
        final weekly = c.meetings.where((m) => m.date == null).toList();
        for (final m in weekly) {
          expect(m.startMinute % 60, 0, reason: c.sourceId);
          expect(m.endMinute % 60, 0, reason: c.sourceId);
          expect(m.endMinute, greaterThan(m.startMinute), reason: c.sourceId);
          for (final o in weekly.where((o) => !identical(o, m))) {
            if (o.weekday == m.weekday && o.classroom == m.classroom) {
              expect(
                o.startMinute - m.endMinute,
                isNot(inInclusiveRange(0, 59)),
                reason: c.sourceId,
              );
            }
          }
        }
      }
      for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
        final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: c.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
          reason: c.sourceId,
        );
      }
    },
  );
  test(
    'Seoultech profile and regular period exclude conditional makeup week',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000036',
        universityName: '서울과학기술대학교',
        schoolKind: 'fourYear',
      );
      expect(profile.timetableUniversity, 'seoultech');
      expect(profile.timetableCampus, 'main');
      final period = await TimetablePeriodDefaults.load(bundle: _Files());
      final term = period.periodFor(2026, '2', university: 'seoultech');
      expect(term?.start, DateTime(2026, 9, 1));
      expect(term?.end, DateTime(2026, 12, 14));
    },
  );
}
