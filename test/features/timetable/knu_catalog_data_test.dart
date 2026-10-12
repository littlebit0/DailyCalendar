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
    'KNU registered whole scope retains source campuses and blocked exceptions',
    () async {
      final data = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'knu',
      );
      expect(
        {for (final d in data) d.campus: d.courses.length},
        {
          'daegu': 3117,
          'sangju': 497,
          'dongin': 26,
          'downtown': 2,
          'unassigned': 205,
        },
      );
      final courses = [for (final d in data) ...d.courses];
      expect(courses, hasLength(3847));
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(3847));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(3607));
      expect(
        courses.where((c) => c.scheduleStatus == 'unrecognized'),
        hasLength(240),
      );
      for (final id in [
        'TCHR0601-001',
        'TCHR0606-001',
        'TCHR0528-007',
        'CCCC0102-001',
      ]) {
        expect(courses.any((c) => c.codeAndSection == id), isFalse);
      }
      for (final c in courses) {
        if (!c.hasSchedulableMeetings) {
          expect(c.meetings, isEmpty);
          expect(c.departmentRemarks.values.join('\n'), contains('시간표 추가 불가'));
        } else {
          final saved = c.toTimetable(
            id: c.sourceId,
            mode: LectureMode.inPerson,
          );
          final restored = TimetableClass.fromJson(saved.toJson());
          expect(restored.isValid, isTrue, reason: c.sourceId);
          expect(
            restored.meetings.map((m) => m.toJson()).toList(),
            saved.meetings.map((m) => m.toJson()).toList(),
          );
        }
        expect(
          c.departmentRemarks.values.any((s) => s.contains('<br>')),
          isFalse,
        );
      }
      final aliased = courses.singleWhere(
        (c) => c.codeAndSection == 'COMP0454-001',
      );
      expect(aliased.departmentClassifications['컴퓨터학부 인공지능컴퓨팅전공'], '전공필수');
      expect(aliased.departmentClassifications['IT 첨단자율학부'], '일반선택');
      for (final label in ['융합전공', '공학전공', '연계전공']) {
        expect(courseCategory(label), CourseCategory.major);
      }
      expect(courseCategory('전공심화'), CourseCategory.advancedMajor);
    },
  );

  test(
    'KNU dated online teaching excludes exams and preserves actual moved date',
    () async {
      final data = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'knu',
      );
      final courses = [for (final d in data) ...d.courses];
      final dated = courses.where(
        (c) =>
            ['AAAA0912', 'AAAA0901'].contains(c.code) &&
            c.meetings.any((m) => m.date != null),
      );
      expect(dated, hasLength(2));
      for (final c in dated) {
        final restored = TimetableClass.fromJson(
          c.toTimetable(id: c.sourceId, mode: LectureMode.inPerson).toJson(),
        );
        for (final m in restored.meetings) {
          expect(m.date, isNotNull);
          expect(restored.modeOn(m, m.teachingDate!), LectureMode.liveOnline);
          expect(m.classroom, isEmpty);
          expect(m.date, isNot('2026-10-24'));
          expect(m.date, isNot('2026-12-12'));
        }
        if (c.code == 'AAAA0912') {
          expect(restored.meetings, hasLength(6));
          expect(restored.meetings.map((m) => m.date), contains('2026-09-23'));
        } else {
          expect(restored.meetings, hasLength(7));
        }
      }
      expect(
        courses.singleWhere((c) => c.codeAndSection == 'AAAA0908-001').meetings,
        isEmpty,
      );
    },
  );

  test(
    'KNU unified profile defaults to Daegu and excludes winter vacation',
    () async {
      const profile = AcademicProfile(
        universityId: 'institution:academyinfo:0000005',
        universityName: '경북대학교',
        schoolKind: 'fourYear',
        campusId: 'academyinfo:0000005',
      );
      expect(profile.timetableUniversity, 'knu');
      expect(profile.timetableCampus, 'daegu');
      final period = (await TimetablePeriodDefaults.load(
        bundle: _Files(),
      )).periodFor(2026, '2', university: 'knu')!;
      expect(period.start, DateTime(2026, 9, 1));
      expect(period.end, DateTime(2026, 12, 18));
    },
  );
}
