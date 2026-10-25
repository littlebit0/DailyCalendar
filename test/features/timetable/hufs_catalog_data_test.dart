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
    'HUFS bundled whole scope preserves reviewed dates, categories and restore',
    () async {
      final data = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'hufs',
      );
      expect(
        {for (final d in data) d.campus: d.courses.length},
        {'seoul': 1823, 'global': 1549},
      );
      final courses = data.expand((d) => d.courses).toList();
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(3147));
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(221),
      );
      expect(
        courses.where((c) => c.scheduleStatus == 'unscheduled'),
        hasLength(4),
      );
      for (final key in [
        'A084891-01',
        'A083681-01',
        'V900282-01',
        'U042421-27',
        'F101071-01',
        'N051083-01',
      ]) {
        final c = courses.singleWhere((c) => c.codeAndSection == key);
        expect(c.hasSchedulableMeetings, isTrue, reason: key);
        expect(c.meetings, isNotEmpty, reason: key);
      }
      var md = 0;
      for (final course in courses) {
        for (final entry in course.departmentClassifications.entries) {
          expect(
            courseCategory(entry.value),
            isNot(CourseCategory.unknown),
            reason: entry.value,
          );
          if (entry.value == '마이크로디그리(영어)') {
            md++;
            expect(
              course.categoriesFor(entry.key),
              contains(CourseCategory.microDegree),
            );
          }
          if (entry.value == '대학기초') {
            expect(
              course.categoriesFor(entry.key),
              contains(CourseCategory.foundation),
            );
            expect(
              course.categoriesFor(entry.key),
              isNot(contains(CourseCategory.major)),
            );
          }
        }
        if (!course.hasSchedulableMeetings) {
          expect(course.meetings, isEmpty, reason: course.sourceId);
          continue;
        }
        final saved = course.toTimetable(
          id: course.sourceId,
          mode: LectureMode.inPerson,
        );
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: course.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
        );
        expect(restored.period?.toJson(), saved.period?.toJson());
        expect(restored.note, saved.note);
        expect(restored.meetings.every((m) => m.date != null), isTrue);
        expect(
          classOccurrences(
            [restored],
            [
              DateTime(2026, 8, 31),
              DateTime(2026, 12, 22),
              DateTime(2026, 9, 24),
              DateTime(2026, 9, 25),
              DateTime(2026, 10, 5),
              DateTime(2026, 10, 9),
            ],
          ),
          isEmpty,
          reason: course.sourceId,
        );
      }
      expect(md, greaterThan(0));
      final actual = courses
          .singleWhere((c) => c.sourceId.endsWith('/A013048/01'))
          .toTimetable(id: 'dated', mode: LectureMode.inPerson);
      expect(classOccurrences([actual], [DateTime(2026, 9, 24)]), isEmpty);
      expect(
        classOccurrences(
          [actual],
          [DateTime(2026, 12, 10), DateTime(2026, 12, 17)],
        ),
        hasLength(2),
      );
      final clock = courses
          .singleWhere((c) => c.sourceId.endsWith('/V434073/01'))
          .meetings
          .first;
      expect(
        (clock.originalStartMinute, clock.originalEndMinute, clock.classroom),
        (1030, 1130, '2201'),
      );
      expect(
        courses
            .singleWhere((c) => c.sourceId.endsWith('/N073604/01'))
            .hasSchedulableMeetings,
        isFalse,
      );
      expect(
        courses
            .singleWhere((c) => c.sourceId.endsWith('/Q020161/10'))
            .hasSchedulableMeetings,
        isTrue,
      );
    },
  );

  test(
    'HUFS period meetings use 60-minute slots including the break',
    () async {
      // 근거: 서울 수강편람 134쪽, english_help.html (교시 시작 60분 간격, 수업 50분 + 쉬는 시간 10분)
      final data = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'hufs',
      );
      var checked = 0;
      for (final course in data.expand((d) => d.courses)) {
        final byDate = <String, List<(int, int, String)>>{};
        for (final m in course.meetings) {
          // V434073: 학교 원문이 17:10 시작을 직접 적은 강좌라 교시 슬롯 규칙에서 제외
          if (course.sourceId.endsWith('/V434073/01')) continue;
          expect(m.originalStartMinute % 60, 0, reason: course.sourceId);
          expect(m.originalEndMinute % 60, 0, reason: course.sourceId);
          checked++;
          byDate.putIfAbsent('${m.date}', () => []).add((
            m.originalStartMinute,
            m.originalEndMinute,
            m.classroom,
          ));
        }
        for (final list in byDate.values) {
          list.sort((a, b) => a.$1.compareTo(b.$1));
          for (var i = 1; i < list.length; i++) {
            final gap = list[i].$1 - list[i - 1].$2;
            // 같은 강의실이고 간격 60분 미만이면 합쳐져 있어야 한다
            expect(
              gap >= 60 || list[i].$3 != list[i - 1].$3,
              isTrue,
              reason: course.sourceId,
            );
          }
        }
      }
      expect(checked, 43820);
    },
  );

  test(
    'HUFS unified profile enables both timetable campuses and exact semester bounds',
    () async {
      for (final id in [
        'institution:academyinfo:0000192',
        'academyinfo:0000192',
      ]) {
        final profile = AcademicProfile(
          universityId: id,
          universityName: '한국외국어대학교',
          schoolKind: 'fourYear',
        );
        expect(profile.timetableUniversity, 'hufs');
        expect(profile.timetableCampus, 'seoul');
        expect(profile.timetableSupported, isFalse);
      }
      const wrong = AcademicProfile(
        universityId: 'institution:academyinfo:0000192',
        universityName: '한국외국어대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000200',
      );
      expect(wrong.timetableSupported, isFalse);
      final term = (await TimetablePeriodDefaults.load(
        bundle: _Files(),
      )).periodFor(2026, '2', university: 'hufs');
      expect(term?.start, DateTime(2026, 9, 1));
      expect(term?.end, DateTime(2026, 12, 21));
    },
  );
}
