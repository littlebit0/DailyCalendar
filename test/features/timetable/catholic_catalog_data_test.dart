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
  test(
    'Catholic integrated profile loads catalog without inventing campus',
    () async {
      final datasets = await UniversityCatalog.load(
        bundle: _Files(),
        university: 'catholic',
      );
      expect(
        {for (final d in datasets) d.campus: d.courses.length},
        {'songsim': 1086, 'unknown': 373},
      );
      expect(
        datasets.expand((d) => d.courses).map((c) => c.sourceId).toSet(),
        hasLength(1459),
      );
      for (final id in [
        'institution:academyinfo:0000046',
        'academyinfo:0000046',
        'academyinfo:0000048',
        'academyinfo:0000049',
      ]) {
        for (final campus in [
          null,
          'academyinfo:0000046',
          'academyinfo:0000048',
          'academyinfo:0000049',
        ]) {
          final profile = AcademicProfile(
            universityId: id,
            universityName: '가톨릭대학교',
            schoolKind: 'fourYear',
            campusId: campus,
          );
          final restored = AcademicProfile.fromJson(profile.toJson());
          expect(restored.timetableUniversity, 'catholic');
          expect(restored.timetableCampus, 'songsim');
        }
      }
      expect(
        const AcademicProfile(
          universityId: 'institution:academyinfo:0000046',
          universityName: '가톨릭대학교',
          schoolKind: 'fourYear',
          campusId: 'academyinfo:0000117',
        ).timetableSupported,
        isFalse,
      );
      final defaults = await TimetablePeriodDefaults.load(bundle: _Files());
      final period = defaults.periodFor(2026, '2', university: 'catholic');
      expect(period?.start, DateTime(2026, 8, 31));
      expect(period?.end, DateTime(2026, 12, 18));
    },
  );

  test(
    'published regular plans preserve user mode, restrictions and date boundaries',
    () {
      final rawCourses = <dynamic>[];
      final datasets = <UniversityDataset>[];
      for (final campus in ['songsim', 'unknown']) {
        final raw =
            jsonDecode(
                  File(
                    'assets/timetable/catholic-$campus-2026-2.json',
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        rawCourses.addAll(raw['courses'] as List);
        final dataset = UniversityDataset.fromJson(raw);
        expect(dataset.courses.every((c) => c.campus == campus), isTrue);
        datasets.add(dataset);
      }
      final courses = datasets.expand((d) => d.courses).toList();
      expect(courses.map((c) => c.sourceId).toSet(), hasLength(1459));
      expect(courses.where((c) => c.credits != null), hasLength(1052));
      expect(courses.where((c) => c.hasSchedulableMeetings), hasLength(1024));
      expect(courses.expand((c) => c.meetings), hasLength(21899));
      for (final mode in LectureMode.values) {
        for (final course in courses.where((c) => c.hasSchedulableMeetings)) {
          final saved = course.toTimetable(id: course.sourceId, mode: mode);
          final restored = TimetableClass.fromJson(saved.toJson());
          expect(restored.toJson(), saved.toJson());
          expect(restored.note, course.remarks);
          for (final meeting in restored.meetings) {
            expect(restored.modeOn(meeting, meeting.teachingDate!), mode);
            expect(meeting.teachingDate!.weekday, meeting.weekday);
            expect(meeting.originalStartMinute % 60, 0);
            expect(meeting.originalEndMinute % 60, 50);
            if (meeting.date == '2026-09-09') {
              expect(
                meeting.originalEndMinute <= 590 ||
                    meeting.originalStartMinute >= 720,
                isTrue,
              );
            }
          }
          expect(
            classOccurrences(
              [restored],
              [
                DateTime(2026, 8, 30),
                DateTime(2026, 9, 24),
                DateTime(2026, 9, 25),
                DateTime(2026, 10, 5),
                DateTime(2026, 10, 9),
                DateTime(2026, 12, 19),
              ],
            ),
            isEmpty,
          );
        }
      }
      for (final id in ['00097-01', '05642-01', '05911-01', '06539-01']) {
        final course = courses.singleWhere((c) => c.codeAndSection == id);
        expect(course.meetings.every((m) => m.classroom.isEmpty), isTrue);
        expect(course.remarks, contains('강의실은 학교 공시 자료에 미표기'));
      }
      for (final course in rawCourses) {
        expect(course['sourceEducation']['actualAttendanceConfirmed'], isFalse);
        for (final meeting in course['schedules'] as List) {
          expect(meeting.containsKey('deliveryMode'), isFalse);
        }
      }
    },
  );
}
