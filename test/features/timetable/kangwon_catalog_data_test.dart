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
    'Kangwon registered whole catalog retains five campus filters and safe source meetings',
    () async {
      final data = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'kangwon',
      );
      expect(
        {for (final d in data) d.campus: d.courses.length},
        {
          'chuncheon': 2902,
          'gangneung': 1293,
          'wonju': 500,
          'samcheok': 670,
          'dogye': 396,
        },
      );
      final courses = [for (final d in data) ...d.courses];
      expect(courses, hasLength(5761));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(5761));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(5108));
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(653),
      );
      for (final c in courses.where((c) => c.hasSchedulableMeetings)) {
        final saved = c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson);
        final restored = TimetableClass.fromJson(saved.toJson());
        expect(restored.isValid, isTrue, reason: c.sourceId);
        expect(
          restored.meetings.map((m) => m.toJson()).toList(),
          saved.meetings.map((m) => m.toJson()).toList(),
        );
        expect(restored.period?.toJson(), saved.period?.toJson());
      }
      final service = courses.where(
        (c) => c.code == '14207025' && c.hasSchedulableMeetings,
      );
      expect(service, hasLength(135));
      for (final c in service) {
        expect(
          c.meetings.single.endMinute - c.meetings.single.startMinute,
          120,
        );
        expect(c.meetings.single.classroom, isEmpty);
        expect(c.departmentRemarks.values.join('\n'), contains('봉사기관:'));
        expect(c.period!.contains(DateTime(2026, 9, 13)), isFalse);
        expect(c.period!.contains(DateTime(2026, 12, 5)), isFalse);
      }
      expect(courseCategory('글로컬교양'), CourseCategory.generalEducation);
    },
  );

  test(
    'Kangwon major offering labels all belong to an official college',
    () async {
      final data = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'kangwon',
      );
      final raw = <String>{};
      final orphans = <String>{};
      for (final d in data) {
        for (final c in d.courses) {
          for (final l in c.departments) {
            if (c.isMajorForSourceDepartment(l) &&
                !c.offeringOrganizations.any((o) => o.sourceLabel == l)) {
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
    'Kangwon unified profile selects actual campus defaults and excludes automatic makeup recurrence',
    () async {
      for (final entry in {
        'academyinfo:0000003': 'chuncheon',
        'academyinfo:0000004': 'samcheok',
        'academyinfo:0003363': 'gangneung',
        'academyinfo:0003364': 'wonju',
      }.entries) {
        final profile = AcademicProfile(
          universityId: 'institution:academyinfo:0000003',
          universityName: '강원대학교',
          schoolKind: 'fourYear',
          campusId: entry.key,
        );
        expect(profile.timetableUniversity, 'kangwon');
        expect(profile.timetableCampus, entry.value);
      }
      const wrongCampus = AcademicProfile(
        universityId: 'institution:academyinfo:0000003',
        universityName: '강원대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000117',
      );
      expect(wrongCampus.timetableCampus, isNull);
      final period = (await TimetablePeriodDefaults.load(
        bundle: _Files(),
      )).periodFor(2026, '2', university: 'kangwon')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 14));
      expect(period.contains(DateTime(2026, 12, 15)), isFalse);
      expect(period.contains(DateTime(2026, 12, 21)), isFalse);
    },
  );
}
