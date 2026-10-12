import 'dart:convert';
import 'dart:io';

import 'package:daily/features/timetable/data/course_organization_directory.dart';
import 'package:daily/features/timetable/data/university_catalog.dart';
import 'package:daily/features/timetable/domain/timetable.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

CourseOrganizationDirectory _organizations(String school) =>
    CourseOrganizationDirectory.fromJson(
      _read('assets/timetable/organizations/$school.json'),
    );

void main() {
  test('KAIST MSE imports only official undergraduate cells without invented sections', () {
    final raw = _read('assets/timetable/kaist-main-2026-2.json');
    final rows = (raw['courses'] as List).cast<Map<String, dynamic>>();
    final additions = rows.where((row) => '${row['sourceId']}'.contains('/mse-389571/')).toList();
    expect(additions, hasLength(16));
    final directory = _organizations('kaist');
    for (final row in additions) {
      expect(row['section'], isEmpty);
      expect((row['sourceLocator'] as Map)['legend'], 'peach = 학부과목');
      final converted = directory.apply(row);
      expect((converted['offeringOrganizations'] as List).single['college'], '공과대학');
    }
    final basic = additions.where((row) => row['classification'] == '기초');
    expect(basic, hasLength(2));
    final special = additions.where((row) => '${row['courseCode']}'.startsWith('49900'));
    expect(special, hasLength(2));
    expect(special.every((row) => row['credits'] == null && row['classification'] == ''), isTrue);
    expect(additions.expand((row) => row['schedules'] as List).every((m) => !(m as Map).containsKey('date')), isTrue);
  });

  test('Eulji undergraduate additions retain source gaps and dual routes', () {
    final raw = _read('assets/timetable/eulji-seongnam-2026-2.json');
    final sourceRows = (raw['courses'] as List).cast<Map<String, dynamic>>();
    final additions = sourceRows.where((row) => row.containsKey('sourceLocator'));
    expect(sourceRows, hasLength(260));
    expect(additions, hasLength(200));
    expect(additions.where((row) => '${row['sourceGrade']}'.contains('대학원')), isEmpty);
    final directory = _organizations('eulji');
    var visualDesignCount = 0;
    for (final row in additions) {
      expect(row['sourceUrl'], startsWith('https://'));
      expect((row['sourceLocator'] as Map), isNotEmpty);
      final routes = (directory.apply(row)['offeringOrganizations'] as List)
          .cast<Map<String, dynamic>>();
      if ((row['departments'] as List).contains('시각디자인전공')) {
        visualDesignCount++;
        expect(routes.map((unit) => unit['college'] ?? unit['group']).toSet(),
            containsAll(['미래융합대학', '전공통합학부']));
      }
    }
    expect(visualDesignCount, greaterThan(0));
    final dataset = UniversityDataset.fromJson(raw, organizationDirectory: directory);
    for (final course in dataset.courses) {
      expect(course.meetings.every((m) => m.endMinute % 30 == 0), isTrue);
    }
  });

  test('JBNU whole public query has weekly slots and safe unresolved clocks', () {
    final paths = (jsonDecode(File('assets/timetable/catalog.json').readAsStringSync())
        as List).cast<String>().where((p) => p.startsWith('assets/timetable/jbnu-'));
    final identities = <String>{};
    var newRows = 0;
    var weekly = 0;
    var held = 0;
    final directory = _organizations('jbnu');
    for (final path in paths) {
      final dataset = UniversityDataset.fromJson(_read(path), organizationDirectory: directory);
      final rawRows = (_read(path)['courses'] as List).cast<Map<String, dynamic>>();
      for (var i = 0; i < rawRows.length; i++) {
        final row = rawRows[i];
        final course = dataset.courses[i];
        expect(identities.add(course.sourceId), isTrue);
        if (row['clockSourcePage'] != 16) continue; // Original dated medical records.
        newRows++;
        expect(course.code, (row['publicEducationRow'] as Map)['STDTR_NO']);
        expect(course.meetings.every((m) => m.date == null), isTrue);
        if (course.hasSchedulableMeetings) {
          weekly++;
          expect(course.meetings.every((m) => m.startMinute % 30 == 0 && m.endMinute % 30 == 0), isTrue);
          final restored = TimetableClass.fromJson(
            course.toTimetable(id: course.sourceId, mode: LectureMode.inPerson).toJson(),
          );
          expect(classOccurrences([restored], [DateTime(2026, 8, 31), DateTime(2026, 12, 23)]), isEmpty);
        } else {
          held++;
          expect(course.meetings, isEmpty);
          expect(row['sourceOperatingHolds'], isNotEmpty);
        }
      }
    }
    expect(identities, hasLength(3571));
    expect(newRows, 3538);
    expect(weekly, 3276);
    expect(held, 262);
  });

  test('ICCU native guide offerings and KMOU weekly additions remain distinct', () {
    final iccu = UniversityDataset.fromJson(_read('assets/timetable/iccu-songdo-2026-2.json'));
    expect(iccu.courses, hasLength(265));
    expect(iccu.courses.map((c) => c.sourceId).toSet(), hasLength(265));
    final kmou = UniversityDataset.fromJson(_read('assets/timetable/kmou-public-weekly-2026-2.json'));
    expect(kmou.courses, hasLength(173));
    for (final course in kmou.courses) {
      expect(course.code, isNotEmpty);
      expect(course.meetings, isNotEmpty);
      expect(course.meetings.every((m) => m.date == null), isTrue);
      final restored = TimetableClass.fromJson(
        course.toTimetable(id: course.sourceId, mode: LectureMode.inPerson).toJson(),
      );
      expect(classOccurrences([restored], [DateTime(2026, 8, 31), DateTime(2026, 12, 8)]), isEmpty);
    }
  });
}
