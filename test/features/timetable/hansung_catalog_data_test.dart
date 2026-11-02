import 'dart:convert';
import 'dart:io';
import 'package:daily/core/academic/academic_profile.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/data/timetable_period_defaults.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Hansung full metadata preserves verified clocks and blocks unresolved operations',
    () async {
      final data = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'hansung',
      )).single;
      final courses = data.courses;
      expect(courses, hasLength(1489));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(1489));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1139));
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(240),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(110),
      );
      for (final key in [
        'CTS0001-A',
        'T011009-A',
        'T011009-N',
        'R01G012-A',
        'R01G012-N',
        'P020116-A',
        'O040015-A',
        'T010010-7',
        'T010010-8',
        'T010010-A',
        'T010010-N',
        'R010052-A',
        'R010052-N',
        'R01C011-A',
        'R01C011-N',
        'R019003-7',
        'R019003-9',
        'R019003-A',
        'V023003-7',
        'V020011-N',
        'GEN0637-A',
        'GEN0787-0',
        'GEN0636-N',
        'GEN0844-A',
        'GEN0926-N',
        'V020017-N',
        'V020007-D',
        'GEN1045-7',
        'GEN0787-9',
        'GEN1046-A',
        'P010182-A',
      ]) {
        final c = courses.singleWhere((c) => c.codeAndSection == key);
        expect(c.hasSchedulableMeetings, isTrue, reason: key);
      }
      final night = courses.singleWhere((c) => c.codeAndSection == 'P012012-N');
      expect(
        night.meetings
            .map((m) => (m.weekday, m.originalStartMinute, m.originalEndMinute))
            .toSet(),
        {(1, 1080, 1165), (4, 1165, 1245)},
      );
      expect(night.meetings.last.classroom, '상상관503');
      expect(night.remarks, contains('계획서 수강대상:'));
      expect(
        courses.singleWhere((c) => c.codeAndSection == 'GEN0925-@').section,
        '@',
      );
      for (final key in ['P010143-A', 'P017022-Z']) {
        final course = courses.singleWhere((c) => c.codeAndSection == key);
        expect(course.meetings, isEmpty, reason: key);
        expect(course.period, isNull, reason: key);
        expect(course.sourceSchedule, isNotEmpty, reason: key);
      }
      for (final c in courses) {
        for (final raw in c.departmentClassifications.values) {
          expect(
            courseCategory(raw),
            isNot(CourseCategory.unknown),
            reason: raw,
          );
        }
        if (!c.hasSchedulableMeetings) continue;
        final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: c.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
          reason: c.sourceId,
        );
        expect(restored.period?.toJson(), saved.period?.toJson());
        expect(restored.meetings.every((m) => m.date != null), isTrue);
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 9, 24),
              DateTime(2026, 9, 25),
              DateTime(2026, 9, 26),
              DateTime(2026, 10, 3),
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 9),
            ],
          ),
          isEmpty,
          reason: c.sourceId,
        );
      }
    },
  );

  test(
    'Hansung class segments use break-inclusive slots from the registration guide table',
    () {
      // 수강신청 안내 "강의시간 안내": 월·수·목 75분(주간 휴식 15분, 야간 10·5분),
      // 화·금 50분(주간 휴식 10분, 야간 5분). 슬롯 = 시작부터 다음 교시 시작 직전.
      // 마지막 교시는 같은 요일 그룹의 일반 슬롯(90분/60분)을 쓴다.
      const slots75 = {
        540: 630,
        630: 720,
        720: 810,
        810: 900,
        900: 990,
        990: 1080,
        1080: 1165,
        1165: 1245,
        1245: 1335,
      };
      const slots50 = {
        540: 600,
        600: 660,
        660: 720,
        720: 780,
        780: 840,
        840: 900,
        900: 960,
        960: 1020,
        1020: 1080,
        1080: 1135,
        1135: 1190,
        1190: 1245,
        1245: 1300,
        1300: 1360,
      };
      final data =
          jsonDecode(
                File(
                  'assets/timetable/hansung-main-2026-2.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      var segments = 0;
      for (final course in data['courses'] as List) {
        final seen = <String>{};
        final list = <Map<String, dynamic>>[];
        for (final raw in course['schedules'] as List) {
          final s = raw as Map<String, dynamic>;
          segments++;
          final slots = switch (s['weekday'] as int) {
            1 || 3 || 4 => slots75,
            2 || 5 => slots50,
            _ => null,
          };
          if (slots != null) {
            final start = s['startMinute'] as int;
            final end = s['endMinute'] as int;
            expect(slots.containsKey(start), isTrue, reason: '$s');
            expect(slots.containsValue(end), isTrue, reason: '$s');
            expect(end > start, isTrue, reason: '$s');
          }
          expect(
            seen.add('${s['date']}/${s['classroom']}/${s['startMinute']}'),
            isTrue,
          );
          list.add(s);
        }
        // 같은 날짜·강의실 구간은 60분 미만 간격이면 하나로 합쳐져 있어야 한다.
        list.sort(
          (a, b) =>
              '${a['date']}${a['classroom']}'.compareTo(
                    '${b['date']}${b['classroom']}',
                  ) !=
                  0
              ? '${a['date']}${a['classroom']}'.compareTo(
                  '${b['date']}${b['classroom']}',
                )
              : (a['startMinute'] as int).compareTo(b['startMinute'] as int),
        );
        for (var i = 1; i < list.length; i++) {
          final a = list[i - 1];
          final b = list[i];
          if (a['date'] == b['date'] && a['classroom'] == b['classroom']) {
            expect(
              (b['startMinute'] as int) - (a['endMinute'] as int) >= 60,
              isTrue,
              reason: '${course['sourceId']} ${a['date']}',
            );
          }
        }
      }
      expect(segments, 16589);
    },
  );
  test(
    'Hansung profile and course period keep regular classes out of makeup and vacation',
    () async {
      for (final id in [
        'institution:academyinfo:0000200',
        'academyinfo:0000200',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '한성대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'hansung');
        expect(profile.timetableCampus, 'main');
      }
      const wrongCampus = AcademicProfile(
        universityId: 'institution:academyinfo:0000200',
        universityName: '한성대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000036',
      );
      expect(wrongCampus.timetableCampus, isNull);
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final term = defaults.periodFor(2026, '2', university: 'hansung');
      expect(term?.start, DateTime(2026, 8, 31));
      expect(term?.end, DateTime(2026, 12, 19));
      final data = (await UniversityCatalog.load(
        bundle: _Files(),
        university: 'hansung',
      )).single;
      final night = data.courses
          .singleWhere((c) => c.codeAndSection == 'P012012-N')
          .toTimetable(id: 'night', mode: LectureMode.inPerson);
      expect(
        classOccurrences(
          [night],
          [DateTime(2026, 11, 30)],
          periodFor: (_) => term,
        ),
        hasLength(1),
      );
      expect(
        classOccurrences(
          [night],
          [DateTime(2026, 12, 7)],
          periodFor: (_) => term,
        ),
        isEmpty,
      );
      expect(
        classOccurrences(
          [night],
          [DateTime(2026, 8, 24)],
          periodFor: (_) => term,
        ),
        isEmpty,
      );
      expect(
        classOccurrences(
          [night],
          [DateTime(2026, 12, 21)],
          periodFor: (_) => term,
        ),
        isEmpty,
      );
    },
  );
}
